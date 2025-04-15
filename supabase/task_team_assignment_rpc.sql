-- Fonction RPC pour gérer correctement l'assignation de tâches aux équipes
-- Cette fonction effectue toutes les opérations nécessaires dans une transaction avec
-- les privilèges SECURITY DEFINER pour contourner les limitations de RLS

-- Créer une fonction qui gère à la fois la désassignation de l'utilisateur
-- et l'association à une équipe en une seule transaction
CREATE OR REPLACE FUNCTION assign_task_to_team(
  p_task_id UUID,
  p_team_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_task RECORD;
  v_result JSONB;
  v_old_assigned_to TEXT;
  v_task_exists BOOLEAN;
  v_team_exists BOOLEAN;
BEGIN
  -- Vérifier que la tâche existe
  SELECT EXISTS (SELECT 1 FROM tasks WHERE id = p_task_id) INTO v_task_exists;
  IF NOT v_task_exists THEN
    RETURN jsonb_build_object('success', false, 'error', 'Task not found');
  END IF;

  -- Vérifier que l'équipe existe
  SELECT EXISTS (SELECT 1 FROM teams WHERE id = p_team_id) INTO v_team_exists;
  IF NOT v_team_exists THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team not found');
  END IF;

  -- Récupérer l'état actuel de la tâche pour logging
  SELECT id, title, assigned_to, project_id, phase_id, status INTO v_task 
  FROM tasks 
  WHERE id = p_task_id;
  
  v_old_assigned_to := v_task.assigned_to;
  
  -- 1. Supprimer toutes les associations d'équipes existantes pour cette tâche
  DELETE FROM team_tasks WHERE task_id = p_task_id;
  
  -- 2. Créer la nouvelle association d'équipe
  INSERT INTO team_tasks (task_id, team_id) 
  VALUES (p_task_id, p_team_id);
  
  -- 3. Mettre à jour la tâche pour supprimer l'assignation individuelle
  UPDATE tasks 
  SET 
    assigned_to = NULL,
    updated_at = NOW()
  WHERE id = p_task_id;
  
  -- 4. Ajouter une entrée dans l'historique des tâches si elle existe
  BEGIN
    INSERT INTO task_history (
      task_id, 
      field_name, 
      old_value, 
      new_value, 
      changed_by, 
      change_time
    ) VALUES (
      p_task_id, 
      'assigned_to', 
      v_old_assigned_to, 
      'Team Assignment: ' || p_team_id::TEXT, 
      auth.uid(), 
      NOW()
    );
  EXCEPTION WHEN OTHERS THEN
    -- Ignorer les erreurs si la table n'existe pas
    NULL;
  END;
  
  -- Récupérer l'état final de la tâche
  SELECT 
    jsonb_build_object(
      'success', true,
      'task_id', t.id,
      'team_id', p_team_id,
      'old_assigned_to', v_old_assigned_to,
      'assigned_to', t.assigned_to,
      'team_name', tm.name
    ) INTO v_result
  FROM tasks t
  LEFT JOIN team_tasks tt ON t.id = tt.task_id
  LEFT JOIN teams tm ON tt.team_id = tm.id
  WHERE t.id = p_task_id;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour désassigner une tâche d'une équipe et l'assigner à un utilisateur
CREATE OR REPLACE FUNCTION assign_task_to_user(
  p_task_id UUID,
  p_user_id TEXT
) RETURNS JSONB AS $$
DECLARE
  v_task RECORD;
  v_result JSONB;
  v_team_assignment TEXT;
  v_task_exists BOOLEAN;
  v_user_exists BOOLEAN;
BEGIN
  -- Vérifier que la tâche existe
  SELECT EXISTS (SELECT 1 FROM tasks WHERE id = p_task_id) INTO v_task_exists;
  IF NOT v_task_exists THEN
    RETURN jsonb_build_object('success', false, 'error', 'Task not found');
  END IF;

  -- Vérifier que l'utilisateur existe
  SELECT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id::UUID) INTO v_user_exists;
  IF NOT v_user_exists THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  -- Récupérer l'état actuel de la tâche pour logging
  SELECT 
    t.id, 
    t.title, 
    t.assigned_to, 
    t.project_id, 
    t.phase_id, 
    t.status,
    tm.id as team_id,
    tm.name as team_name
  INTO v_task 
  FROM tasks t
  LEFT JOIN team_tasks tt ON t.id = tt.task_id
  LEFT JOIN teams tm ON tt.team_id = tm.id
  WHERE t.id = p_task_id;
  
  IF v_task.team_id IS NOT NULL THEN
    v_team_assignment := 'Team: ' || v_task.team_name || ' (' || v_task.team_id || ')';
  ELSE
    v_team_assignment := NULL;
  END IF;
  
  -- 1. Supprimer toutes les associations d'équipes
  DELETE FROM team_tasks WHERE task_id = p_task_id;
  
  -- 2. Mettre à jour la tâche pour assigner à l'utilisateur
  UPDATE tasks 
  SET 
    assigned_to = p_user_id,
    updated_at = NOW()
  WHERE id = p_task_id;
  
  -- 3. Ajouter une entrée dans l'historique des tâches
  BEGIN
    INSERT INTO task_history (
      task_id, 
      field_name, 
      old_value, 
      new_value, 
      changed_by, 
      change_time
    ) VALUES (
      p_task_id, 
      'assigned_to', 
      COALESCE(v_task.assigned_to, v_team_assignment, 'Unassigned'), 
      p_user_id, 
      auth.uid(), 
      NOW()
    );
  EXCEPTION WHEN OTHERS THEN
    -- Ignorer les erreurs si la table n'existe pas
    NULL;
  END;
  
  -- Récupérer l'état final de la tâche
  SELECT 
    jsonb_build_object(
      'success', true,
      'task_id', t.id,
      'old_team_id', v_task.team_id,
      'old_assigned_to', v_task.assigned_to,
      'assigned_to', t.assigned_to,
      'user_name', p.display_name
    ) INTO v_result
  FROM tasks t
  LEFT JOIN profiles p ON t.assigned_to = p.id
  WHERE t.id = p_task_id;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Accorder les droits d'exécution sur ces fonctions
GRANT EXECUTE ON FUNCTION assign_task_to_team(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION assign_task_to_user(UUID, TEXT) TO authenticated;
