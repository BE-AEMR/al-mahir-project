-- Création de la table des équipes
CREATE TABLE IF NOT EXISTS teams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  updated_at TIMESTAMPTZ
);

-- Création de la table des membres d'équipe
CREATE TABLE IF NOT EXISTS team_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('admin', 'member', 'guest')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  invited_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  status TEXT NOT NULL CHECK (status IN ('invited', 'active', 'inactive')) DEFAULT 'invited',
  UNIQUE(team_id, user_id)
);

-- Création de la table des projets d'équipe
CREATE TABLE IF NOT EXISTS team_projects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(team_id, project_id)
);

-- Création de la table des invitations
CREATE TABLE IF NOT EXISTS invitations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT NOT NULL,
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  invited_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
  token TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')) DEFAULT 'pending'
);

-- Ajout de la colonne team_id à la table des tâches
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE SET NULL;

-- Politiques RLS pour la table teams
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Les utilisateurs peuvent voir les équipes dont ils sont membres" 
ON teams FOR SELECT 
USING (
  id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid() AND status = 'active'
  )
);

CREATE POLICY "Les utilisateurs peuvent créer des équipes" 
ON teams FOR INSERT 
WITH CHECK (created_by = auth.uid());

CREATE POLICY "Les administrateurs d'équipe peuvent mettre à jour les équipes" 
ON teams FOR UPDATE 
USING (
  id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  )
);

CREATE POLICY "Les administrateurs d'équipe peuvent supprimer les équipes" 
ON teams FOR DELETE 
USING (
  id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  )
);

-- Politiques RLS pour la table team_members
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Les utilisateurs peuvent voir les membres des équipes dont ils sont membres" 
ON team_members FOR SELECT 
USING (
  team_id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid() AND status = 'active'
  )
);

CREATE POLICY "Les administrateurs d'équipe peuvent ajouter des membres" 
ON team_members FOR INSERT 
WITH CHECK (
  team_id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  )
);

CREATE POLICY "Les administrateurs d'équipe peuvent mettre à jour les membres" 
ON team_members FOR UPDATE 
USING (
  team_id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  )
);

CREATE POLICY "Les utilisateurs peuvent mettre à jour leur propre statut de membre" 
ON team_members FOR UPDATE 
USING (user_id = auth.uid());

CREATE POLICY "Les administrateurs d'équipe peuvent supprimer des membres" 
ON team_members FOR DELETE 
USING (
  team_id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  )
);

-- Politiques RLS pour la table team_projects
ALTER TABLE team_projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Les utilisateurs peuvent voir les projets des équipes dont ils sont membres" 
ON team_projects FOR SELECT 
USING (
  team_id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid() AND status = 'active'
  )
);

CREATE POLICY "Les administrateurs d'équipe peuvent ajouter des projets" 
ON team_projects FOR INSERT 
WITH CHECK (
  team_id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  )
);

CREATE POLICY "Les administrateurs d'équipe peuvent supprimer des projets" 
ON team_projects FOR DELETE 
USING (
  team_id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  )
);

-- Politiques RLS pour la table invitations
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Les utilisateurs peuvent voir les invitations qu'ils ont envoyées" 
ON invitations FOR SELECT 
USING (invited_by = auth.uid());

CREATE POLICY "Les utilisateurs peuvent voir les invitations qui leur sont destinées" 
ON invitations FOR SELECT 
USING (email = (SELECT email FROM auth.users WHERE id = auth.uid()));

CREATE POLICY "Les administrateurs d'équipe peuvent créer des invitations" 
ON invitations FOR INSERT 
WITH CHECK (
  team_id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  )
);

CREATE POLICY "Les utilisateurs peuvent mettre à jour les invitations qui leur sont destinées" 
ON invitations FOR UPDATE 
USING (email = (SELECT email FROM auth.users WHERE id = auth.uid()));

CREATE POLICY "Les administrateurs d'équipe peuvent mettre à jour les invitations qu'ils ont envoyées" 
ON invitations FOR UPDATE 
USING (
  invited_by = auth.uid() AND 
  team_id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  )
);

CREATE POLICY "Les administrateurs d'équipe peuvent supprimer les invitations" 
ON invitations FOR DELETE 
USING (
  team_id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  )
);
