-- Procédure stockée pour supprimer toutes les associations équipe-projet pour un projet donné
-- Cette fonction contourne les politiques RLS car elle s'exécute avec les privilèges du serveur
CREATE OR REPLACE FUNCTION public.remove_all_teams_from_project(p_project_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- S'exécute avec les permissions du créateur (superuser)
AS $$
BEGIN
  -- Supprimer toutes les associations pour ce projet
  DELETE FROM team_projects
  WHERE project_id = p_project_id;
  
  -- Loguer l'action dans le journal d'audit de PostgreSQL
  RAISE NOTICE 'All team associations removed for project %', p_project_id;
END;
$$;
