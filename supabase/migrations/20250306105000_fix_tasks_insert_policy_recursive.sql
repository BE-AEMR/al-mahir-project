-- Correction des politiques d'insertion pour les tâches (correction de la récursion infinie)
-- Permettre aux utilisateurs d'insérer des tâches et de les assigner à des membres d'équipe ou à des équipes

-- Vérifier et créer la politique d'insertion manquante
DROP POLICY IF EXISTS "Users can insert tasks" ON public.tasks;

CREATE POLICY "Users can insert tasks" ON public.tasks
  FOR INSERT WITH CHECK (
    -- L'utilisateur peut toujours créer une tâche
    -- La tâche peut être assignée à l'utilisateur lui-même, à un autre membre de l'équipe, ou à personne (si assignée à une équipe)
    created_by = auth.uid() AND
    (
      -- Assignée à personne (car assignée à une équipe)
      assigned_to IS NULL OR
      
      -- Assignée à l'utilisateur lui-même
      assigned_to = auth.uid()::text OR
      
      -- Assignée à un autre membre d'une équipe dont l'utilisateur est admin
      EXISTS (
        SELECT 1 FROM team_members tm
        JOIN team_members current_user_tm ON tm.team_id = current_user_tm.team_id
        WHERE tm.user_id::text = assigned_to
        AND current_user_tm.user_id = auth.uid()
        AND current_user_tm.role = 'admin'
        AND tm.status = 'active'
        AND current_user_tm.status = 'active'
      )
    )
  );

-- Mettre à jour la politique de sélection pour prendre en compte les projets
DROP POLICY IF EXISTS "Users can view their assigned tasks or team tasks" ON public.tasks;

CREATE POLICY "Users can view their assigned tasks or team tasks" ON public.tasks
  FOR SELECT USING (
    -- Assignée directement à l'utilisateur
    assigned_to = auth.uid()::text OR
    
    -- Créée par l'utilisateur
    created_by = auth.uid() OR
    
    -- Associée à une équipe dont l'utilisateur est membre
    EXISTS (
      SELECT 1 FROM team_tasks tt
      JOIN team_members tm ON tt.team_id = tm.team_id
      WHERE tt.task_id = tasks.id
      AND tm.user_id = auth.uid()
      AND tm.status = 'active'
    ) OR
    
    -- Associée à un projet où l'utilisateur est membre d'une équipe
    EXISTS (
      SELECT 1 FROM projects p
      JOIN team_projects tp ON p.id = tp.project_id
      JOIN team_members tm ON tp.team_id = tm.team_id
      WHERE tasks.project_id = p.id
      AND tm.user_id = auth.uid()
      AND tm.status = 'active'
    )
  );
