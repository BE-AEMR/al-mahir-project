-- Modification du trigger pour traiter une transaction budgétaire
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
      -- Conversion explicite du project_id en UUID
      PERFORM update_project_budget_consumption(NEW.project_id::uuid, ABS(NEW.amount));
    END IF;
    
    -- Si la transaction est associée à une phase, mettre à jour le budget consommé de la phase
    IF NEW.phase_id IS NOT NULL AND NEW.amount < 0 THEN
      -- Conversion explicite du phase_id en UUID
      PERFORM update_phase_budget_consumption(NEW.phase_id::uuid, ABS(NEW.amount));
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
        -- Conversion explicite du project_id en UUID
        PERFORM update_project_budget_consumption(OLD.project_id::uuid, -ABS(OLD.amount));
      END IF;
      
      IF NEW.project_id IS NOT NULL AND NEW.amount < 0 THEN
        -- Conversion explicite du project_id en UUID
        PERFORM update_project_budget_consumption(NEW.project_id::uuid, ABS(NEW.amount));
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
    
    -- Gérer les réductions de budget consommé pour les projets, phases et tâches
    IF OLD.project_id IS NOT NULL AND OLD.amount < 0 THEN
      -- Conversion explicite du project_id en UUID
      PERFORM update_project_budget_consumption(OLD.project_id::uuid, -ABS(OLD.amount));
    END IF;
    
    IF OLD.phase_id IS NOT NULL AND OLD.amount < 0 THEN
      -- Conversion explicite du phase_id en UUID
      PERFORM update_phase_budget_consumption(OLD.phase_id::uuid, -ABS(OLD.amount));
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
