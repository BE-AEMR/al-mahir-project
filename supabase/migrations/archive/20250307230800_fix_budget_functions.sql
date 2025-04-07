-- Fonction pour mettre à jour le budget consommé d'une phase (acceptant UUID comme type d'ID)
CREATE OR REPLACE FUNCTION update_phase_budget_consumption(p_phase_id uuid, p_amount numeric)
RETURNS void AS $$
BEGIN
  -- Mettre à jour le budget consommé de la phase
  UPDATE phases
  SET 
    budget_consumed = COALESCE(budget_consumed, 0) + p_amount,
    updated_at = NOW()
  WHERE id = p_phase_id::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour mettre à jour le budget consommé d'un projet (acceptant UUID comme type d'ID)
CREATE OR REPLACE FUNCTION update_project_budget_consumption(p_project_id uuid, p_amount numeric)
RETURNS void AS $$
BEGIN
  -- Mettre à jour le budget consommé du projet
  UPDATE projects
  SET 
    budget_consumed = COALESCE(budget_consumed, 0) + p_amount,
    updated_at = NOW()
  WHERE id = p_project_id::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
