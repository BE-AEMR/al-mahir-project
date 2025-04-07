-- Remplacer la politique de sélection existante pour les phases
DROP POLICY IF EXISTS "Utilisateurs peuvent voir les phases des projets auxquels ils appartiennent" ON public.phases;

-- Nouvelle politique qui prend en compte les équipes
CREATE POLICY "Utilisateurs peuvent voir les phases des projets auxquels ils appartiennent" ON public.phases
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = phases.project_id
            AND (
                projects.created_by = auth.uid() OR
                auth.uid()::text = ANY(projects.members) OR
                EXISTS (
                    SELECT 1 FROM public.team_projects tp
                    JOIN public.team_members tm ON tp.team_id = tm.team_id
                    WHERE tp.project_id = phases.project_id
                    AND tm.user_id = auth.uid()
                    AND tm.status = 'active'
                )
            )
        )
    );

-- Mettre à jour la politique d'insertion des phases
DROP POLICY IF EXISTS "Utilisateurs peuvent créer des phases pour leurs projets" ON public.phases;

CREATE POLICY "Utilisateurs peuvent créer des phases pour leurs projets" ON public.phases
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = phases.project_id
            AND (
                projects.created_by = auth.uid() OR
                auth.uid()::text = ANY(projects.members) OR
                EXISTS (
                    SELECT 1 FROM public.team_projects tp
                    JOIN public.team_members tm ON tp.team_id = tm.team_id
                    WHERE tp.project_id = phases.project_id
                    AND tm.user_id = auth.uid()
                    AND tm.status = 'active'
                )
            )
        )
    );

-- Mettre à jour la politique de mise à jour des phases
DROP POLICY IF EXISTS "Utilisateurs peuvent mettre à jour les phases de leurs projets" ON public.phases;

CREATE POLICY "Utilisateurs peuvent mettre à jour les phases de leurs projets" ON public.phases
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = phases.project_id
            AND (
                projects.created_by = auth.uid() OR
                auth.uid()::text = ANY(projects.members) OR
                EXISTS (
                    SELECT 1 FROM public.team_projects tp
                    JOIN public.team_members tm ON tp.team_id = tm.team_id
                    WHERE tp.project_id = phases.project_id
                    AND tm.user_id = auth.uid()
                    AND tm.status = 'active'
                )
            )
        )
    );

-- Corriger également les politiques pour les tâches afin que les membres d'équipe puissent voir les tâches liées aux phases
DROP POLICY IF EXISTS "Utilisateurs peuvent voir les tâches des projets auxquels ils appartiennent" ON public.tasks;

CREATE POLICY "Utilisateurs peuvent voir les tâches des projets auxquels ils appartiennent" ON public.tasks
    FOR SELECT
    USING (
        (
            EXISTS (
                SELECT 1 FROM public.projects
                WHERE projects.id = tasks.project_id
                AND (
                    projects.created_by = auth.uid() OR
                    auth.uid()::text = ANY(projects.members) OR
                    EXISTS (
                        SELECT 1 FROM public.team_projects tp
                        JOIN public.team_members tm ON tp.team_id = tm.team_id
                        WHERE tp.project_id = tasks.project_id
                        AND tm.user_id = auth.uid()
                        AND tm.status = 'active'
                    )
                )
            )
        )
    );

-- Mettre à jour les politiques d'insertion, mise à jour et suppression pour les tâches similairement
DROP POLICY IF EXISTS "Utilisateurs peuvent créer des tâches pour les projets auxquels ils appartiennent" ON public.tasks;

CREATE POLICY "Utilisateurs peuvent créer des tâches pour les projets auxquels ils appartiennent" ON public.tasks
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = tasks.project_id
            AND (
                projects.created_by = auth.uid() OR
                auth.uid()::text = ANY(projects.members) OR
                EXISTS (
                    SELECT 1 FROM public.team_projects tp
                    JOIN public.team_members tm ON tp.team_id = tm.team_id
                    WHERE tp.project_id = tasks.project_id
                    AND tm.user_id = auth.uid()
                    AND tm.status = 'active'
                )
            )
        )
    );

DROP POLICY IF EXISTS "Utilisateurs peuvent mettre à jour les tâches des projets auxquels ils appartiennent" ON public.tasks;

CREATE POLICY "Utilisateurs peuvent mettre à jour les tâches des projets auxquels ils appartiennent" ON public.tasks
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = tasks.project_id
            AND (
                projects.created_by = auth.uid() OR
                auth.uid()::text = ANY(projects.members) OR
                EXISTS (
                    SELECT 1 FROM public.team_projects tp
                    JOIN public.team_members tm ON tp.team_id = tm.team_id
                    WHERE tp.project_id = tasks.project_id
                    AND tm.user_id = auth.uid()
                    AND tm.status = 'active'
                )
            )
        )
    );
