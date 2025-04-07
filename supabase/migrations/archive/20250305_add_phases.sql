-- Création de la table des phases
CREATE TABLE IF NOT EXISTS public.phases (
    id UUID PRIMARY KEY,
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by UUID NOT NULL REFERENCES auth.users(id),
    order_index INTEGER NOT NULL,
    status TEXT NOT NULL,
    CONSTRAINT phases_status_check CHECK (status IN ('not_started', 'in_progress', 'completed', 'on_hold', 'cancelled'))
);

-- Ajout des politiques RLS pour la table des phases
ALTER TABLE public.phases ENABLE ROW LEVEL SECURITY;

-- Politique pour permettre aux utilisateurs de voir les phases des projets auxquels ils appartiennent
CREATE POLICY "Utilisateurs peuvent voir les phases des projets auxquels ils appartiennent" ON public.phases
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = phases.project_id
            AND (
                projects.created_by = auth.uid() OR
                auth.uid()::text = ANY(projects.members)
            )
        )
    );

-- Politique pour permettre aux utilisateurs de créer des phases pour les projets auxquels ils appartiennent
CREATE POLICY "Utilisateurs peuvent créer des phases pour leurs projets" ON public.phases
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = phases.project_id
            AND (
                projects.created_by = auth.uid() OR
                auth.uid()::text = ANY(projects.members)
            )
        )
    );

-- Politique pour permettre aux utilisateurs de mettre à jour les phases des projets auxquels ils appartiennent
CREATE POLICY "Utilisateurs peuvent mettre à jour les phases de leurs projets" ON public.phases
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = phases.project_id
            AND (
                projects.created_by = auth.uid() OR
                auth.uid()::text = ANY(projects.members)
            )
        )
    );

-- Politique pour permettre aux utilisateurs de supprimer les phases des projets qu'ils ont créés
CREATE POLICY "Utilisateurs peuvent supprimer les phases des projets qu'ils ont créés" ON public.phases
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = phases.project_id
            AND projects.created_by = auth.uid()
        )
    );

-- Ajout de la colonne phase_id à la table des tâches
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS phase_id UUID REFERENCES public.phases(id) ON DELETE SET NULL;

-- Création d'un index sur la colonne phase_id
CREATE INDEX IF NOT EXISTS tasks_phase_id_idx ON public.tasks(phase_id);

-- Création d'un index sur project_id dans la table des phases
CREATE INDEX IF NOT EXISTS phases_project_id_idx ON public.phases(project_id);

-- Mise à jour des déclencheurs pour les tâches
CREATE OR REPLACE FUNCTION public.handle_task_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Vérifier que la tâche est associée à un projet valide
    IF NOT EXISTS (SELECT 1 FROM public.projects WHERE id = NEW.project_id) THEN
      RAISE EXCEPTION 'Le projet spécifié n''existe pas';
    END IF;
    
    -- Vérifier que la phase est associée au même projet que la tâche (si une phase est spécifiée)
    IF NEW.phase_id IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.phases 
        WHERE id = NEW.phase_id AND project_id = NEW.project_id
      ) THEN
        RAISE EXCEPTION 'La phase spécifiée n''appartient pas au projet spécifié';
      END IF;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Vérifier que la phase est associée au même projet que la tâche (si une phase est spécifiée)
    IF NEW.phase_id IS NOT NULL AND NEW.phase_id != OLD.phase_id THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.phases 
        WHERE id = NEW.phase_id AND project_id = NEW.project_id
      ) THEN
        RAISE EXCEPTION 'La phase spécifiée n''appartient pas au projet spécifié';
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Supprimer le déclencheur existant s'il existe
DROP TRIGGER IF EXISTS task_validation_trigger ON public.tasks;

-- Créer le nouveau déclencheur
CREATE TRIGGER task_validation_trigger
BEFORE INSERT OR UPDATE ON public.tasks
FOR EACH ROW
EXECUTE FUNCTION public.handle_task_changes();
