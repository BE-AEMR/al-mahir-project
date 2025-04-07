-- Ce script crée une table profiles pour stocker les informations publiques des utilisateurs
-- et configure les déclencheurs nécessaires pour maintenir les données synchronisées

-- Fonction pour gérer l'insertion automatique dans profiles lors de la création d'un utilisateur
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name, avatar_url, updated_at)
  VALUES (new.id, new.email, COALESCE(new.raw_user_meta_data->>'display_name', new.email), new.raw_user_meta_data->>'avatar_url', now());
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Créer la table profiles si elle n'existe pas
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ajouter un index sur l'email pour les recherches rapides
CREATE INDEX IF NOT EXISTS profiles_email_idx ON public.profiles(email);

-- Activer la sécurité au niveau des lignes (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Supprimer le déclencheur s'il existe déjà pour éviter les doublons
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Créer un déclencheur pour insérer un profil lorsqu'un nouvel utilisateur est créé
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Politiques RLS pour la table profiles

-- Politique pour permettre à tous les utilisateurs authentifiés de voir les profils
CREATE POLICY "profiles_select_policy" 
ON public.profiles FOR SELECT 
USING (auth.role() = 'authenticated');

-- Politique pour permettre aux utilisateurs de mettre à jour uniquement leur propre profil
CREATE POLICY "profiles_update_policy" 
ON public.profiles FOR UPDATE 
USING (id = auth.uid());

-- Insérer les profils pour les utilisateurs existants si nécessaire
INSERT INTO public.profiles (id, email, display_name, avatar_url, updated_at)
SELECT 
  id, 
  email, 
  COALESCE(raw_user_meta_data->>'display_name', email),
  raw_user_meta_data->>'avatar_url',
  now()
FROM auth.users
ON CONFLICT (id) DO NOTHING;
