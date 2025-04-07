-- Solution simple sans manipulation de trigger
CREATE OR REPLACE FUNCTION public.accept_team_invitation_by_token(p_token text)
RETURNS void AS $$
DECLARE
  v_invitation_id uuid;
  v_team_id uuid;
  v_invited_by uuid;
  v_user_id uuid;
  v_role_id uuid;
  v_now timestamp with time zone;
BEGIN
  -- Obtenir l'ID de l'utilisateur courant
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non connecté';
  END IF;
  
  -- Récupérer les informations de l'invitation
  SELECT id, team_id, invited_by INTO v_invitation_id, v_team_id, v_invited_by
  FROM public.invitations
  WHERE token = p_token
    AND status = 'pending';
    
  IF v_invitation_id IS NULL THEN
    RAISE EXCEPTION 'Aucune invitation en attente trouvée avec ce code';
  END IF;
  
  -- Vérifier si l'invitation est expirée
  IF (SELECT expires_at FROM public.invitations WHERE id = v_invitation_id) < now() THEN
    UPDATE public.invitations SET status = 'expired' WHERE id = v_invitation_id;
    RAISE EXCEPTION 'Cette invitation a expiré';
  END IF;
  
  -- Récupérer l'ID du rôle team_member
  SELECT id INTO v_role_id FROM public.roles WHERE name = 'team_member';
  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'Rôle team_member introuvable';
  END IF;
  
  v_now := now();
  
  -- Traitement pour team_members - Approche atomique
  PERFORM id FROM public.team_members 
  WHERE team_id = v_team_id AND user_id = v_user_id;
  
  IF FOUND THEN
    -- Mettre à jour le membre existant
    UPDATE public.team_members
    SET status = 'active', 
        role = 'member',
        joined_at = COALESCE(joined_at, v_now)
    WHERE team_id = v_team_id AND user_id = v_user_id;
  ELSE
    BEGIN
      -- Insérer un nouveau membre
      INSERT INTO public.team_members(id, team_id, user_id, role, status, invited_by, joined_at)
      VALUES (gen_random_uuid(), v_team_id, v_user_id, 'member', 'active', v_invited_by, v_now);
    EXCEPTION WHEN others THEN
      -- Ignorer les erreurs et réessayer avec une mise à jour
      UPDATE public.team_members
      SET status = 'active', 
          role = 'member',
          joined_at = COALESCE(joined_at, v_now)
      WHERE team_id = v_team_id AND user_id = v_user_id;
    END;
  END IF;
  
  -- Traitement pour user_roles - Approche atomique et indépendante
  PERFORM id FROM public.user_roles
  WHERE user_id = v_user_id AND team_id = v_team_id AND role_id = v_role_id;
  
  IF NOT FOUND THEN
    BEGIN
      -- Insérer le rôle uniquement s'il n'existe pas déjà
      INSERT INTO public.user_roles(id, user_id, role_id, team_id, project_id, created_by)
      VALUES (gen_random_uuid(), v_user_id, v_role_id, v_team_id, NULL, v_invited_by);
    EXCEPTION WHEN others THEN
      -- Si erreur, ignorer (probablement déjà inséré entre-temps)
      NULL;
    END;
  END IF;
  
  -- Mettre à jour le statut de l'invitation
  UPDATE public.invitations
  SET status = 'accepted'
  WHERE id = v_invitation_id;
  
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Créer une politique permettant d'appeler cette fonction
DROP POLICY IF EXISTS "Utilisateurs authentifiés peuvent appeler accept_team_invitation_by_token" ON public.invitations;
CREATE POLICY "Utilisateurs authentifiés peuvent appeler accept_team_invitation_by_token" 
ON public.invitations 
FOR ALL 
TO authenticated
USING (true);

-- Permettre aux utilisateurs authentifiés d'appeler la fonction
GRANT EXECUTE ON FUNCTION public.accept_team_invitation_by_token TO authenticated;
