-- Suppression des politiques existantes pour team_members
DROP POLICY IF EXISTS "team_members_select_policy" ON public.team_members;
DROP POLICY IF EXISTS "team_members_insert_policy" ON public.team_members;
DROP POLICY IF EXISTS "team_members_update_policy" ON public.team_members;
DROP POLICY IF EXISTS "team_members_update_own_policy" ON public.team_members;
DROP POLICY IF EXISTS "team_members_delete_policy" ON public.team_members;

-- Création d'une politique de sélection pour team_members sans récursion
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

-- Création d'une politique d'insertion pour team_members
CREATE POLICY "team_members_insert_policy" 
ON public.team_members FOR INSERT 
WITH CHECK (
  -- Permet à l'utilisateur d'insérer des membres dans les équipes qu'il a créées
  team_id IN (
    SELECT id FROM public.teams WHERE created_by = auth.uid()
  )
);

-- Création d'une politique de mise à jour pour team_members
CREATE POLICY "team_members_update_policy" 
ON public.team_members FOR UPDATE 
USING (
  -- Permet à l'utilisateur de mettre à jour les membres des équipes qu'il a créées
  team_id IN (
    SELECT id FROM public.teams WHERE created_by = auth.uid()
  )
);

-- Création d'une politique de mise à jour pour ses propres enregistrements
CREATE POLICY "team_members_update_own_policy" 
ON public.team_members FOR UPDATE 
USING (user_id = auth.uid());

-- Création d'une politique de suppression pour team_members
CREATE POLICY "team_members_delete_policy" 
ON public.team_members FOR DELETE 
USING (
  -- Permet à l'utilisateur de supprimer des membres des équipes qu'il a créées
  team_id IN (
    SELECT id FROM public.teams WHERE created_by = auth.uid()
  )
);
