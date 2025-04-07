-- Fonction pour mettre à jour le budget consommé d'une phase
CREATE OR REPLACE FUNCTION update_phase_budget_consumption(p_phase_id text, p_amount double precision)
RETURNS void AS $$
BEGIN
  -- Mettre à jour le budget consommé de la phase
  UPDATE phases
  SET 
    budget_consumed = COALESCE(budget_consumed, 0) + p_amount,
    updated_at = NOW()
  WHERE id = p_phase_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour mettre à jour le budget consommé d'un projet
CREATE OR REPLACE FUNCTION update_project_budget_consumption(p_project_id text, p_amount double precision)
RETURNS void AS $$
BEGIN
  -- Mettre à jour le budget consommé du projet
  UPDATE projects
  SET 
    budget_consumed = COALESCE(budget_consumed, 0) + p_amount,
    updated_at = NOW()
  WHERE id = p_project_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour recalculer le budget total consommé d'une phase
CREATE OR REPLACE FUNCTION recalculate_phase_budget_consumption(p_phase_id text)
RETURNS void AS $$
DECLARE
  v_total_consumed double precision := 0;
BEGIN
  -- Calculer le total consommé par les tâches
  SELECT COALESCE(SUM(COALESCE(budget_consumed, 0)), 0)
  INTO v_total_consumed
  FROM tasks
  WHERE phase_id = p_phase_id;
  
  -- Mettre à jour le budget consommé de la phase
  UPDATE phases
  SET 
    budget_consumed = v_total_consumed,
    updated_at = NOW()
  WHERE id = p_phase_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour recalculer le budget total consommé d'un projet
CREATE OR REPLACE FUNCTION recalculate_project_budget_consumption(p_project_id text)
RETURNS void AS $$
DECLARE
  v_tasks_consumed double precision := 0;
  v_phases_tasks_consumed double precision := 0;
BEGIN
  -- Calculer le total consommé par les tâches directement liées au projet (sans phase)
  SELECT COALESCE(SUM(COALESCE(budget_consumed, 0)), 0)
  INTO v_tasks_consumed
  FROM tasks
  WHERE project_id = p_project_id AND phase_id IS NULL;
  
  -- Calculer le total consommé par les tâches des phases du projet
  SELECT COALESCE(SUM(COALESCE(budget_consumed, 0)), 0)
  INTO v_phases_tasks_consumed
  FROM tasks
  WHERE project_id = p_project_id AND phase_id IS NOT NULL;
  
  -- Mettre à jour le budget consommé du projet
  UPDATE projects
  SET 
    budget_consumed = v_tasks_consumed + v_phases_tasks_consumed,
    updated_at = NOW()
  WHERE id = p_project_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour propager une allocation de budget d'un budget global à un projet
CREATE OR REPLACE FUNCTION allocate_budget_to_project(p_budget_id text, p_project_id text, p_amount double precision)
RETURNS void AS $$
DECLARE
  v_budget_current_amount double precision;
BEGIN
  -- Vérifier si le budget a suffisamment de fonds
  SELECT current_amount INTO v_budget_current_amount
  FROM budgets
  WHERE id = p_budget_id;
  
  IF v_budget_current_amount < p_amount THEN
    RAISE EXCEPTION 'Budget insuffisant: % disponible, % demandé', v_budget_current_amount, p_amount;
  END IF;
  
  -- Mettre à jour le montant actuel du budget global
  UPDATE budgets
  SET 
    current_amount = current_amount - p_amount,
    updated_at = NOW()
  WHERE id = p_budget_id;
  
  -- Mettre à jour le budget alloué du projet
  UPDATE projects
  SET 
    budget_allocated = COALESCE(budget_allocated, 0) + p_amount,
    updated_at = NOW()
  WHERE id = p_project_id;
  
  -- Insérer une entrée dans la table des allocations budgétaires
  INSERT INTO budget_allocations (
    id, 
    budget_id, 
    project_id, 
    amount, 
    allocation_date, 
    created_at, 
    created_by
  )
  VALUES (
    gen_random_uuid(), 
    p_budget_id, 
    p_project_id, 
    p_amount, 
    NOW(), 
    NOW(), 
    auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour traiter une transaction budgétaire
CREATE OR REPLACE FUNCTION process_budget_transaction()
RETURNS TRIGGER AS $$
BEGIN
  -- Si c'est une insertion
  IF TG_OP = 'INSERT' THEN
    -- Si la transaction est associée à un budget, mettre à jour le montant du budget
    IF NEW.budget_id IS NOT NULL THEN
      UPDATE budgets
      SET 
        current_amount = current_amount + NEW.amount,
        updated_at = NOW()
      WHERE id = NEW.budget_id;
    END IF;
    
    -- Si la transaction est associée à un projet, mettre à jour le budget consommé du projet
    IF NEW.project_id IS NOT NULL AND NEW.amount < 0 THEN
      PERFORM update_project_budget_consumption(NEW.project_id, ABS(NEW.amount));
    END IF;
    
    -- Si la transaction est associée à une phase, mettre à jour le budget consommé de la phase
    IF NEW.phase_id IS NOT NULL AND NEW.amount < 0 THEN
      PERFORM update_phase_budget_consumption(NEW.phase_id, ABS(NEW.amount));
    END IF;
    
    -- Si la transaction est associée à une tâche, mettre à jour le budget consommé de la tâche
    IF NEW.task_id IS NOT NULL AND NEW.amount < 0 THEN
      UPDATE tasks
      SET 
        budget_consumed = COALESCE(budget_consumed, 0) + ABS(NEW.amount),
        updated_at = NOW()
      WHERE id = NEW.task_id;
      
      -- Recalculer le budget consommé de la phase (si applicable)
      IF NEW.phase_id IS NOT NULL THEN
        PERFORM recalculate_phase_budget_consumption(NEW.phase_id);
      END IF;
      
      -- Recalculer le budget consommé du projet
      PERFORM recalculate_project_budget_consumption(NEW.project_id);
    END IF;
  
  -- Si c'est une mise à jour
  ELSIF TG_OP = 'UPDATE' THEN
    -- Si la transaction est associée à un budget, ajuster le montant du budget
    IF NEW.budget_id IS NOT NULL THEN
      UPDATE budgets
      SET 
        current_amount = current_amount - OLD.amount + NEW.amount,
        updated_at = NOW()
      WHERE id = NEW.budget_id;
    END IF;
    
    -- Gérer les modifications de budget consommé pour les projets, phases et tâches
    -- Cette partie est simplifiée, mais vous pourriez ajouter des logiques plus complexes
    IF NEW.project_id IS NOT NULL OR OLD.project_id IS NOT NULL THEN
      IF OLD.project_id IS NOT NULL AND NEW.amount <> OLD.amount AND OLD.amount < 0 THEN
        PERFORM update_project_budget_consumption(OLD.project_id, -ABS(OLD.amount));
      END IF;
      
      IF NEW.project_id IS NOT NULL AND NEW.amount < 0 THEN
        PERFORM update_project_budget_consumption(NEW.project_id, ABS(NEW.amount));
      END IF;
    END IF;
  
  -- Si c'est une suppression
  ELSIF TG_OP = 'DELETE' THEN
    -- Si la transaction est associée à un budget, ajuster le montant du budget
    IF OLD.budget_id IS NOT NULL THEN
      UPDATE budgets
      SET 
        current_amount = current_amount - OLD.amount,
        updated_at = NOW()
      WHERE id = OLD.budget_id;
    END IF;
    
    -- Si la transaction est associée à un projet, ajuster le budget consommé
    IF OLD.project_id IS NOT NULL AND OLD.amount < 0 THEN
      PERFORM update_project_budget_consumption(OLD.project_id, -ABS(OLD.amount));
    END IF;
    
    -- Si la transaction est associée à une phase, ajuster le budget consommé
    IF OLD.phase_id IS NOT NULL AND OLD.amount < 0 THEN
      PERFORM update_phase_budget_consumption(OLD.phase_id, -ABS(OLD.amount));
    END IF;
    
    -- Si la transaction est associée à une tâche, ajuster le budget consommé
    IF OLD.task_id IS NOT NULL AND OLD.amount < 0 THEN
      UPDATE tasks
      SET 
        budget_consumed = GREATEST(0, COALESCE(budget_consumed, 0) - ABS(OLD.amount)),
        updated_at = NOW()
      WHERE id = OLD.task_id;
      
      -- Recalculer le budget consommé de la phase (si applicable)
      IF OLD.phase_id IS NOT NULL THEN
        PERFORM recalculate_phase_budget_consumption(OLD.phase_id);
      END IF;
      
      -- Recalculer le budget consommé du projet
      PERFORM recalculate_project_budget_consumption(OLD.project_id);
    END IF;
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Créer le déclencheur pour les transactions budgétaires
DROP TRIGGER IF EXISTS budget_transaction_trigger ON budget_transactions;
CREATE TRIGGER budget_transaction_trigger
AFTER INSERT OR UPDATE OR DELETE ON budget_transactions
FOR EACH ROW EXECUTE PROCEDURE process_budget_transaction();

-- Trigger pour mettre à jour le budget du projet quand une tâche est mise à jour
CREATE OR REPLACE FUNCTION task_budget_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
  -- Si le budget consommé a changé
  IF OLD.budget_consumed IS DISTINCT FROM NEW.budget_consumed THEN
    -- Si la tâche appartient à une phase, mettre à jour le budget de la phase
    IF NEW.phase_id IS NOT NULL THEN
      PERFORM update_phase_budget_consumption(NEW.phase_id, NEW.budget_consumed - COALESCE(OLD.budget_consumed, 0));
    END IF;
    
    -- Mettre à jour le budget du projet
    PERFORM update_project_budget_consumption(NEW.project_id, NEW.budget_consumed - COALESCE(OLD.budget_consumed, 0));
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Créer le trigger sur la table des tâches
DROP TRIGGER IF EXISTS task_budget_trigger ON tasks;
CREATE TRIGGER task_budget_trigger
AFTER UPDATE ON tasks
FOR EACH ROW
WHEN (OLD.budget_consumed IS DISTINCT FROM NEW.budget_consumed)
EXECUTE FUNCTION task_budget_trigger_function();
