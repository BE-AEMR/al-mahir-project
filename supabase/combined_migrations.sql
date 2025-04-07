-- Migration pour l'assignation des tâches aux équipes (20250306093148_task_team_assignment.sql)

-- Créer une nouvelle table pour associer les tâches aux équipes
CREATE TABLE IF NOT EXISTS public.team_tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  UNIQUE(team_id, task_id)
);

-- Activer la sécurité au niveau des lignes (RLS)
ALTER TABLE public.team_tasks ENABLE ROW LEVEL SECURITY;

-- Créer les politiques RLS pour la table team_tasks
-- Politique pour voir les tâches des équipes: un utilisateur peut voir les tâches assignées à ses équipes
CREATE POLICY "Users can view their team tasks" ON public.team_tasks
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.team_id = team_tasks.team_id
      AND tm.user_id = auth.uid()
      AND tm.status = 'active'
    )
  );

-- Politique pour créer des tâches pour les équipes: un utilisateur peut assigner une tâche à son équipe s'il est admin
CREATE POLICY "Team admins can assign tasks to their teams" ON public.team_tasks
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.team_id = team_tasks.team_id
      AND tm.user_id = auth.uid()
      AND tm.role = 'admin'
      AND tm.status = 'active'
    )
  );

-- Politique pour supprimer des tâches des équipes: un utilisateur peut supprimer une tâche de son équipe s'il est admin
CREATE POLICY "Team admins can remove tasks from their teams" ON public.team_tasks
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.team_id = team_tasks.team_id
      AND tm.user_id = auth.uid()
      AND tm.role = 'admin'
      AND tm.status = 'active'
    )
  );

-- Mettre à jour la colonne assignedTo pour qu'elle soit nullable
ALTER TABLE public.tasks ALTER COLUMN assigned_to DROP NOT NULL;
ALTER TABLE public.tasks ALTER COLUMN assigned_to SET DEFAULT NULL;

-- Mettre à jour les politiques RLS pour la table des tâches
-- Permettre aux utilisateurs de voir les tâches qui leur sont assignées individuellement OU via leurs équipes
CREATE OR REPLACE POLICY "Users can view their assigned tasks or team tasks" ON public.tasks
  FOR SELECT USING (
    assigned_to = auth.uid() OR
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM team_tasks tt
      JOIN team_members tm ON tt.team_id = tm.team_id
      WHERE tt.task_id = id
      AND tm.user_id = auth.uid()
      AND tm.status = 'active'
    )
  );

-- Permettre aux utilisateurs de mettre à jour les tâches qui leur sont assignées individuellement OU via leurs équipes (s'ils sont admin)
CREATE OR REPLACE POLICY "Users can update their assigned tasks or team tasks" ON public.tasks
  FOR UPDATE USING (
    assigned_to = auth.uid() OR
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM team_tasks tt
      JOIN team_members tm ON tt.team_id = tm.team_id
      WHERE tt.task_id = id
      AND tm.user_id = auth.uid()
      AND tm.role = 'admin'
      AND tm.status = 'active'
    )
  );

-- Permettre aux utilisateurs de supprimer les tâches qu'ils ont créées OU les tâches des équipes dont ils sont admins
CREATE OR REPLACE POLICY "Users can delete their own tasks or team tasks" ON public.tasks
  FOR DELETE USING (
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM team_tasks tt
      JOIN team_members tm ON tt.team_id = tm.team_id
      WHERE tt.task_id = id
      AND tm.user_id = auth.uid()
      AND tm.role = 'admin'
      AND tm.status = 'active'
    )
  );
