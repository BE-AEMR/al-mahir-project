-- +migrate Up
-- +migrate StatementBegin

-- Ce script ajoute des politiques RLS pour la table des invitations
-- afin de permettre à tous les utilisateurs de récupérer une invitation par son token

-- Supprimer la politique existante si elle existe
DROP POLICY IF EXISTS "Allow users to select invitations by token" ON public.invitations;

-- Créer une nouvelle politique qui permet à n'importe quel utilisateur authentifié
-- de voir une invitation en utilisant son token
CREATE POLICY "Allow users to select invitations by token" 
ON public.invitations FOR SELECT 
USING (auth.role() = 'authenticated');

-- Remarque: Cette politique est assez permissive et permet à tout utilisateur authentifié
-- de voir toutes les invitations. Si vous préférez une approche plus restrictive,
-- vous pourriez utiliser une condition comme:
-- USING ((auth.uid() = invited_by) OR (email = auth.email()) OR (token IS NOT NULL));

-- +migrate StatementEnd
