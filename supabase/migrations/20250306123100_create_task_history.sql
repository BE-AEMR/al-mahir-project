-- Création de la table d'historique des tâches
CREATE TABLE IF NOT EXISTS task_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  field_name TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  CONSTRAINT task_history_task_id_fk FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

-- Index pour accélérer les recherches par tâche
CREATE INDEX IF NOT EXISTS task_history_task_id_idx ON task_history(task_id);

-- Politique RLS pour permettre à tous les utilisateurs authentifiés de voir l'historique des tâches auxquelles ils ont accès
CREATE POLICY "Users can view task history if they can view the task" ON task_history
  FOR SELECT USING (
    auth.uid()::text IN (
      SELECT created_by::text FROM tasks WHERE id = task_id
      UNION
      SELECT assigned_to FROM tasks WHERE id = task_id AND assigned_to IS NOT NULL
      UNION
      SELECT tm.user_id::text FROM team_members tm
      JOIN team_tasks tt ON tm.team_id = tt.team_id
      WHERE tt.task_id = task_id
      UNION
      SELECT tm.user_id::text FROM team_members tm
      JOIN team_projects tp ON tm.team_id = tp.team_id
      JOIN tasks t ON tp.project_id = t.project_id
      WHERE t.id = task_id
    )
  );

-- Politique RLS pour permettre aux utilisateurs authentifiés d'insérer des entrées d'historique pour les tâches qu'ils peuvent modifier
CREATE POLICY "Users can insert task history if they can modify the task" ON task_history
  FOR INSERT WITH CHECK (
    auth.uid()::text = user_id::text AND
    auth.uid()::text IN (
      SELECT created_by::text FROM tasks WHERE id = task_id
      UNION
      SELECT assigned_to FROM tasks WHERE id = task_id AND assigned_to IS NOT NULL
      UNION
      SELECT tm.user_id::text FROM team_members tm
      JOIN team_tasks tt ON tm.team_id = tt.team_id
      WHERE tt.task_id = task_id
      UNION
      SELECT tm.user_id::text FROM team_members tm
      JOIN team_projects tp ON tm.team_id = tp.team_id
      JOIN tasks t ON tp.project_id = t.project_id
      WHERE t.id = task_id
    )
  );

-- Activer la sécurité au niveau des lignes (RLS)
ALTER TABLE task_history ENABLE ROW LEVEL SECURITY;
