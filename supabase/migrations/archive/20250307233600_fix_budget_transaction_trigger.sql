-- Suppression du déclencheur existant s'il existe
DROP TRIGGER IF EXISTS budget_transaction_trigger ON budget_transactions;

-- Suppression de la fonction existante
DROP FUNCTION IF EXISTS process_budget_transaction();

-- Recréation de la fonction avec des conversions explicites de type
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
    
    -- Si la transaction est associée à un projet et que c'est une dépense (montant négatif),
    -- mettre à jour le budget consommé du projet
    IF NEW.project_id IS NOT NULL AND NEW.amount < 0 THEN
      -- Utilisation de l'appel RPC directement dans le trigger avec conversion explicite
      PERFORM public.update_project_budget_consumption(
        p_project_id := NEW.project_id,
        p_amount := ABS(NEW.amount)
      );
    END IF;
    
    -- Si la transaction est associée à une phase et que c'est une dépense (montant négatif),
    -- mettre à jour le budget consommé de la phase
    IF NEW.phase_id IS NOT NULL AND NEW.amount < 0 THEN
      -- Utilisation de l'appel RPC directement dans le trigger avec conversion explicite
      PERFORM public.update_phase_budget_consumption(
        p_phase_id := NEW.phase_id,
        p_amount := ABS(NEW.amount)
      );
    END IF;
    
    -- Si la transaction est associée à une tâche et que c'est une dépense (montant négatif),
    -- mettre à jour le budget consommé de la tâche
    IF NEW.task_id IS NOT NULL AND NEW.amount < 0 THEN
      UPDATE tasks
      SET 
        budget_consumed = COALESCE(budget_consumed, 0) + ABS(NEW.amount),
        updated_at = NOW()
      WHERE id = NEW.task_id;
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
    IF NEW.project_id IS NOT NULL OR OLD.project_id IS NOT NULL THEN
      -- Si l'ancien enregistrement avait un projet et que c'était une dépense
      IF OLD.project_id IS NOT NULL AND OLD.amount < 0 AND 
         (NEW.project_id IS NULL OR NEW.project_id <> OLD.project_id OR NEW.amount <> OLD.amount) THEN
        -- Réduire le budget consommé de l'ancien projet
        PERFORM public.update_project_budget_consumption(
          p_project_id := OLD.project_id,
          p_amount := -ABS(OLD.amount)
        );
      END IF;
      
      -- Si le nouvel enregistrement a un projet et que c'est une dépense
      IF NEW.project_id IS NOT NULL AND NEW.amount < 0 AND 
         (OLD.project_id IS NULL OR NEW.project_id <> OLD.project_id OR NEW.amount <> OLD.amount) THEN
        -- Augmenter le budget consommé du nouveau projet
        PERFORM public.update_project_budget_consumption(
          p_project_id := NEW.project_id,
          p_amount := ABS(NEW.amount)
        );
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
    
    -- Si la transaction supprimée était associée à un projet et que c'était une dépense,
    -- réduire le budget consommé du projet
    IF OLD.project_id IS NOT NULL AND OLD.amount < 0 THEN
      PERFORM public.update_project_budget_consumption(
        p_project_id := OLD.project_id,
        p_amount := -ABS(OLD.amount)
      );
    END IF;
    
    -- Si la transaction supprimée était associée à une phase et que c'était une dépense,
    -- réduire le budget consommé de la phase
    IF OLD.phase_id IS NOT NULL AND OLD.amount < 0 THEN
      PERFORM public.update_phase_budget_consumption(
        p_phase_id := OLD.phase_id,
        p_amount := -ABS(OLD.amount)
      );
    END IF;
  END IF;
  
  -- Pour les opérations INSERT et UPDATE, retourner NEW, pour DELETE retourner OLD
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Création du nouveau déclencheur
CREATE TRIGGER budget_transaction_trigger
AFTER INSERT OR UPDATE OR DELETE ON budget_transactions
FOR EACH ROW EXECUTE FUNCTION process_budget_transaction();
