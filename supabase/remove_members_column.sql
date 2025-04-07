-- Supprimer la colonne members de la table projects
ALTER TABLE public.projects DROP COLUMN IF EXISTS members;

-- Mettre à jour les politiques RLS pour les projets pour tenir compte de l'affectation via équipes
-- Politique pour voir les projets : un utilisateur peut voir les projets qu'il a créés ou ceux auxquels son équipe est affectée
CREATE OR REPLACE POLICY "Users can view their own projects or team projects" ON public.projects
  FOR SELECT USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM team_projects tp
      JOIN team_members tm ON tp.team_id = tm.team_id
      WHERE tp.project_id = id
      AND tm.user_id = auth.uid()
      AND tm.status = 'active'
    )
  );

-- Politique pour les projets: un utilisateur peut mettre à jour ses propres projets ou ceux auxquels son équipe est affectée avec rôle admin
CREATE OR REPLACE POLICY "Users can update their own projects or team projects" ON public.projects
  FOR UPDATE USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM team_projects tp
      JOIN team_members tm ON tp.team_id = tm.team_id
      WHERE tp.project_id = id
      AND tm.user_id = auth.uid()
      AND tm.role = 'admin'
      AND tm.status = 'active'
    )
  );

-- Politique pour les projets: un utilisateur peut supprimer ses propres projets ou ceux auxquels son équipe est affectée avec rôle admin
CREATE OR REPLACE POLICY "Users can delete their own projects or team projects" ON public.projects
  FOR DELETE USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM team_projects tp
      JOIN team_members tm ON tp.team_id = tm.team_id
      WHERE tp.project_id = id
      AND tm.user_id = auth.uid()
      AND tm.role = 'admin'
      AND tm.status = 'active'
    )
  );
