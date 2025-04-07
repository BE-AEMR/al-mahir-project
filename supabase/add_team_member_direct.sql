-- Fonction SQL pour ajouter directement un membre à une équipe
-- Cette fonction contourne le problème du client Supabase qui utilise ON CONFLICT

-- Création de la fonction pour insérer directement un membre d'équipe
CREATE OR REPLACE FUNCTION add_team_member_direct(
  p_member_id UUID,
  p_team_id UUID,
  p_user_id UUID,
  p_role TEXT,
  p_invited_by UUID
)
RETURNS VOID AS $$
BEGIN
  -- Vérifier si l'entrée existe déjà
  IF NOT EXISTS (
    SELECT 1 FROM public.team_members 
    WHERE team_id = p_team_id AND user_id = p_user_id
  ) THEN
    -- Insérer le nouveau membre
    INSERT INTO public.team_members (
      id, team_id, user_id, role, joined_at, invited_by, status
    ) VALUES (
      p_member_id, p_team_id, p_user_id, p_role, NOW(), p_invited_by, 'active'
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Accorder les permissions d'exécution
GRANT EXECUTE ON FUNCTION add_team_member_direct TO authenticated;
GRANT EXECUTE ON FUNCTION add_team_member_direct TO anon;
GRANT EXECUTE ON FUNCTION add_team_member_direct TO service_role;

-- Fonction complémentaire pour ajouter un rôle utilisateur directement
CREATE OR REPLACE FUNCTION add_user_role_direct(
  p_role_id UUID,
  p_user_id UUID,
  p_team_id UUID,
  p_role_type UUID,
  p_created_by UUID
)
RETURNS VOID AS $$
BEGIN
  -- Vérifier si l'entrée existe déjà
  IF NOT EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_id = p_user_id AND team_id = p_team_id AND role_id = p_role_type
  ) THEN
    -- Insérer le nouveau rôle
    INSERT INTO public.user_roles (
      id, user_id, role_id, team_id, project_id, created_by, created_at
    ) VALUES (
      p_role_id, p_user_id, p_role_type, p_team_id, NULL, p_created_by, NOW()
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Accorder les permissions d'exécution
GRANT EXECUTE ON FUNCTION add_user_role_direct TO authenticated;
GRANT EXECUTE ON FUNCTION add_user_role_direct TO anon;
GRANT EXECUTE ON FUNCTION add_user_role_direct TO service_role;
