-- Création de la table user_role_projects pour gérer les relations many-to-many entre rôles utilisateurs et projets
-- Cette table remplace la dépendance directe au champ project_id dans la table user_roles

CREATE TABLE IF NOT EXISTS user_role_projects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_role_id UUID NOT NULL REFERENCES user_roles(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Contrainte unique pour éviter les doublons d'associations
  UNIQUE(user_role_id, project_id)
);

-- Index pour améliorer les performances des requêtes
CREATE INDEX IF NOT EXISTS idx_user_role_projects_user_role_id ON user_role_projects(user_role_id);
CREATE INDEX IF NOT EXISTS idx_user_role_projects_project_id ON user_role_projects(project_id);

-- Commentaires sur la table et les colonnes
COMMENT ON TABLE user_role_projects IS 'Association entre rôles utilisateur et projets pour le système RBAC multi-projets';
COMMENT ON COLUMN user_role_projects.user_role_id IS 'Référence à l''ID du rôle utilisateur';
COMMENT ON COLUMN user_role_projects.project_id IS 'Référence à l''ID du projet associé';

-- Politique RLS pour l'accès sécurisé
-- Les administrateurs système peuvent tout voir
CREATE POLICY admin_policy ON user_role_projects 
  FOR ALL 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM user_roles ur 
      JOIN roles r ON ur.role_id = r.id 
      WHERE ur.user_id = auth.uid() 
      AND r.name = 'system_admin'
    )
  );

-- Les utilisateurs peuvent voir les associations pour lesquelles ils ont le rôle
CREATE POLICY user_view_policy ON user_role_projects 
  FOR SELECT 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM user_roles ur 
      WHERE ur.id = user_role_id 
      AND ur.user_id = auth.uid()
    )
  );
