-- Requêtes de diagnostic pour comprendre les problèmes d'assignation de tâches
-- Exécutez ces requêtes dans l'éditeur SQL de Supabase

-- 1. Examiner les logs de modifications de tâches (si vous avez appliqué le trigger)
SELECT * FROM task_update_logs
WHERE change_time > NOW() - INTERVAL '1 hour'
ORDER BY change_time DESC;

-- 2. Vérifier les éventuelles erreurs dans les requêtes SQL (nécessite des droits admin)
SELECT * FROM pg_stat_activity
WHERE application_name = 'supabase-api' 
AND query LIKE '%UPDATE "public"."tasks"%'
ORDER BY query_start DESC
LIMIT 20;

-- 3. Vérifier l'état actuel d'une tâche spécifique (remplacez TASK_ID)
SELECT 
  t.id, 
  t.title, 
  t.assigned_to, 
  t.created_by,
  t.status,
  t.updated_at,
  p.display_name as assigned_to_name,
  (SELECT COUNT(*) FROM team_tasks tt WHERE tt.task_id = t.id) as team_assignment_count
FROM tasks t
LEFT JOIN profiles p ON t.assigned_to = p.id
WHERE t.id = 'TASK_ID';

-- 4. Vérifier quelle équipe est associée à une tâche (remplacez TASK_ID)
SELECT 
  tt.task_id,
  tt.team_id,
  tm.name as team_name
FROM team_tasks tt
JOIN teams tm ON tt.team_id = tm.id
WHERE tt.task_id = 'TASK_ID';

-- 5. Tester manuellement la politique RLS - cette requête simulera ce qui se passe lorsque
-- l'application tente de mettre à jour une tâche (remplacez TASK_ID)
DO $$
DECLARE
  v_task_id UUID := 'TASK_ID'::UUID;
  v_result RECORD;
BEGIN
  -- Vérifier l'état actuel avant mise à jour
  SELECT id, title, assigned_to INTO v_result FROM tasks WHERE id = v_task_id;
  RAISE NOTICE 'État actuel - ID: %, Titre: %, Assigné à: %', 
    v_result.id, v_result.title, v_result.assigned_to;

  -- Tentative de mise à jour pour annuler l'assignation
  UPDATE tasks SET assigned_to = NULL WHERE id = v_task_id;
  
  -- Vérifier l'état après mise à jour
  SELECT id, title, assigned_to INTO v_result FROM tasks WHERE id = v_task_id;
  RAISE NOTICE 'État après mise à jour - ID: %, Titre: %, Assigné à: %', 
    v_result.id, v_result.title, v_result.assigned_to;
  
  -- Annuler la transaction pour ne pas affecter réellement les données
  RAISE EXCEPTION 'Simulation terminée, transaction annulée';
END;
$$;

-- 6. Vérifier si des hooks/triggers sur la table empêchent la mise à jour
SELECT 
  event_object_schema as schema_name,
  event_object_table as table_name,
  trigger_name,
  action_statement,
  action_timing
FROM information_schema.triggers
WHERE event_object_table = 'tasks'
ORDER BY action_timing;

-- 7. Si nous soupçonnons un problème avec les politiques RLS, nous pouvons les tester directement
-- Remplacez USER_ID par l'ID de l'utilisateur qui tente de faire la mise à jour
SELECT 
  has_role_permission('USER_ID'::UUID, 'update_task', 'PROJECT_ID'::UUID) as can_update;

-- 8. Exécuter une mise à jour directe (ATTENTION: ceci modifiera réellement les données)
-- Utilisez seulement si nécessaire pour débloquer une situation
/*
UPDATE tasks 
SET assigned_to = NULL 
WHERE id = 'TASK_ID' 
AND assigned_to IS NOT NULL 
AND EXISTS (
  SELECT 1 FROM team_tasks tt 
  WHERE tt.task_id = 'TASK_ID'
);
*/
