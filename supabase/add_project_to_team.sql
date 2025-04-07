-- Procédure stockée pour ajouter un projet à une équipe
-- Cette fonction contourne les politiques RLS car elle s'exécute avec les privilèges du serveur
CREATE OR REPLACE FUNCTION public.add_project_to_team(p_team_id uuid, p_project_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- S'exécute avec les permissions du créateur (superuser)
AS $$
DECLARE
  v_id uuid;
  v_exists boolean;
BEGIN
  -- Vérifier si l'association existe déjà
  SELECT EXISTS (
    SELECT 1 FROM team_projects
    WHERE team_id = p_team_id AND project_id = p_project_id
  ) INTO v_exists;
  
  -- Si l'association n'existe pas, la créer
  IF NOT v_exists THEN
    -- Générer un nouvel UUID
    v_id := gen_random_uuid();
    
    -- Insérer la nouvelle association
    INSERT INTO team_projects (id, team_id, project_id)
    VALUES (v_id, p_team_id, p_project_id);
    
    -- Loguer l'action dans le journal d'audit de PostgreSQL
    RAISE NOTICE 'Team % associated with project %', p_team_id, p_project_id;
  END IF;
END;
$$;
