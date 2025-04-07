-- Fix des politiques RLS pour la table rbac_logs
-- Ce script ajoute les politiques RLS nécessaires pour permettre l'écriture dans la table rbac_logs

-- Activer RLS sur la table
ALTER TABLE public.rbac_logs ENABLE ROW LEVEL SECURITY;

-- Supprimer les anciennes politiques si elles existent
DROP POLICY IF EXISTS "rbac_logs_insert_policy" ON public.rbac_logs;
DROP POLICY IF EXISTS "rbac_logs_select_policy" ON public.rbac_logs;

-- Politique permettant à tout utilisateur authentifié d'insérer des logs
CREATE POLICY "rbac_logs_insert_policy"
ON public.rbac_logs
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Politique permettant aux administrateurs système et à l'utilisateur concerné de voir ses propres logs
CREATE POLICY "rbac_logs_select_policy"
ON public.rbac_logs
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = auth.uid() AND r.name = 'system_admin'
  )
);

-- Confirmer que l'opération a réussi
SELECT 'Politiques RLS pour rbac_logs configurées avec succès' AS message;
