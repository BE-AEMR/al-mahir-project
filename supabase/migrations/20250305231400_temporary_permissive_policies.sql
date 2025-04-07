-- Migration temporaire avec des politiques très permissives pour les tests
-- AVERTISSEMENT: Ne pas utiliser en production telles quelles !

-- Politiques très permissives pour auth.users
DROP POLICY IF EXISTS "Temporary allow all operations on users" ON auth.users;
CREATE POLICY "Temporary allow all operations on users" 
ON auth.users FOR ALL
USING (true);

-- Politiques très permissives pour toutes les autres tables importantes
-- Invitations
DROP POLICY IF EXISTS "Temporary allow all operations on invitations" ON public.invitations;
CREATE POLICY "Temporary allow all operations on invitations" 
ON public.invitations FOR ALL
USING (true);

-- Team Members
DROP POLICY IF EXISTS "Temporary allow all operations on team_members" ON public.team_members;
CREATE POLICY "Temporary allow all operations on team_members" 
ON public.team_members FOR ALL
USING (true);

-- Teams
DROP POLICY IF EXISTS "Temporary allow all operations on teams" ON public.teams;
CREATE POLICY "Temporary allow all operations on teams" 
ON public.teams FOR ALL
USING (true);

-- Profiles
DROP POLICY IF EXISTS "Temporary allow all operations on profiles" ON public.profiles;
CREATE POLICY "Temporary allow all operations on profiles" 
ON public.profiles FOR ALL
USING (true);

-- S'assurer que RLS est activé pour toutes ces tables
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
