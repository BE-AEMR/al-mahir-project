-- Ce script est destiné à être exécuté directement dans la console SQL de Supabase
-- pour corriger toutes les politiques RLS liées aux équipes

-- 1. Suppression de toutes les politiques existantes qui pourraient causer des récursions
-- Pour la table teams
DROP POLICY IF EXISTS "teams_select_policy" ON public.teams;
DROP POLICY IF EXISTS "teams_insert_policy" ON public.teams;
DROP POLICY IF EXISTS "teams_update_policy" ON public.teams;
DROP POLICY IF EXISTS "teams_delete_policy" ON public.teams;

-- Pour la table team_members
DROP POLICY IF EXISTS "team_members_select_policy" ON public.team_members;
DROP POLICY IF EXISTS "team_members_insert_policy" ON public.team_members;
DROP POLICY IF EXISTS "team_members_update_policy" ON public.team_members;
DROP POLICY IF EXISTS "team_members_update_own_policy" ON public.team_members;
DROP POLICY IF EXISTS "team_members_delete_policy" ON public.team_members;

-- Pour la table team_projects
DROP POLICY IF EXISTS "team_projects_select_policy" ON public.team_projects;
DROP POLICY IF EXISTS "team_projects_insert_policy" ON public.team_projects;
DROP POLICY IF EXISTS "team_projects_delete_policy" ON public.team_projects;

-- 2. Création de nouvelles politiques sans récursion
-- Pour la table teams
CREATE POLICY "teams_select_policy" 
ON public.teams FOR SELECT 
USING (
  -- Permet à l'utilisateur de voir les équipes qu'il a créées
  created_by = auth.uid()
);

CREATE POLICY "teams_insert_policy" 
ON public.teams FOR INSERT 
WITH CHECK (created_by = auth.uid());

CREATE POLICY "teams_update_policy" 
ON public.teams FOR UPDATE 
USING (created_by = auth.uid());

CREATE POLICY "teams_delete_policy" 
ON public.teams FOR DELETE 
USING (created_by = auth.uid());

-- Pour la table team_members
CREATE POLICY "team_members_select_policy" 
ON public.team_members FOR SELECT 
USING (
  -- Permet à l'utilisateur de voir ses propres enregistrements
  user_id = auth.uid()
  -- Ou les enregistrements des équipes qu'il a créées
  OR team_id IN (
    SELECT id FROM public.teams WHERE created_by = auth.uid()
  )
);

CREATE POLICY "team_members_insert_policy" 
ON public.team_members FOR INSERT 
WITH CHECK (
  -- Permet à l'utilisateur d'insérer des membres dans les équipes qu'il a créées
  team_id IN (
    SELECT id FROM public.teams WHERE created_by = auth.uid()
  )
);

CREATE POLICY "team_members_update_policy" 
ON public.team_members FOR UPDATE 
USING (
  -- Permet à l'utilisateur de mettre à jour les membres des équipes qu'il a créées
  team_id IN (
    SELECT id FROM public.teams WHERE created_by = auth.uid()
  )
);

CREATE POLICY "team_members_update_own_policy" 
ON public.team_members FOR UPDATE 
USING (user_id = auth.uid());

CREATE POLICY "team_members_delete_policy" 
ON public.team_members FOR DELETE 
USING (
  -- Permet à l'utilisateur de supprimer des membres des équipes qu'il a créées
  team_id IN (
    SELECT id FROM public.teams WHERE created_by = auth.uid()
  )
);

-- Pour la table team_projects
CREATE POLICY "team_projects_select_policy" 
ON public.team_projects FOR SELECT 
USING (
  -- Permet à l'utilisateur de voir les projets des équipes qu'il a créées
  team_id IN (
    SELECT id FROM public.teams WHERE created_by = auth.uid()
  )
  -- Ou les projets des équipes auxquelles il appartient
  OR team_id IN (
    SELECT team_id FROM public.team_members WHERE user_id = auth.uid() AND status = 'active'
  )
);

CREATE POLICY "team_projects_insert_policy" 
ON public.team_projects FOR INSERT 
WITH CHECK (
  -- Permet à l'utilisateur d'insérer des projets dans les équipes qu'il a créées
  team_id IN (
    SELECT id FROM public.teams WHERE created_by = auth.uid()
  )
);

CREATE POLICY "team_projects_delete_policy" 
ON public.team_projects FOR DELETE 
USING (
  -- Permet à l'utilisateur de supprimer des projets des équipes qu'il a créées
  team_id IN (
    SELECT id FROM public.teams WHERE created_by = auth.uid()
  )
);
