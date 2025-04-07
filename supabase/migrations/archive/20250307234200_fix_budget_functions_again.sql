-- Correction des fonctions de mise à jour du budget
CREATE OR REPLACE FUNCTION update_phase_budget_consumption(p_phase_id uuid, p_amount numeric)
RETURNS void AS $$
BEGIN
  -- Mettre à jour le budget consommé de la phase - SANS conversion ::text
  UPDATE phases
  SET 
    budget_consumed = COALESCE(budget_consumed, 0) + p_amount,
    updated_at = NOW()
  WHERE id = p_phase_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour mettre à jour le budget consommé d'un projet (acceptant UUID comme type d'ID)
CREATE OR REPLACE FUNCTION update_project_budget_consumption(p_project_id uuid, p_amount numeric)
RETURNS void AS $$
BEGIN
  -- Mettre à jour le budget consommé du projet - SANS conversion ::text
  UPDATE projects
  SET 
    budget_consumed = COALESCE(budget_consumed, 0) + p_amount,
    updated_at = NOW()
  WHERE id = p_project_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour recalculer le budget consommé d'une phase
CREATE OR REPLACE FUNCTION recalculate_phase_budget_consumption(p_phase_id uuid)
RETURNS void AS $$
DECLARE
  total_consumed numeric;
BEGIN
  -- Calculer le budget consommé total à partir des tâches
  SELECT COALESCE(SUM(budget_consumed), 0)
  INTO total_consumed
  FROM tasks
  WHERE phase_id = p_phase_id;
  
  -- Mettre à jour le budget consommé de la phase
  UPDATE phases
  SET 
    budget_consumed = total_consumed,
    updated_at = NOW()
  WHERE id = p_phase_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour recalculer le budget consommé d'un projet
CREATE OR REPLACE FUNCTION recalculate_project_budget_consumption(p_project_id uuid)
RETURNS void AS $$
DECLARE
  total_consumed numeric;
BEGIN
  -- Calculer le budget consommé total à partir des phases
  SELECT COALESCE(SUM(budget_consumed), 0)
  INTO total_consumed
  FROM phases
  WHERE project_id = p_project_id;
  
  -- Mettre à jour le budget consommé du projet
  UPDATE projects
  SET 
    budget_consumed = total_consumed,
    updated_at = NOW()
  WHERE id = p_project_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
