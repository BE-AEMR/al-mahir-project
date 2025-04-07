-- Activer l'extension uuid-ossp pour générer des UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table des projets
CREATE TABLE IF NOT EXISTS public.projects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ,
  created_by UUID REFERENCES auth.users(id),
  members TEXT[] DEFAULT '{}',
  status TEXT NOT NULL
);

-- Table des tâches
CREATE TABLE IF NOT EXISTS public.tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ,
  due_date TIMESTAMPTZ,
  assigned_to TEXT NOT NULL,
  created_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL,
  priority INTEGER NOT NULL
);

-- Activer la sécurité par ligne (RLS)
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Politique pour les projets: un utilisateur peut voir ses propres projets
DROP POLICY IF EXISTS "Users can view their own projects" ON public.projects;
CREATE POLICY "Users can view their own projects" ON public.projects
  FOR SELECT USING (auth.uid() = created_by);

-- Politique pour les projets: un utilisateur peut insérer ses propres projets
DROP POLICY IF EXISTS "Users can insert their own projects" ON public.projects;
CREATE POLICY "Users can insert their own projects" ON public.projects
  FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Politique pour les projets: un utilisateur peut mettre à jour ses propres projets
DROP POLICY IF EXISTS "Users can update their own projects" ON public.projects;
CREATE POLICY "Users can update their own projects" ON public.projects
  FOR UPDATE USING (auth.uid() = created_by);

-- Politique pour les projets: un utilisateur peut supprimer ses propres projets
DROP POLICY IF EXISTS "Users can delete their own projects" ON public.projects;
CREATE POLICY "Users can delete their own projects" ON public.projects
  FOR DELETE USING (auth.uid() = created_by);

-- Politique pour les tâches: un utilisateur peut voir les tâches des projets qu'il a créés
DROP POLICY IF EXISTS "Users can view tasks of their projects" ON public.tasks;
CREATE POLICY "Users can view tasks of their projects" ON public.tasks
  FOR SELECT USING (
    auth.uid() = created_by OR 
    auth.uid() IN (
      SELECT created_by FROM public.projects WHERE id = project_id
    )
  );

-- Politique pour les tâches: un utilisateur peut insérer des tâches dans ses propres projets
DROP POLICY IF EXISTS "Users can insert tasks in their projects" ON public.tasks;
CREATE POLICY "Users can insert tasks in their projects" ON public.tasks
  FOR INSERT WITH CHECK (
    auth.uid() IN (
      SELECT created_by FROM public.projects WHERE id = project_id
    )
  );

-- Politique pour les tâches: un utilisateur peut mettre à jour les tâches de ses propres projets
DROP POLICY IF EXISTS "Users can update tasks in their projects" ON public.tasks;
CREATE POLICY "Users can update tasks in their projects" ON public.tasks
  FOR UPDATE USING (
    auth.uid() = created_by OR 
    auth.uid() IN (
      SELECT created_by FROM public.projects WHERE id = project_id
    )
  );

-- Politique pour les tâches: un utilisateur peut supprimer les tâches de ses propres projets
DROP POLICY IF EXISTS "Users can delete tasks in their projects" ON public.tasks;
CREATE POLICY "Users can delete tasks in their projects" ON public.tasks
  FOR DELETE USING (
    auth.uid() = created_by OR 
    auth.uid() IN (
      SELECT created_by FROM public.projects WHERE id = project_id
    )
  );
