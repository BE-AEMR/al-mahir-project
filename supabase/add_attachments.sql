-- Création de la table des pièces jointes
CREATE TABLE IF NOT EXISTS public.attachments (
    id UUID PRIMARY KEY,
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    path TEXT NOT NULL,
    uploaded_by UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Création d'un index sur task_id
CREATE INDEX IF NOT EXISTS attachments_task_id_idx ON public.attachments(task_id);

-- Ajout des politiques RLS pour la table des pièces jointes
ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

-- Politique pour permettre aux utilisateurs de voir les pièces jointes des tâches auxquelles ils ont accès
CREATE POLICY "Utilisateurs peuvent voir les pièces jointes des tâches auxquelles ils ont accès" ON public.attachments
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.tasks
            JOIN public.projects ON tasks.project_id = projects.id
            WHERE tasks.id = attachments.task_id
            AND (
                projects.created_by = auth.uid() OR
                auth.uid()::text = ANY(projects.members) OR
                EXISTS (
                    SELECT 1 FROM public.team_projects tp
                    JOIN public.team_members tm ON tp.team_id = tm.team_id
                    WHERE tp.project_id = projects.id
                    AND tm.user_id = auth.uid()
                    AND tm.status = 'active'
                )
            )
        )
    );

-- Politique pour permettre aux utilisateurs de créer des pièces jointes pour les tâches auxquelles ils ont accès
CREATE POLICY "Utilisateurs peuvent créer des pièces jointes pour les tâches auxquelles ils ont accès" ON public.attachments
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tasks
            JOIN public.projects ON tasks.project_id = projects.id
            WHERE tasks.id = attachments.task_id
            AND (
                projects.created_by = auth.uid() OR
                auth.uid()::text = ANY(projects.members) OR
                EXISTS (
                    SELECT 1 FROM public.team_projects tp
                    JOIN public.team_members tm ON tp.team_id = tm.team_id
                    WHERE tp.project_id = projects.id
                    AND tm.user_id = auth.uid()
                    AND tm.status = 'active'
                )
            )
        )
    );

-- Politique pour permettre aux utilisateurs de supprimer leurs propres pièces jointes
CREATE POLICY "Utilisateurs peuvent supprimer leurs propres pièces jointes" ON public.attachments
    FOR DELETE
    USING (
        uploaded_by = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.tasks
            JOIN public.projects ON tasks.project_id = projects.id
            WHERE tasks.id = attachments.task_id
            AND projects.created_by = auth.uid()
        )
    );

-- Création du bucket de stockage pour les pièces jointes si nécessaire
-- Note: La commande suivante doit être exécutée dans l'interface utilisateur de Supabase
-- ou par une API appropriée, car elle ne peut pas être exécutée directement en SQL
-- INSERT INTO storage.buckets (id, name, public) VALUES ('task-attachments', 'task-attachments', true);
