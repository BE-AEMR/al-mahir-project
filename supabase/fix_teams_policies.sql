-- Ce script est destiné à être exécuté directement dans la console SQL de Supabase
-- pour corriger les politiques RLS de la table teams

-- Suppression des politiques existantes pour teams
DROP POLICY IF EXISTS "teams_select_policy" ON public.teams;
DROP POLICY IF EXISTS "teams_insert_policy" ON public.teams;
DROP POLICY IF EXISTS "teams_update_policy" ON public.teams;
DROP POLICY IF EXISTS "teams_delete_policy" ON public.teams;

-- Création d'une politique de sélection pour teams sans récursion
CREATE POLICY "teams_select_policy" 
ON public.teams FOR SELECT 
USING (
  -- Permet à l'utilisateur de voir les équipes qu'il a créées
  created_by = auth.uid()
  -- Ou les équipes auxquelles il appartient (sans référence circulaire)
  OR id IN (
    SELECT team_id FROM public.team_members 
    WHERE user_id = auth.uid() AND status = 'active'
  )
);

-- Création d'une politique d'insertion pour teams
CREATE POLICY "teams_insert_policy" 
ON public.teams FOR INSERT 
WITH CHECK (created_by = auth.uid());

-- Création d'une politique de mise à jour pour teams
CREATE POLICY "teams_update_policy" 
ON public.teams FOR UPDATE 
USING (
  -- Permet à l'utilisateur de mettre à jour les équipes qu'il a créées
  created_by = auth.uid()
  -- Ou les équipes où il est admin (sans référence circulaire)
  OR id IN (
    SELECT team_id FROM public.team_members 
    WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  )
);

-- Création d'une politique de suppression pour teams
CREATE POLICY "teams_delete_policy" 
ON public.teams FOR DELETE 
USING (
  -- Permet à l'utilisateur de supprimer les équipes qu'il a créées
  created_by = auth.uid()
  -- Ou les équipes où il est admin (sans référence circulaire)
  OR id IN (
    SELECT team_id FROM public.team_members 
    WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  )
);
