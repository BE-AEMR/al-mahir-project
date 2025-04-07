
-- Supprimer d'abord les politiques existantes qui pourraient référencer la colonne members
DROP POLICY IF EXISTS "Users can view their own projects" ON public.projects;
DROP POLICY IF EXISTS "Users can update their own projects" ON public.projects;
DROP POLICY IF EXISTS "Users can delete their own projects" ON public.projects;

-- Si la colonne members existe, mettre à jour pour ajouter une valeur par défaut et la rendre nullable
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'projects'
    AND column_name = 'members'
  ) THEN
    -- Mettre à jour la colonne pour la rendre nullable et avec une valeur par défaut
    ALTER TABLE public.projects ALTER COLUMN members SET DEFAULT '{}';
    ALTER TABLE public.projects ALTER COLUMN members DROP NOT NULL;
  END IF;
END $$;

-- Créer les nouvelles politiques RLS pour les projets
CREATE POLICY "Users can view their own projects or team projects" ON public.projects
  FOR SELECT USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM team_projects tp
      JOIN team_members tm ON tp.team_id = tm.team_id
      WHERE tp.project_id = projects.id
      AND tm.user_id = auth.uid()
      AND tm.status = 'active'
    )
  );

CREATE POLICY "Users can update their own projects or team projects" ON public.projects
  FOR UPDATE USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM team_projects tp
      JOIN team_members tm ON tp.team_id = tm.team_id
      WHERE tp.project_id = projects.id
      AND tm.user_id = auth.uid()
      AND tm.role = 'admin'
      AND tm.status = 'active'
    )
  );

CREATE POLICY "Users can delete their own projects or team projects" ON public.projects
  FOR DELETE USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM team_projects tp
      JOIN team_members tm ON tp.team_id = tm.team_id
      WHERE tp.project_id = projects.id
      AND tm.user_id = auth.uid()
      AND tm.role = 'admin'
      AND tm.status = 'active'
    )
  );