-- Créer une table de journalisation pour tracer les modifications de tâches
CREATE TABLE IF NOT EXISTS public.task_update_logs (
  id SERIAL PRIMARY KEY,
  task_id UUID NOT NULL,
  operation VARCHAR(10) NOT NULL,
  user_id UUID,
  old_data JSONB,
  new_data JSONB,
  changes JSONB,
  rls_result BOOLEAN, -- Si la mise à jour a réussi ou échoué en raison des politiques RLS
  error_message TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Activer la journalisation RLS dans PostgreSQL (nécessite des droits superutilisateur)
ALTER SYSTEM SET log_statement = 'all';
-- Note: Vous devrez peut-être redémarrer le serveur PostgreSQL pour que ce paramètre prenne effet

-- Fonction pour tracer les tentatives de mise à jour de tâches
CREATE OR REPLACE FUNCTION public.log_task_updates()
RETURNS TRIGGER AS $$
DECLARE
  v_changes JSONB;
  v_user_id UUID;
BEGIN
  -- Obtenir l'ID de l'utilisateur actuel
  v_user_id := auth.uid();
  
  -- Calculer les changements
  v_changes := jsonb_build_object(
    'assigned_to', CASE WHEN OLD.assigned_to IS DISTINCT FROM NEW.assigned_to THEN jsonb_build_object('old', OLD.assigned_to, 'new', NEW.assigned_to) ELSE NULL END,
    'team_id', CASE WHEN OLD.team_id IS DISTINCT FROM NEW.team_id THEN jsonb_build_object('old', OLD.team_id, 'new', NEW.team_id) ELSE NULL END,
    'status', CASE WHEN OLD.status IS DISTINCT FROM NEW.status THEN jsonb_build_object('old', OLD.status, 'new', NEW.status) ELSE NULL END
  );
  
  -- Enregistrer la tentative
  INSERT INTO public.task_update_logs (
    task_id,
    operation,
    user_id,
    old_data,
    new_data,
    changes,
    rls_result,
    timestamp
  ) VALUES (
    NEW.id,
    TG_OP,
    v_user_id,
    to_jsonb(OLD),
    to_jsonb(NEW),
    v_changes,
    TRUE, -- Si nous arrivons ici, c'est que la politique RLS a permis l'opération
    NOW()
  );
  
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- En cas d'erreur, journaliser également
  INSERT INTO public.task_update_logs (
    task_id,
    operation,
    user_id,
    old_data,
    new_data,
    changes,
    rls_result,
    error_message,
    timestamp
  ) VALUES (
    OLD.id,
    TG_OP,
    v_user_id,
    to_jsonb(OLD),
    NULL,
    NULL,
    FALSE,
    SQLERRM,
    NOW()
  );
  
  RAISE; -- Propager l'erreur
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Créer le trigger sur la table des tâches
DROP TRIGGER IF EXISTS task_update_trigger ON public.tasks;
CREATE TRIGGER task_update_trigger
BEFORE UPDATE ON public.tasks
FOR EACH ROW
EXECUTE FUNCTION public.log_task_updates();

-- Créer une vue pour faciliter la consultation des logs
CREATE OR REPLACE VIEW public.task_update_audit AS
SELECT 
  l.id,
  l.task_id,
  t.title AS task_title,
  l.operation,
  p.display_name AS user_name,
  l.user_id,
  l.changes,
  l.rls_result,
  l.error_message,
  l.timestamp
FROM 
  public.task_update_logs l
LEFT JOIN 
  public.tasks t ON l.task_id = t.id
LEFT JOIN 
  public.profiles p ON l.user_id = p.id
ORDER BY 
  l.timestamp DESC;

-- Accorder les permissions nécessaires
ALTER TABLE public.task_update_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can see all logs" ON public.task_update_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM user_roles ur
      JOIN roles r ON ur.role_id = r.id
      WHERE ur.user_id = auth.uid() AND r.name = 'system_admin'
    )
  );

CREATE POLICY "Users can see their own logs" ON public.task_update_logs
  FOR SELECT USING (user_id = auth.uid());

GRANT SELECT ON public.task_update_audit TO authenticated;
GRANT SELECT, INSERT ON public.task_update_logs TO authenticated;
