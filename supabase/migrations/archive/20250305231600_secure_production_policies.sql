-- Migration avec des politiques sécurisées pour la production
-- Remplace les politiques temporaires permissives

-- Supprimer toutes les politiques temporaires
DROP POLICY IF EXISTS "Temporary allow all operations on users" ON auth.users;
DROP POLICY IF EXISTS "Temporary allow all operations on invitations" ON public.invitations;
DROP POLICY IF EXISTS "Temporary allow all operations on team_members" ON public.team_members;
DROP POLICY IF EXISTS "Temporary allow all operations on teams" ON public.teams;
DROP POLICY IF EXISTS "Temporary allow all operations on profiles" ON public.profiles;

-- 1. POLITIQUES POUR AUTH.USERS
-- Permet à un utilisateur de voir son propre enregistrement
CREATE POLICY "Users can view their own user data" 
ON auth.users FOR SELECT 
USING (auth.uid() = id);

-- Permet à un utilisateur de voir les enregistrements des utilisateurs qui sont membres des mêmes équipes
CREATE POLICY "Users can view team members" 
ON auth.users FOR SELECT 
USING (
  id IN (
    -- Utilisateurs qui sont membres d'équipes dont l'utilisateur actuel est membre
    SELECT tm.user_id 
    FROM public.team_members tm 
    WHERE tm.team_id IN (
      -- Équipes dont l'utilisateur actuel est membre
      SELECT team_id 
      FROM public.team_members 
      WHERE user_id = auth.uid() AND status = 'active'
    )
    AND tm.status = 'active'
  )
);

-- 2. POLITIQUES POUR INVITATIONS
-- SELECT: Permet à un utilisateur de voir les invitations où il est l'invité ou l'invitant
CREATE POLICY "Users can view invitations they sent or received" 
ON public.invitations FOR SELECT 
USING (
  invited_by = auth.uid() OR 
  email = (SELECT email FROM auth.users WHERE id = auth.uid())
);

-- SELECT: Permet à un utilisateur de voir n'importe quelle invitation par son token (pour rejoindre une équipe)
CREATE POLICY "Users can view invitations by token" 
ON public.invitations FOR SELECT 
USING (token IS NOT NULL);

-- UPDATE: Permet à un utilisateur de mettre à jour les invitations qu'il a envoyées
CREATE POLICY "Users can update invitations they sent" 
ON public.invitations FOR UPDATE
USING (invited_by = auth.uid());

-- UPDATE: Permet à un utilisateur de mettre à jour les invitations qu'il a reçues
CREATE POLICY "Users can update invitations they received" 
ON public.invitations FOR UPDATE
USING (email = (SELECT email FROM auth.users WHERE id = auth.uid()));

-- INSERT: Permet à un utilisateur d'envoyer des invitations s'il est membre d'une équipe
CREATE POLICY "Team members can create invitations" 
ON public.invitations FOR INSERT 
WITH CHECK (
  invited_by = auth.uid() AND 
  team_id IN (
    SELECT team_id 
    FROM public.team_members 
    WHERE user_id = auth.uid() AND status = 'active'
  )
);

-- 3. POLITIQUES POUR TEAM_MEMBERS
-- SELECT: Permet à un utilisateur de voir les membres des équipes dont il fait partie
CREATE POLICY "Users can view members of their teams" 
ON public.team_members FOR SELECT 
USING (
  team_id IN (
    SELECT team_id 
    FROM public.team_members 
    WHERE user_id = auth.uid() AND status = 'active'
  )
);

-- INSERT: Permet à un utilisateur de s'ajouter à une équipe s'il a une invitation valide
CREATE POLICY "Users can join teams they were invited to" 
ON public.team_members FOR INSERT 
WITH CHECK (
  user_id = auth.uid() AND 
  team_id IN (
    SELECT team_id 
    FROM public.invitations 
    WHERE email = (SELECT email FROM auth.users WHERE id = auth.uid()) AND status = 'pending'
  )
);

-- UPDATE: Permet à un utilisateur de mettre à jour son propre statut de membre
CREATE POLICY "Users can update their own team membership" 
ON public.team_members FOR UPDATE 
USING (user_id = auth.uid());

-- 4. POLITIQUES POUR PROFILES
-- SELECT: Permet à un utilisateur de voir son propre profil
CREATE POLICY "Users can view their own profile" 
ON public.profiles FOR SELECT 
USING (id = auth.uid());

-- SELECT: Permet aux utilisateurs de voir les profils des membres de leurs équipes
CREATE POLICY "Users can view profiles of team members" 
ON public.profiles FOR SELECT 
USING (
  id IN (
    SELECT user_id 
    FROM public.team_members 
    WHERE team_id IN (
      SELECT team_id 
      FROM public.team_members 
      WHERE user_id = auth.uid() AND status = 'active'
    )
  )
);

-- UPDATE: Permet à un utilisateur de mettre à jour son propre profil
CREATE POLICY "Users can update their own profile" 
ON public.profiles FOR UPDATE 
USING (id = auth.uid());

-- INSERT: Permet à un utilisateur de créer son propre profil
CREATE POLICY "Users can insert their own profile" 
ON public.profiles FOR INSERT 
WITH CHECK (id = auth.uid());

-- 5. POLITIQUES POUR TEAMS
-- SELECT: Permet à un utilisateur de voir les équipes dont il est membre
CREATE POLICY "Users can view their teams" 
ON public.teams FOR SELECT 
USING (
  id IN (
    SELECT team_id 
    FROM public.team_members 
    WHERE user_id = auth.uid() AND status = 'active'
  )
);

-- UPDATE: Permet à un administrateur d'équipe de mettre à jour les détails de l'équipe
CREATE POLICY "Team admins can update team details" 
ON public.teams FOR UPDATE 
USING (
  id IN (
    SELECT team_id 
    FROM public.team_members 
    WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  )
);

-- INSERT: Permet à un utilisateur de créer une nouvelle équipe
CREATE POLICY "Users can create teams" 
ON public.teams FOR INSERT 
WITH CHECK (true);
