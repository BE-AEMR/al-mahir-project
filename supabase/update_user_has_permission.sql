-- Mise à jour de la procédure stockée user_has_permission pour prendre en compte
-- les projets associés via la nouvelle table user_role_projects
CREATE OR REPLACE FUNCTION user_has_permission(
  p_user_id UUID,
  p_permission_name TEXT,
  p_team_id UUID DEFAULT NULL,
  p_project_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    has_perm boolean := false;
    has_team_perm boolean := false;
    has_project_perm boolean := false;
    has_direct_project_perm boolean := false;
    has_via_user_role_projects boolean := false; -- Nouvelle variable pour les projets via user_role_projects
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
        -- Méthode 1: Via project_id dans user_roles (méthode existante)
        SELECT EXISTS (
            SELECT 1
            FROM user_roles ur
            JOIN role_permissions rp ON ur.role_id = rp.role_id
            JOIN permissions p ON rp.permission_id = p.id
            WHERE ur.user_id = p_user_id
              AND p.name = p_permission_name
              AND ur.project_id = p_project_id
        ) INTO has_direct_project_perm;
        
        -- Méthode 2: Via user_role_projects (nouvelle méthode)
        SELECT EXISTS (
            SELECT 1
            FROM user_roles ur
            JOIN role_permissions rp ON ur.role_id = rp.role_id
            JOIN permissions p ON rp.permission_id = p.id
            JOIN user_role_projects urp ON ur.id = urp.user_role_id
            WHERE ur.user_id = p_user_id
              AND p.name = p_permission_name
              AND urp.project_id = p_project_id
        ) INTO has_via_user_role_projects;
        
        -- Journaliser ces vérifications
        INSERT INTO rbac_logs (
            user_id, permission_name, team_id, project_id, result, log_timestamp, debug_info
        ) VALUES (
            p_user_id, 
            'CHECK_PROJECT_PERMISSIONS', 
            NULL, 
            p_project_id, 
            (has_direct_project_perm OR has_via_user_role_projects), 
            NOW(),
            jsonb_build_object(
                'permission', p_permission_name,
                'project_id', p_project_id,
                'direct_project_perm', has_direct_project_perm,
                'via_user_role_projects', has_via_user_role_projects
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
    
    -- Combiner les résultats (ajout de has_via_user_role_projects)
    has_perm := has_team_perm OR has_project_perm OR has_direct_project_perm OR has_via_user_role_projects;

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
            'has_via_user_role_projects', has_via_user_role_projects,
            'team_id', p_team_id,
            'project_id', p_project_id,
            'user_roles', user_roles
        )
    );

    RETURN has_perm;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
