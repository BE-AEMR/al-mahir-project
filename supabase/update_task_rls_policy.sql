-- Politique RLS mise à jour pour les tâches dans WebXio
-- Cette politique permet une gestion plus flexible des tâches en prenant en compte 
-- les rôles système (system_admin, project_manager) et les rôles d'équipe

-- Suppression de la politique existante
DROP POLICY IF EXISTS "Users can update their assigned tasks or team tasks" ON public.tasks;

-- Création de la nouvelle politique avec des permissions étendues
CREATE POLICY "Users can update their assigned tasks or team tasks" ON public.tasks
  FOR UPDATE USING (
    -- L'utilisateur est l'assigné actuel
    assigned_to = auth.uid()::text OR 
    -- L'utilisateur est le créateur
    created_by = auth.uid() OR
    -- L'utilisateur est admin système (peut tout modifier)
    EXISTS (
      SELECT 1 FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id = auth.uid() 
      AND r.name = 'system_admin'
    ) OR
    -- L'utilisateur est gestionnaire de projet pour ce projet spécifique
    EXISTS (
      SELECT 1 FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id = auth.uid()
      AND r.name = 'project_manager'
      AND ur.project_id = tasks.project_id
    ) OR
    -- L'utilisateur est admin d'une équipe associée à la tâche
    EXISTS (
      SELECT 1 FROM team_tasks tt
      JOIN team_members tm ON tt.team_id = tm.team_id
      WHERE tt.task_id = tasks.id
      AND tm.user_id = auth.uid()
      AND tm.role = 'admin'
      AND tm.status = 'active'
    )
  );

-- Fonction RPC pour vérifier les permissions de rôle (si besoin de la remplacer)
CREATE OR REPLACE FUNCTION has_role_permission(
  p_user_id UUID,
  p_permission_name TEXT,
  p_project_id TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
  v_has_permission BOOLEAN;
BEGIN
  -- Vérifier si l'utilisateur a un rôle system_admin
  SELECT EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = p_user_id 
    AND r.name = 'system_admin'
  ) INTO v_has_permission;
  
  IF v_has_permission THEN
    RETURN TRUE;
  END IF;
  
  -- Vérifier si l'utilisateur est project_manager pour ce projet
  IF p_project_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id = p_user_id
      AND r.name = 'project_manager'
      AND ur.project_id = p_project_id
    ) INTO v_has_permission;
    
    IF v_has_permission THEN
      RETURN TRUE;
    END IF;
  END IF;
  
  -- Vérifier dans la table de permissions standard
  SELECT EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN role_permissions rp ON ur.role_id = rp.role_id
    JOIN permissions p ON rp.permission_id = p.id
    WHERE ur.user_id = p_user_id
    AND p.name = p_permission_name
    AND (
      ur.project_id IS NULL 
      OR 
      (p_project_id IS NOT NULL AND ur.project_id = p_project_id)
    )
  ) INTO v_has_permission;
  
  RETURN v_has_permission;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
