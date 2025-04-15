-- Création d'une fonction RPC pour gérer les assignations de tâches
-- Cette fonction s'exécute avec les privilèges élevés et effectue les opérations dans l'ordre correct

CREATE OR REPLACE FUNCTION public.assign_task_to_team(
  p_task_id UUID,
  p_team_id UUID,
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
SECURITY DEFINER -- S'exécute avec les privilèges du créateur (superuser), contourne les RLS
LANGUAGE plpgsql
AS $$
DECLARE
  v_task RECORD;
  v_team RECORD;
  v_phase_id UUID;
  v_result JSONB;
BEGIN
  -- 1. Vérifications de sécurité
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié';
  END IF;
  
  -- 2. Vérifier que la tâche existe
  SELECT id, title, assigned_to, project_id, phase_id INTO v_task 
  FROM tasks 
  WHERE id = p_task_id;
  
  IF v_task.id IS NULL THEN
    RAISE EXCEPTION 'Tâche non trouvée';
  END IF;
  
  -- 3. Vérifier que l'équipe existe
  SELECT id, name INTO v_team 
  FROM teams 
  WHERE id = p_team_id;
  
  IF v_team.id IS NULL THEN
    RAISE EXCEPTION 'Équipe non trouvée';
  END IF;
  
  -- 4. Vérifier les autorisations
  -- L'utilisateur doit être le créateur, l'assigné actuel, ou avoir un rôle spécial
  IF NOT (
    -- Vérifier si l'utilisateur est créateur ou assigné
    EXISTS(SELECT 1 FROM tasks WHERE id = p_task_id AND (created_by = p_user_id OR assigned_to = p_user_id::text))
    OR
    -- Vérifier si l'utilisateur est admin d'équipe associée
    EXISTS(
      SELECT 1 FROM team_tasks tt
      JOIN team_members tm ON tt.team_id = tm.team_id
      WHERE tt.task_id = p_task_id
      AND tm.user_id = p_user_id
      AND tm.role = 'admin'
      AND tm.status = 'active'
    )
    OR
    -- Vérifier si l'utilisateur est system_admin
    EXISTS(
      SELECT 1 FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id = p_user_id 
      AND r.name = 'system_admin'
    )
    OR
    -- Vérifier si l'utilisateur est project_manager pour ce projet
    EXISTS(
      SELECT 1 FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id = p_user_id
      AND r.name = 'project_manager'
      AND ur.project_id = v_task.project_id
    )
  ) THEN
    RAISE EXCEPTION 'Permissions insuffisantes pour modifier cette tâche';
  END IF;
  
  -- 5. D'abord supprimer toutes les associations d'équipes existantes
  DELETE FROM team_tasks 
  WHERE task_id = p_task_id;
  
  -- 6. Ensuite mettre à jour la tâche pour enlever l'assignation individuelle
  UPDATE tasks 
  SET 
    assigned_to = NULL,
    updated_at = NOW()
  WHERE id = p_task_id;
  
  -- 7. Finalement ajouter la nouvelle association d'équipe
  INSERT INTO team_tasks (task_id, team_id) 
  VALUES (p_task_id, p_team_id);
  
  -- 8. Journaliser l'opération dans l'historique des tâches
  INSERT INTO task_history (
    task_id,
    field_name,
    old_value,
    new_value,
    changed_by,
    timestamp
  ) VALUES (
    p_task_id,
    'assigned_to_team',
    CASE WHEN v_task.assigned_to IS NOT NULL THEN v_task.assigned_to ELSE 'Aucun assigné' END,
    'Équipe: ' || v_team.name,
    p_user_id,
    NOW()
  );
  
  -- 9. Retourner un résultat complet
  SELECT 
    jsonb_build_object(
      'success', true,
      'task_id', p_task_id,
      'team_id', p_team_id,
      'team_name', v_team.name,
      'previous_assigned_to', v_task.assigned_to,
      'phase_id', v_task.phase_id,
      'timestamp', NOW()
    ) INTO v_result;
  
  RETURN v_result;
  
EXCEPTION WHEN OTHERS THEN
  -- En cas d'erreur, retourner un message d'erreur avec les détails
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM,
    'detail', SQLSTATE
  );
END;
$$;

-- Fonction complémentaire pour assigner une tâche à un utilisateur
CREATE OR REPLACE FUNCTION public.assign_task_to_user(
  p_task_id UUID,
  p_user_id UUID,
  p_assigner_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_task RECORD;
  v_user RECORD;
  v_result JSONB;
BEGIN
  -- 1. Vérifications de sécurité
  IF p_assigner_id IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié';
  END IF;
  
  -- 2. Vérifier que la tâche existe
  SELECT id, title, assigned_to, project_id, phase_id INTO v_task 
  FROM tasks 
  WHERE id = p_task_id;
  
  IF v_task.id IS NULL THEN
    RAISE EXCEPTION 'Tâche non trouvée';
  END IF;
  
  -- 3. Vérifier que l'utilisateur assigné existe
  SELECT id, display_name INTO v_user 
  FROM profiles 
  WHERE id = p_user_id;
  
  IF v_user.id IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non trouvé';
  END IF;
  
  -- 4. Vérifier les autorisations (comme précédemment)
  IF NOT (
    EXISTS(SELECT 1 FROM tasks WHERE id = p_task_id AND (created_by = p_assigner_id OR assigned_to = p_assigner_id::text))
    OR
    EXISTS(
      SELECT 1 FROM team_tasks tt
      JOIN team_members tm ON tt.team_id = tm.team_id
      WHERE tt.task_id = p_task_id
      AND tm.user_id = p_assigner_id
      AND tm.role = 'admin'
      AND tm.status = 'active'
    )
    OR
    EXISTS(
      SELECT 1 FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id = p_assigner_id 
      AND r.name = 'system_admin'
    )
    OR
    EXISTS(
      SELECT 1 FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id = p_assigner_id
      AND r.name = 'project_manager'
      AND ur.project_id = v_task.project_id
    )
  ) THEN
    RAISE EXCEPTION 'Permissions insuffisantes pour modifier cette tâche';
  END IF;
  
  -- 5. D'abord supprimer toutes les associations d'équipes
  DELETE FROM team_tasks 
  WHERE task_id = p_task_id;
  
  -- 6. Ensuite mettre à jour la tâche pour attribuer à l'utilisateur
  UPDATE tasks 
  SET 
    assigned_to = p_user_id::text,
    updated_at = NOW()
  WHERE id = p_task_id;
  
  -- 7. Journaliser l'opération dans l'historique des tâches
  INSERT INTO task_history (
    task_id,
    field_name,
    old_value,
    new_value,
    changed_by,
    timestamp
  ) VALUES (
    p_task_id,
    'assigned_to',
    CASE 
      WHEN v_task.assigned_to IS NOT NULL THEN v_task.assigned_to 
      ELSE 'Équipe'
    END,
    p_user_id::text,
    p_assigner_id,
    NOW()
  );
  
  -- 8. Retourner un résultat complet
  SELECT 
    jsonb_build_object(
      'success', true,
      'task_id', p_task_id,
      'user_id', p_user_id,
      'user_name', v_user.display_name,
      'previous_assigned_to', v_task.assigned_to,
      'phase_id', v_task.phase_id,
      'timestamp', NOW()
    ) INTO v_result;
  
  RETURN v_result;
  
EXCEPTION WHEN OTHERS THEN
  -- En cas d'erreur, retourner un message d'erreur
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM,
    'detail', SQLSTATE
  );
END;
$$;

-- Accorder les permissions d'exécution
GRANT EXECUTE ON FUNCTION public.assign_task_to_team TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_task_to_user TO authenticated;
