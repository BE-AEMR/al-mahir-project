-- Procédure pour ajouter les permissions de base au rôle observateur
-- Comme ces permissions sont fondamentales pour le fonctionnement de ce rôle,
-- elles sont prédéfinies dans cette procédure

CREATE OR REPLACE FUNCTION add_observer_permissions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_observer_role_id uuid;
  v_read_task_permission_id uuid;
  v_read_phase_permission_id uuid;
  v_read_transaction_permission_id uuid;
BEGIN
  -- Récupérer l'ID du rôle observateur
  SELECT id INTO v_observer_role_id 
  FROM roles 
  WHERE name = 'observer';
  
  IF v_observer_role_id IS NULL THEN
    RAISE EXCEPTION 'Rôle observateur non trouvé dans la base de données';
  END IF;
  
  -- Récupérer les IDs des permissions de base
  SELECT id INTO v_read_task_permission_id 
  FROM permissions 
  WHERE name = 'read_task';
  
  SELECT id INTO v_read_phase_permission_id 
  FROM permissions 
  WHERE name = 'read_phase';
  
  SELECT id INTO v_read_transaction_permission_id 
  FROM permissions 
  WHERE name = 'read_transaction';
  
  -- Vérifier que toutes les permissions nécessaires existent
  IF v_read_task_permission_id IS NULL OR v_read_phase_permission_id IS NULL OR v_read_transaction_permission_id IS NULL THEN
    RAISE EXCEPTION 'Une ou plusieurs permissions de base non trouvées';
  END IF;
  
  -- Ajouter les permissions si elles n'existent pas déjà pour ce rôle
  INSERT INTO role_permissions (id, role_id, permission_id)
  SELECT gen_random_uuid(), v_observer_role_id, v_read_task_permission_id
  WHERE NOT EXISTS (
    SELECT 1 FROM role_permissions 
    WHERE role_id = v_observer_role_id AND permission_id = v_read_task_permission_id
  );
  
  INSERT INTO role_permissions (id, role_id, permission_id)
  SELECT gen_random_uuid(), v_observer_role_id, v_read_phase_permission_id
  WHERE NOT EXISTS (
    SELECT 1 FROM role_permissions 
    WHERE role_id = v_observer_role_id AND permission_id = v_read_phase_permission_id
  );
  
  INSERT INTO role_permissions (id, role_id, permission_id)
  SELECT gen_random_uuid(), v_observer_role_id, v_read_transaction_permission_id
  WHERE NOT EXISTS (
    SELECT 1 FROM role_permissions 
    WHERE role_id = v_observer_role_id AND permission_id = v_read_transaction_permission_id
  );
  
  RAISE NOTICE 'Permissions de base ajoutées avec succès au rôle observateur';
END;
$$;

-- Exécuter immédiatement la fonction pour s'assurer que les permissions sont à jour
SELECT add_observer_permissions();
