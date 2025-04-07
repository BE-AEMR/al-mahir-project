-- Ce script ajoute des politiques RLS pour la table des invitations
-- afin de permettre à tous les utilisateurs de récupérer une invitation par son token

-- Supprimer la politique existante si elle existe
DROP POLICY IF EXISTS "Allow users to select invitations by token" ON public.invitations;

-- Créer une nouvelle politique qui permet à n'importe quel utilisateur authentifié
-- de voir une invitation en utilisant son token
CREATE POLICY "Allow users to select invitations by token" 
ON public.invitations FOR SELECT 
USING (auth.role() = 'authenticated');
