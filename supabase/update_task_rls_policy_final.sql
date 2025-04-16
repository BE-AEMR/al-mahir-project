-- Script SQL pour mettre à jour la politique RLS des tâches
-- Ce script ajoute les vérifications de rôles system_admin et project_manager à la politique existante

-- Supprimer la politique existante
DROP POLICY IF EXISTS "Users can update their assigned tasks or team tasks" ON public.tasks;

-- Recréer la politique avec les nouvelles vérifications de rôles
CREATE POLICY "Users can update their assigned tasks or team tasks" ON public.tasks
  FOR UPDATE USING (
    -- Conditions existantes
    assigned_to = auth.uid()::text OR 
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM team_tasks tt
      JOIN team_members tm ON tt.team_id = tm.team_id
      WHERE tt.task_id = tasks.id
      AND tm.user_id = auth.uid()
      AND tm.role = 'admin'
      AND tm.status = 'active'
    ) OR
    -- Nouvelles conditions pour les rôles spéciaux
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
    )
  );

-- Script de restauration en cas de problème
-- Pour revenir à la version précédente, exécutez ce qui suit :
/*
DROP POLICY IF EXISTS "Users can update their assigned tasks or team tasks" ON public.tasks;

CREATE POLICY "Users can update their assigned tasks or team tasks" ON public.tasks
  FOR UPDATE USING (
    assigned_to = auth.uid()::text OR 
    created_by = auth.uid() OR 
    EXISTS (
      SELECT 1 FROM team_tasks tt
      JOIN team_members tm ON tt.team_id = tm.team_id
      WHERE tt.task_id = tasks.id
      AND tm.user_id = auth.uid()
      AND tm.role = 'admin'
      AND tm.status = 'active'
    )
  );
*/
