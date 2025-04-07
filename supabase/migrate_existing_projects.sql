-- Migration des données existantes de user_roles.project_id vers user_role_projects
-- Ce script est conçu pour être exécuté une seule fois lors de la migration

-- Insérer les relations existantes depuis user_roles dans user_role_projects
INSERT INTO user_role_projects (user_role_id, project_id)
SELECT id, project_id
FROM user_roles
WHERE project_id IS NOT NULL
-- Éviter les doublons avec ON CONFLICT DO NOTHING
ON CONFLICT (user_role_id, project_id) DO NOTHING;

-- Vérification des données migrées
SELECT COUNT(*) AS migrated_relations FROM user_role_projects;

-- Journalisation de la migration
INSERT INTO rbac_logs (user_id, action, details)
VALUES (
  '00000000-0000-0000-0000-000000000000', -- ID système
  'system_migration',
  json_build_object(
    'migration', 'user_roles_to_user_role_projects',
    'timestamp', NOW(),
    'count', (SELECT COUNT(*) FROM user_role_projects)
  )
);

-- Note: Dans une phase ultérieure, vous pourriez vouloir supprimer project_id de user_roles
-- mais nous le conservons pour la rétrocompatibilité pour l'instant
-- ALTER TABLE user_roles DROP COLUMN project_id;
