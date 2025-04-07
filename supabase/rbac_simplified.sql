-- Migration vers un système RBAC unifié pour WebXIO (AL MAHIR Project)
-- Ce script supprime la dépendance au système legacy de team_members et améliore la fonction user_has_permission

-- Étape 0: Créer d'abord la table de logs RBAC
DROP TABLE IF EXISTS public.rbac_logs;
CREATE TABLE public.rbac_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    permission_name TEXT NOT NULL,
    team_id UUID,
    project_id UUID,
    result BOOLEAN NOT NULL,
    log_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    debug_info JSONB,
    FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

-- Créer un index sur les colonnes fréquemment recherchées
CREATE INDEX IF NOT EXISTS idx_rbac_logs_user_id ON public.rbac_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_rbac_logs_permission ON public.rbac_logs(permission_name);
CREATE INDEX IF NOT EXISTS idx_rbac_logs_timestamp ON public.rbac_logs(log_timestamp);

-- Étape 1: Améliorer la fonction user_has_permission
CREATE OR REPLACE FUNCTION public.user_has_permission(
    p_user_id uuid,
    p_permission_name text,
    p_team_id uuid DEFAULT NULL,
    p_project_id uuid DEFAULT NULL
) RETURNS boolean AS $$
DECLARE
    has_perm boolean := false;
    has_team_perm boolean := false;
    has_project_perm boolean := false;
    has_direct_project_perm boolean := false;
    v_project_ids uuid[];
    user_roles text[];
    v_debug_info jsonb;
BEGIN
    -- Récupérer les noms des rôles de l'utilisateur pour le débogage
    SELECT array_agg(r.name) INTO user_roles
    FROM user_roles ur
    JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = p_user_id;

    -- Les admins système ont automatiquement toutes les permissions
    IF user_roles IS NOT NULL AND 'system_admin' = ANY(user_roles) THEN
        RETURN true;
    END IF;

    -- Cas 1 & 2: Vérification directe sur l'équipe ou globale
    SELECT EXISTS (
        SELECT 1
        FROM user_roles ur
        JOIN role_permissions rp ON ur.role_id = rp.role_id
        JOIN permissions p ON rp.permission_id = p.id
        WHERE ur.user_id = p_user_id
          AND p.name = p_permission_name
          AND (
              -- Cas 1: Rôle global (sans contexte)
              (ur.team_id IS NULL AND ur.project_id IS NULL)
              OR
              -- Cas 2: Rôle dans le contexte d'équipe spécifié
              (p_team_id IS NOT NULL AND ur.team_id = p_team_id)
          )
    ) INTO has_team_perm;

    -- Cas 5 (NOUVEAU): Vérification directe sur un projet spécifique
    -- Ce cas gère les rôles assignés directement à un projet sans passer par une équipe
    IF p_project_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
            FROM user_roles ur
            JOIN role_permissions rp ON ur.role_id = rp.role_id
            JOIN permissions p ON rp.permission_id = p.id
            WHERE ur.user_id = p_user_id
              AND p.name = p_permission_name
              AND ur.project_id = p_project_id
        ) INTO has_direct_project_perm;

        -- Journaliser cette vérification
        INSERT INTO rbac_logs (
            user_id, permission_name, team_id, project_id, result, log_timestamp, debug_info
        ) VALUES (
            p_user_id,
            'CHECK_DIRECT_PROJECT_PERMISSION',
            NULL,
            p_project_id,
            has_direct_project_perm,
            NOW(),
            jsonb_build_object(
                'permission', p_permission_name,
                'project_id', p_project_id,
                'result', has_direct_project_perm
            )
        );
    END IF;

    -- Cas 3 & 4: Vérification via projets liés à l'équipe spécifiée
    IF NOT has_team_perm AND p_team_id IS NOT NULL THEN
        -- Récupérer les projets de l'équipe
        SELECT array_agg(tp.project_id) INTO v_project_ids
        FROM team_projects tp
        WHERE tp.team_id = p_team_id;

        -- Récupérer les projets sur lesquels l'utilisateur a un rôle
        WITH user_project_roles AS (
            SELECT ur.project_id, r.name as role_name
            FROM user_roles ur
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = p_user_id AND ur.project_id IS NOT NULL
        )
        SELECT jsonb_build_object(
            'team_id', p_team_id,
            'team_projects', v_project_ids,
            'user_project_roles', (SELECT jsonb_agg(row_to_json(upr)) FROM user_project_roles upr)
        ) INTO v_debug_info;

        -- Insérer des informations de débogage
        INSERT INTO rbac_logs (
            user_id, permission_name, team_id, project_id, result, log_timestamp, debug_info
        ) VALUES (
            p_user_id, 'DEBUG_PROJ_TEAM_RELATION', p_team_id, NULL, false, NOW(), v_debug_info
        );

        -- Vérification spécifique pour le cas 4: projet lié à l'équipe
        WITH team_related_projects AS (
            -- Obtenir tous les projets liés à cette équipe
            SELECT project_id FROM team_projects WHERE team_id = p_team_id
        ),
        user_permissions AS (
            -- Vérifier si l'utilisateur a la permission via un de ces projets
            SELECT COUNT(*) > 0 AS has_permission
            FROM user_roles ur
            JOIN role_permissions rp ON ur.role_id = rp.role_id
            JOIN permissions p ON rp.permission_id = p.id
            JOIN team_related_projects trp ON trp.project_id = ur.project_id
            WHERE ur.user_id = p_user_id
              AND p.name = p_permission_name
        )
        SELECT has_permission INTO has_project_perm FROM user_permissions;

        -- Journalisation du résultat de la vérification via projet
        INSERT INTO rbac_logs (
            user_id, permission_name, team_id, project_id, result, log_timestamp, debug_info
        ) VALUES (
            p_user_id,
            'CHECK_PERMISSION_VIA_PROJECT',
            p_team_id,
            NULL,
            has_project_perm,
            NOW(),
            jsonb_build_object(
                'permission', p_permission_name,
                'team_projects', v_project_ids,
                'result', has_project_perm
            )
        );
    END IF;

    -- Combiner les résultats (ajout de has_direct_project_perm)
    has_perm := has_team_perm OR has_project_perm OR has_direct_project_perm;

    -- Journaliser le résultat final
    INSERT INTO rbac_logs (
        user_id,
        permission_name,
        team_id,
        project_id,
        result,
        log_timestamp,
        debug_info
    ) VALUES (
        p_user_id,
        p_permission_name,
        p_team_id,
        p_project_id,
        has_perm,
        NOW(),
        jsonb_build_object(
            'has_team_perm', has_team_perm,
            'has_project_perm', has_project_perm,
            'has_direct_project_perm', has_direct_project_perm,
            'team_id', p_team_id,
            'project_id', p_project_id,
            'user_roles', user_roles
        )
    );

    RETURN has_perm;
END;
$$ LANGUAGE plpgsql;

-- Supprimer les logs après 7 jours pour éviter une croissance excessive
CREATE OR REPLACE FUNCTION clean_old_rbac_logs() RETURNS void AS $$
BEGIN
  DELETE FROM public.rbac_logs
  WHERE log_timestamp < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

-- Note: Pour configurer un nettoyage automatique des logs, vous pouvez:
-- 1. Utiliser pg_cron si disponible: SELECT cron.schedule('0 0 * * *', 'SELECT clean_old_rbac_logs()');
-- 2. Configurer un job externe qui exécute périodiquement: SELECT clean_old_rbac_logs();
-- 3. Exécuter manuellement de temps en temps: SELECT clean_old_rbac_logs();

-- Étape 2: Créer des vues et fonctions utilitaires pour faciliter la gestion
-- Vue pour consulter facilement les permissions disponibles pour les utilisateurs
CREATE OR REPLACE VIEW user_permissions_view AS
SELECT
    u.id AS user_id,
    u.email,
    p.display_name AS user_name,
    r.name AS role_name,
    r.description AS role_description,
    perm.name AS permission_name,
    perm.resource_type,
    perm.action,
    t.name AS team_name,
    t.id AS team_id,
    pr.name AS project_name,
    pr.id AS project_id
FROM
    auth.users u
JOIN
    profiles p ON u.id = p.id
JOIN
    user_roles ur ON u.id = ur.user_id
JOIN
    roles r ON ur.role_id = r.id
JOIN
    role_permissions rp ON r.id = rp.role_id
JOIN
    permissions perm ON rp.permission_id = perm.id
LEFT JOIN
    teams t ON ur.team_id = t.id
LEFT JOIN
    projects pr ON ur.project_id = pr.id;

-- Fonction helper pour attribuer un rôle à un utilisateur
CREATE OR REPLACE FUNCTION assign_user_role(
    p_user_id uuid,
    p_role_name text,
    p_team_id uuid DEFAULT NULL,
    p_project_id uuid DEFAULT NULL
) RETURNS boolean AS $$
DECLARE
    v_role_id uuid;
BEGIN
    -- Récupérer l'ID du rôle
    SELECT id INTO v_role_id FROM roles WHERE name = p_role_name;

    IF v_role_id IS NULL THEN
        RAISE EXCEPTION 'Rôle non trouvé: %', p_role_name;
    END IF;

    -- Insérer le rôle utilisateur
    INSERT INTO user_roles (user_id, role_id, team_id, project_id)
    VALUES (p_user_id, v_role_id, p_team_id, p_project_id)
    ON CONFLICT (user_id, role_id, COALESCE(team_id, '00000000-0000-0000-0000-000000000000'::uuid),
                COALESCE(project_id, '00000000-0000-0000-0000-000000000000'::uuid))
    DO NOTHING;

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Étape 3: Fonction pour migrer les données des team_members vers user_roles
CREATE OR REPLACE FUNCTION migrate_team_members_to_rbac() RETURNS integer AS $$
DECLARE
    count_migrated integer := 0;
    rec record;
    v_role_id uuid;
BEGIN
    -- Parcourir tous les membres d'équipe actifs
    FOR rec IN
        SELECT
            user_id, team_id, role
        FROM
            team_members
        WHERE
            status = 'active'
    LOOP
        -- Déterminer l'ID du rôle RBAC en fonction du rôle legacy
        CASE rec.role
            WHEN 'admin' THEN
                SELECT id INTO v_role_id FROM roles WHERE name = 'system_admin';
            WHEN 'member' THEN
                SELECT id INTO v_role_id FROM roles WHERE name = 'team_member';
            WHEN 'guest' THEN
                SELECT id INTO v_role_id FROM roles WHERE name = 'observer';
            ELSE
                SELECT id INTO v_role_id FROM roles WHERE name = 'observer';
        END CASE;

        -- Insertion dans user_roles
        INSERT INTO user_roles (user_id, role_id, team_id, project_id)
        VALUES (rec.user_id, v_role_id, rec.team_id, NULL)
        ON CONFLICT (user_id, role_id, COALESCE(team_id, '00000000-0000-0000-0000-000000000000'::uuid),
                    COALESCE(project_id, '00000000-0000-0000-0000-000000000000'::uuid))
        DO NOTHING;

        count_migrated := count_migrated + 1;
    END LOOP;

    RETURN count_migrated;
END;
$$ LANGUAGE plpgsql;

-- Étape 4: Trigger pour synchroniser automatiquement les futures invitations
CREATE OR REPLACE FUNCTION sync_team_member_to_user_role() RETURNS TRIGGER AS $$
DECLARE
    v_role_id uuid;
BEGIN
    -- Déterminer l'ID du rôle RBAC en fonction du rôle legacy
    CASE NEW.role
        WHEN 'admin' THEN
            SELECT id INTO v_role_id FROM roles WHERE name = 'system_admin';
        WHEN 'member' THEN
            SELECT id INTO v_role_id FROM roles WHERE name = 'team_member';
        WHEN 'guest' THEN
            SELECT id INTO v_role_id FROM roles WHERE name = 'observer';
        ELSE
            SELECT id INTO v_role_id FROM roles WHERE name = 'observer';
    END CASE;

    -- Insérer dans user_roles lors de l'ajout d'un team_member
    INSERT INTO user_roles (user_id, role_id, team_id, project_id)
    VALUES (NEW.user_id, v_role_id, NEW.team_id, NULL)
    ON CONFLICT (user_id, role_id, COALESCE(team_id, '00000000-0000-0000-0000-000000000000'::uuid),
                COALESCE(project_id, '00000000-0000-0000-0000-000000000000'::uuid))
    DO UPDATE SET role_id = v_role_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Supprimer le trigger s'il existe déjà
DROP TRIGGER IF EXISTS team_member_rbac_sync ON team_members;

-- Créer le trigger pour synchroniser les membres d'équipe avec les rôles utilisateur
CREATE TRIGGER team_member_rbac_sync
AFTER INSERT OR UPDATE ON team_members
FOR EACH ROW
WHEN (NEW.status = 'active')
EXECUTE FUNCTION sync_team_member_to_user_role();

-- Commentaire d'exécution
COMMENT ON FUNCTION public.user_has_permission IS 'Fonction améliorée qui vérifie si un utilisateur a une permission, avec prise en charge plus cohérente des contextes.';
