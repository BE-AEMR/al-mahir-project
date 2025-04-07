-- Procédure stockée pour associer automatiquement un projet à l'utilisateur qui l'a créé
-- Cette fonction contourne les politiques RLS car elle s'exécute avec les privilèges du serveur
CREATE OR REPLACE FUNCTION public.auto_assign_project_to_creator(p_project_id uuid, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- S'exécute avec les permissions du créateur (superuser)
AS $$
DECLARE
  v_role_id uuid;
  v_user_role_id uuid;
BEGIN
  -- Rechercher un rôle de l'utilisateur qui a la permission create_project
  SELECT ur.id INTO v_user_role_id
  FROM user_roles ur
  JOIN role_permissions rp ON ur.role_id = rp.role_id
  JOIN permissions p ON rp.permission_id = p.id
  WHERE ur.user_id = p_user_id
  AND p.name = 'create_project'
  LIMIT 1;
  
  -- Si l'utilisateur a un rôle avec la permission create_project
  IF v_user_role_id IS NOT NULL THEN
    -- Vérifier si l'association existe déjà
    IF NOT EXISTS (
      SELECT 1 FROM user_role_projects
      WHERE user_role_id = v_user_role_id AND project_id = p_project_id
    ) THEN
      -- Créer l'association dans user_role_projects
      INSERT INTO user_role_projects (id, user_role_id, project_id)
      VALUES (gen_random_uuid(), v_user_role_id, p_project_id);
      
      RAISE NOTICE 'Projet % automatiquement associé à l''utilisateur % via le rôle %', 
        p_project_id, p_user_id, v_user_role_id;
    END IF;
  END IF;
END;
$$;
