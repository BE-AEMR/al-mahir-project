-- Ajout de la politique manquante pour les mises à jour dans la table team_projects
-- Cette politique est nécessaire pour permettre aux administrateurs d'équipe de modifier les associations entre équipes et projets

-- Vérifier si la politique existe déjà et la créer uniquement si elle n'existe pas
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'team_projects' AND policyname = 'team_projects_update_policy') THEN
        CREATE POLICY "team_projects_update_policy" 
        ON team_projects FOR UPDATE 
        USING (
          team_id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
          )
        );
        RAISE NOTICE 'Politique team_projects_update_policy créée avec succès.';
    ELSE
        RAISE NOTICE 'La politique team_projects_update_policy existe déjà.';
    END IF;
END
$$;
