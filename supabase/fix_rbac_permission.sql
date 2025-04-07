-- Script de correction de la fonction RBAC pour WebXIO (AL MAHIR Project)
-- Ce script modifie la fonction user_has_permission pour vérifier les permissions dans tous les contextes

-- Modification de la fonction pour vérifier si un utilisateur a une permission sans restriction de contexte
CREATE OR REPLACE FUNCTION public.user_has_permission(
    p_user_id uuid,
    p_permission_name text,
    p_team_id uuid DEFAULT NULL,
    p_project_id uuid DEFAULT NULL
) RETURNS boolean AS $$
DECLARE
    has_perm boolean;
BEGIN
    -- Pour les écrans généraux sans contexte spécifique,
    -- il suffit de vérifier si l'utilisateur a la permission associée à l'un de ses rôles,
    -- indépendamment du contexte dans lequel le rôle a été attribué
    IF p_team_id IS NULL AND p_project_id IS NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM "public"."user_roles" ur
            JOIN "public"."role_permissions" rp ON ur.role_id = rp.role_id
            JOIN "public"."permissions" p ON rp.permission_id = p.id
            WHERE ur.user_id = p_user_id
            AND p.name = p_permission_name
        ) INTO has_perm;

        IF has_perm THEN
            RETURN true;
        END IF;
    END IF;

    -- Si la vérification précédente échoue ou si un contexte spécifique est demandé,
    -- on utilise la vérification de contexte existante
    SELECT EXISTS (
        SELECT 1 FROM "public"."user_roles" ur
        JOIN "public"."role_permissions" rp ON ur.role_id = rp.role_id
        JOIN "public"."permissions" p ON rp.permission_id = p.id
        WHERE ur.user_id = p_user_id
        AND p.name = p_permission_name
        AND (
            -- Contexte global (ni team ni project spécifiés)
            (ur.team_id IS NULL AND ur.project_id IS NULL AND p_team_id IS NULL AND p_project_id IS NULL)
            -- Contexte équipe spécifique
            OR (ur.team_id = p_team_id AND ur.project_id IS NULL AND p_team_id IS NOT NULL AND p_project_id IS NULL)
            -- Contexte projet spécifique
            OR (ur.project_id = p_project_id AND ur.team_id IS NULL AND p_project_id IS NOT NULL AND p_team_id IS NULL)
            -- Contexte équipe+projet spécifique
            OR (ur.team_id = p_team_id AND ur.project_id = p_project_id AND p_team_id IS NOT NULL AND p_project_id IS NOT NULL)
        )
    ) INTO has_perm;

    -- Si pas de permission trouvée, vérifier les rôles team_members legacy
    IF NOT has_perm AND p_team_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM "public"."team_members" tm
            WHERE tm.user_id = p_user_id
            AND tm.team_id = p_team_id
            AND tm.status = 'active'
            AND (
                -- Les admins peuvent tout faire dans leur équipe
                (tm.role = 'admin')
                -- Les membres ont des permissions limitées (à adapter selon vos besoins)
                OR (tm.role = 'member' AND p_permission_name IN (
                    'read_project', 'read_phase', 'read_task', 'update_task',
                    'change_task_status', 'create_task'
                ))
                -- Les invités ont très peu de permissions
                OR (tm.role = 'guest' AND p_permission_name IN (
                    'read_project', 'read_phase', 'read_task'
                ))
            )
        ) INTO has_perm;
    END IF;

    RETURN has_perm;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
