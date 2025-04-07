-- Script d'implémentation RBAC pour WebXIO (AL MAHIR Project)
-- À exécuter dans l'éditeur SQL de Supabase Cloud

BEGIN;

-- 1. Création des tables principales du système RBAC
----------------------------------------------------

-- Table des rôles
CREATE TABLE IF NOT EXISTS "public"."roles" (
    "id" uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    "name" text NOT NULL,
    "description" text,
    "created_at" timestamp with time zone DEFAULT now(),
    CONSTRAINT "roles_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "roles_name_key" UNIQUE ("name")
);
ALTER TABLE "public"."roles" OWNER TO "postgres";

-- Table des permissions
CREATE TABLE IF NOT EXISTS "public"."permissions" (
    "id" uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    "name" text NOT NULL,
    "description" text,
    "resource_type" text NOT NULL, -- 'project', 'phase', 'task', 'finance', etc.
    "action" text NOT NULL, -- 'create', 'read', 'update', 'delete', etc.
    "created_at" timestamp with time zone DEFAULT now(),
    CONSTRAINT "permissions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "permissions_name_key" UNIQUE ("name")
);
ALTER TABLE "public"."permissions" OWNER TO "postgres";

-- Table d'association rôle-permission
CREATE TABLE IF NOT EXISTS "public"."role_permissions" (
    "id" uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    "role_id" uuid NOT NULL REFERENCES "public"."roles"("id") ON DELETE CASCADE,
    "permission_id" uuid NOT NULL REFERENCES "public"."permissions"("id") ON DELETE CASCADE,
    "created_at" timestamp with time zone DEFAULT now(),
    CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "role_permissions_role_permission_key" UNIQUE ("role_id", "permission_id")
);
ALTER TABLE "public"."role_permissions" OWNER TO "postgres";

-- Table d'assignation des rôles aux utilisateurs
CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "id" uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    "user_id" uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    "role_id" uuid NOT NULL REFERENCES "public"."roles"("id") ON DELETE CASCADE,
    "team_id" uuid REFERENCES "public"."teams"("id") ON DELETE CASCADE,
    "project_id" uuid REFERENCES "public"."projects"("id") ON DELETE CASCADE,
    "created_at" timestamp with time zone DEFAULT now(),
    "created_by" uuid REFERENCES auth.users(id),
    CONSTRAINT "user_roles_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "user_roles_unique_context" UNIQUE ("user_id", "role_id", "team_id", "project_id")
);
ALTER TABLE "public"."user_roles" OWNER TO "postgres";

-- 2. Insertion des données initiales
------------------------------------

-- Rôles de base
INSERT INTO "public"."roles" ("name", "description") VALUES
('system_admin', 'Accès complet à toutes les fonctionnalités du système'),
('project_manager', 'Gestion complète des projets assignés'),
('team_member', 'Travail sur les tâches assignées'),
('finance_manager', 'Gestion des finances et budgets'),
('observer', 'Accès en lecture seule')
ON CONFLICT (name) DO NOTHING;

-- Permissions pour les projets
INSERT INTO "public"."permissions" ("name", "description", "resource_type", "action") VALUES
('create_project', 'Créer un nouveau projet', 'project', 'create'),
('read_project', 'Voir un projet', 'project', 'read'),
('read_all_projects', 'Voir tous les projets', 'project', 'read'),
('update_project', 'Modifier un projet', 'project', 'update'),
('delete_project', 'Supprimer un projet', 'project', 'delete')
ON CONFLICT (name) DO NOTHING;

-- Permissions pour les phases
INSERT INTO "public"."permissions" ("name", "description", "resource_type", "action") VALUES
('create_phase', 'Créer une nouvelle phase', 'phase', 'create'),
('read_phase', 'Voir une phase', 'phase', 'read'),
('update_phase', 'Modifier une phase', 'phase', 'update'),
('reorder_phase', 'Réordonner les phases', 'phase', 'update'),
('delete_phase', 'Supprimer une phase', 'phase', 'delete')
ON CONFLICT (name) DO NOTHING;

-- Permissions pour les tâches
INSERT INTO "public"."permissions" ("name", "description", "resource_type", "action") VALUES
('create_task', 'Créer une nouvelle tâche', 'task', 'create'),
('read_task', 'Voir une tâche', 'task', 'read'),
('update_task', 'Modifier une tâche', 'task', 'update'),
('assign_task', 'Assigner une tâche', 'task', 'update'),
('change_task_status', 'Changer le statut d''une tâche', 'task', 'update'),
('delete_task', 'Supprimer une tâche', 'task', 'delete')
ON CONFLICT (name) DO NOTHING;

-- Permissions pour les finances
INSERT INTO "public"."permissions" ("name", "description", "resource_type", "action") VALUES
('create_transaction', 'Créer une transaction', 'finance', 'create'),
('read_transaction', 'Voir une transaction', 'finance', 'read'),
('read_all_transactions', 'Voir toutes les transactions', 'finance', 'read'),
('update_transaction', 'Modifier une transaction', 'finance', 'update'),
('approve_transaction', 'Approuver une transaction', 'finance', 'update'),
('delete_transaction', 'Supprimer une transaction', 'finance', 'delete'),
('manage_budget', 'Gérer les budgets', 'finance', 'update')
ON CONFLICT (name) DO NOTHING;

-- Permissions pour les équipes
INSERT INTO "public"."permissions" ("name", "description", "resource_type", "action") VALUES
('create_team', 'Créer une équipe', 'team', 'create'),
('read_team', 'Voir une équipe', 'team', 'read'),
('update_team', 'Modifier une équipe', 'team', 'update'),
('invite_team_member', 'Inviter un membre dans l''équipe', 'team', 'update'),
('delete_team', 'Supprimer une équipe', 'team', 'delete')
ON CONFLICT (name) DO NOTHING;

-- Permissions utilisateurs
INSERT INTO "public"."permissions" ("name", "description", "resource_type", "action") VALUES
('manage_users', 'Gérer les utilisateurs', 'user', 'admin'),
('read_profile', 'Voir un profil utilisateur', 'user', 'read'),
('update_own_profile', 'Modifier son propre profil', 'user', 'update')
ON CONFLICT (name) DO NOTHING;

-- 3. Assigner les permissions aux rôles
----------------------------------------

-- Admin système (toutes les permissions)
INSERT INTO "public"."role_permissions" ("role_id", "permission_id")
SELECT
    (SELECT id FROM "public"."roles" WHERE name = 'system_admin'),
    id
FROM "public"."permissions";

-- Chef de projet
INSERT INTO "public"."role_permissions" ("role_id", "permission_id")
SELECT
    (SELECT id FROM "public"."roles" WHERE name = 'project_manager'),
    id
FROM "public"."permissions"
WHERE name IN (
    'create_project', 'read_project', 'update_project',
    'create_phase', 'read_phase', 'update_phase', 'reorder_phase', 'delete_phase',
    'create_task', 'read_task', 'update_task', 'assign_task', 'change_task_status', 'delete_task',
    'create_transaction', 'read_transaction', 'approve_transaction',
    'read_team', 'invite_team_member',
    'read_profile', 'update_own_profile'
);

-- Membre d'équipe
INSERT INTO "public"."role_permissions" ("role_id", "permission_id")
SELECT
    (SELECT id FROM "public"."roles" WHERE name = 'team_member'),
    id
FROM "public"."permissions"
WHERE name IN (
    'read_project',
    'read_phase',
    'create_task', 'read_task', 'update_task', 'change_task_status',
    'read_team',
    'read_profile', 'update_own_profile'
);

-- Responsable financier
INSERT INTO "public"."role_permissions" ("role_id", "permission_id")
SELECT
    (SELECT id FROM "public"."roles" WHERE name = 'finance_manager'),
    id
FROM "public"."permissions"
WHERE name IN (
    'read_project',
    'read_phase',
    'read_task',
    'create_transaction', 'read_transaction', 'read_all_transactions',
    'update_transaction', 'approve_transaction', 'delete_transaction', 'manage_budget',
    'read_team',
    'read_profile', 'update_own_profile'
);

-- Observateur
INSERT INTO "public"."role_permissions" ("role_id", "permission_id")
SELECT
    (SELECT id FROM "public"."roles" WHERE name = 'observer'),
    id
FROM "public"."permissions"
WHERE name IN (
    'read_project',
    'read_phase',
    'read_task',
    'read_transaction',
    'read_team',
    'read_profile'
);

-- 4. Fonctions utilitaires RBAC
--------------------------------

-- Fonction pour vérifier si un utilisateur a une permission
CREATE OR REPLACE FUNCTION public.user_has_permission(
    p_user_id uuid,
    p_permission_name text,
    p_team_id uuid DEFAULT NULL,
    p_project_id uuid DEFAULT NULL
) RETURNS boolean AS $$
DECLARE
    has_perm boolean;
BEGIN
    -- Vérifier si l'utilisateur a le rôle avec la permission dans le contexte spécifié
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

-- Fonction pour vérifier si un utilisateur peut accéder à un projet
CREATE OR REPLACE FUNCTION public.can_access_project(project_id uuid) RETURNS boolean AS $$
BEGIN
    -- Admin système
    IF user_has_permission(auth.uid(), 'read_all_projects') THEN
        RETURN true;
    END IF;

    -- Chef de projet ou autre rôle avec permission spécifique pour ce projet
    IF user_has_permission(auth.uid(), 'read_project', NULL, project_id) THEN
        RETURN true;
    END IF;

    -- Membre d'équipe associée au projet
    RETURN EXISTS (
        SELECT 1 FROM "public"."team_projects" tp
        JOIN "public"."team_members" tm ON tp.team_id = tm.team_id
        WHERE tp.project_id = project_id
        AND tm.user_id = auth.uid()
        AND tm.status = 'active'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour vérifier si un utilisateur peut modifier un projet
CREATE OR REPLACE FUNCTION public.can_modify_project(project_id uuid) RETURNS boolean AS $$
BEGIN
    -- Admin système
    IF user_has_permission(auth.uid(), 'update_project') THEN
        RETURN true;
    END IF;

    -- Chef de projet pour ce projet spécifique
    IF user_has_permission(auth.uid(), 'update_project', NULL, project_id) THEN
        RETURN true;
    END IF;

    -- Admin d'équipe associée au projet
    RETURN EXISTS (
        SELECT 1 FROM "public"."team_projects" tp
        JOIN "public"."team_members" tm ON tp.team_id = tm.team_id
        WHERE tp.project_id = project_id
        AND tm.user_id = auth.uid()
        AND tm.role = 'admin'
        AND tm.status = 'active'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Mise à jour des politiques RLS
-----------------------------------

-- Politiques pour la table roles
ALTER TABLE "public"."roles" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage roles" ON "public"."roles";
CREATE POLICY "Admins can manage roles" ON "public"."roles"
    USING (user_has_permission(auth.uid(), 'manage_users'))
    WITH CHECK (user_has_permission(auth.uid(), 'manage_users'));

DROP POLICY IF EXISTS "Users can view roles" ON "public"."roles";
CREATE POLICY "Users can view roles" ON "public"."roles"
    FOR SELECT USING (true);

-- Politiques pour la table permissions
ALTER TABLE "public"."permissions" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage permissions" ON "public"."permissions";
CREATE POLICY "Admins can manage permissions" ON "public"."permissions"
    USING (user_has_permission(auth.uid(), 'manage_users'))
    WITH CHECK (user_has_permission(auth.uid(), 'manage_users'));

DROP POLICY IF EXISTS "Users can view permissions" ON "public"."permissions";
CREATE POLICY "Users can view permissions" ON "public"."permissions"
    FOR SELECT USING (true);

-- Politiques pour la table role_permissions
ALTER TABLE "public"."role_permissions" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage role_permissions" ON "public"."role_permissions";
CREATE POLICY "Admins can manage role_permissions" ON "public"."role_permissions"
    USING (user_has_permission(auth.uid(), 'manage_users'))
    WITH CHECK (user_has_permission(auth.uid(), 'manage_users'));

DROP POLICY IF EXISTS "Users can view role_permissions" ON "public"."role_permissions";
CREATE POLICY "Users can view role_permissions" ON "public"."role_permissions"
    FOR SELECT USING (true);

-- Politiques pour la table user_roles
ALTER TABLE "public"."user_roles" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage user_roles" ON "public"."user_roles";
CREATE POLICY "Admins can manage user_roles" ON "public"."user_roles"
    USING (user_has_permission(auth.uid(), 'manage_users'))
    WITH CHECK (user_has_permission(auth.uid(), 'manage_users'));

DROP POLICY IF EXISTS "Project managers can assign roles for their projects" ON "public"."user_roles";
CREATE POLICY "Project managers can assign roles for their projects" ON "public"."user_roles"
    USING (
        user_has_permission(auth.uid(), 'update_project', NULL, project_id) AND
        (SELECT id FROM "public"."roles" WHERE name = 'system_admin') != role_id
    )
    WITH CHECK (
        user_has_permission(auth.uid(), 'update_project', NULL, project_id) AND
        (SELECT id FROM "public"."roles" WHERE name = 'system_admin') != role_id
    );

DROP POLICY IF EXISTS "Users can view their roles" ON "public"."user_roles";
CREATE POLICY "Users can view their roles" ON "public"."user_roles"
    FOR SELECT USING (
        user_id = auth.uid() OR
        user_has_permission(auth.uid(), 'manage_users') OR
        (project_id IS NOT NULL AND can_access_project(project_id)) OR
        (team_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM "public"."team_members"
            WHERE team_id = "public"."user_roles".team_id
            AND user_id = auth.uid()
            AND status = 'active'
        ))
    );

-- Mise à jour des politiques de la table projects
DROP POLICY IF EXISTS "Users can view their own projects" ON "public"."projects";
CREATE POLICY "Users can view projects based on RBAC" ON "public"."projects"
    FOR SELECT USING (can_access_project(id));

DROP POLICY IF EXISTS "Users can update their own projects" ON "public"."projects";
CREATE POLICY "Users can update projects based on RBAC" ON "public"."projects"
    FOR UPDATE USING (can_modify_project(id))
    WITH CHECK (can_modify_project(id));

DROP POLICY IF EXISTS "Users can delete their own projects" ON "public"."projects";
CREATE POLICY "Users can delete projects based on RBAC" ON "public"."projects"
    FOR DELETE USING (
        user_has_permission(auth.uid(), 'delete_project') OR
        user_has_permission(auth.uid(), 'delete_project', NULL, id)
    );

DROP POLICY IF EXISTS "Users can insert projects" ON "public"."projects";
CREATE POLICY "Users can insert projects based on RBAC" ON "public"."projects"
    FOR INSERT WITH CHECK (
        user_has_permission(auth.uid(), 'create_project')
    );

-- 6. Migration des données existantes
------------------------------------

-- Conversion des administrateurs d'équipe en chefs de projet
INSERT INTO "public"."user_roles" (user_id, role_id, team_id)
SELECT
    tm.user_id,
    (SELECT id FROM "public"."roles" WHERE name = 'project_manager'),
    tm.team_id
FROM "public"."team_members" tm
WHERE tm.role = 'admin' AND tm.status = 'active'
ON CONFLICT ON CONSTRAINT user_roles_unique_context DO NOTHING;

-- Conversion des membres d'équipe en membres d'équipe RBAC
INSERT INTO "public"."user_roles" (user_id, role_id, team_id)
SELECT
    tm.user_id,
    (SELECT id FROM "public"."roles" WHERE name = 'team_member'),
    tm.team_id
FROM "public"."team_members" tm
WHERE tm.role = 'member' AND tm.status = 'active'
ON CONFLICT ON CONSTRAINT user_roles_unique_context DO NOTHING;

-- Conversion des invités d'équipe en observateurs
INSERT INTO "public"."user_roles" (user_id, role_id, team_id)
SELECT
    tm.user_id,
    (SELECT id FROM "public"."roles" WHERE name = 'observer'),
    tm.team_id
FROM "public"."team_members" tm
WHERE tm.role = 'guest' AND tm.status = 'active'
ON CONFLICT ON CONSTRAINT user_roles_unique_context DO NOTHING;

-- Attribution du rôle système admin au premier utilisateur (optionnel)
INSERT INTO "public"."user_roles" (user_id, role_id)
SELECT
    id,
    (SELECT id FROM "public"."roles" WHERE name = 'system_admin')
FROM auth.users
ORDER BY created_at
LIMIT 1
ON CONFLICT ON CONSTRAINT user_roles_unique_context DO NOTHING;

COMMIT;
