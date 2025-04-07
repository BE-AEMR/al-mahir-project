-- Ce script corrige la relation entre team_members et profiles

-- Supprimer d'abord l'ancienne contrainte de clé étrangère si elle existe
ALTER TABLE IF EXISTS public.team_members
DROP CONSTRAINT IF EXISTS team_members_user_id_fkey;

-- Ajouter une nouvelle contrainte de clé étrangère qui pointe à la fois vers auth.users et profiles
-- Note: on peut avoir plusieurs contraintes sur la même colonne
ALTER TABLE public.team_members
ADD CONSTRAINT team_members_user_id_profiles_fkey
FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Recréer la contrainte originale vers auth.users si nécessaire
ALTER TABLE public.team_members
ADD CONSTRAINT team_members_user_id_auth_users_fkey
FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Pour être sûr, on rafraîchit le cache de schéma de Supabase
NOTIFY pgrst, 'reload schema';
