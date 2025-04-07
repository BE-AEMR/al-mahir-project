-- Create task_comments table
CREATE TABLE IF NOT EXISTS public.task_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    comment TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_task_comments_task_id ON public.task_comments(task_id);
CREATE INDEX IF NOT EXISTS idx_task_comments_user_id ON public.task_comments(user_id);

-- Enable Row Level Security
ALTER TABLE public.task_comments ENABLE ROW LEVEL SECURITY;

-- Create trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at
BEFORE UPDATE ON public.task_comments
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- RLS Policies

-- SELECT policy - Users can view comments for tasks they have access to
CREATE POLICY "Users can view comments for tasks they have access to" ON public.task_comments
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.tasks
    WHERE tasks.id = task_comments.task_id
    AND (
      -- Task creator
      tasks.created_by = auth.uid()
      -- Task is assigned to the user
      OR tasks.assigned_to = auth.uid()::text
      -- User is member of a team assigned to the task
      OR EXISTS (
        SELECT 1 FROM public.team_tasks tt
        JOIN public.team_members tm ON tt.team_id = tm.team_id
        WHERE tt.task_id = task_comments.task_id
        AND tm.user_id = auth.uid()
        AND tm.status = 'active'
      )
      -- User is member of team associated with project
      OR EXISTS (
        SELECT 1 FROM public.tasks t
        JOIN public.team_projects tp ON t.project_id = tp.project_id
        JOIN public.team_members tm ON tp.team_id = tm.team_id
        WHERE t.id = task_comments.task_id
        AND tm.user_id = auth.uid()
        AND tm.status = 'active'
      )
    )
  )
);

-- INSERT policy - Users can add comments to tasks they have access to
CREATE POLICY "Users can add comments to tasks they have access to" ON public.task_comments
FOR INSERT WITH CHECK (
  auth.uid() = user_id
  AND EXISTS (
    SELECT 1 FROM public.tasks
    WHERE tasks.id = task_comments.task_id
    AND (
      -- Task creator
      tasks.created_by = auth.uid()
      -- Task is assigned to the user
      OR tasks.assigned_to = auth.uid()::text
      -- User is member of a team assigned to the task
      OR EXISTS (
        SELECT 1 FROM public.team_tasks tt
        JOIN public.team_members tm ON tt.team_id = tm.team_id
        WHERE tt.task_id = task_comments.task_id
        AND tm.user_id = auth.uid()
        AND tm.status = 'active'
      )
      -- User is member of team associated with project
      OR EXISTS (
        SELECT 1 FROM public.tasks t
        JOIN public.team_projects tp ON t.project_id = tp.project_id
        JOIN public.team_members tm ON tp.team_id = tm.team_id
        WHERE t.id = task_comments.task_id
        AND tm.user_id = auth.uid()
        AND tm.status = 'active'
      )
    )
  )
);

-- UPDATE policy - Users can only update their own comments
CREATE POLICY "Users can update their own comments" ON public.task_comments
FOR UPDATE USING (
  auth.uid() = user_id
);

-- DELETE policy - Users can delete their own comments
CREATE POLICY "Users can delete their own comments" ON public.task_comments
FOR DELETE USING (
  auth.uid() = user_id
);

-- Project creators and admins can delete any comments on their project tasks
CREATE POLICY "Project admins can delete any comments" ON public.task_comments
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM public.tasks t
    JOIN public.projects p ON t.project_id = p.id
    WHERE t.id = task_comments.task_id
    AND p.created_by = auth.uid()
  )
  OR
  EXISTS (
    SELECT 1 FROM public.tasks t
    JOIN public.team_projects tp ON t.project_id = tp.project_id
    JOIN public.team_members tm ON tp.team_id = tm.team_id
    WHERE t.id = task_comments.task_id
    AND tm.user_id = auth.uid()
    AND tm.role = 'admin'
    AND tm.status = 'active'
  )
);
