-- Ce script ajoute des politiques RLS pour permettre aux utilisateurs
-- de modifier les invitations et les membres d'équipe

-- Supprimer les politiques existantes si elles existent
DROP POLICY IF EXISTS "Allow users to update invitations" ON public.invitations;
DROP POLICY IF EXISTS "Allow users to insert team members" ON public.team_members;

-- Créer une politique qui permet à n'importe quel utilisateur authentifié
-- de mettre à jour une invitation (pour changer son statut)
CREATE POLICY "Allow users to update invitations" 
ON public.invitations FOR UPDATE
USING (auth.role() = 'authenticated');

-- Créer une politique qui permet à n'importe quel utilisateur authentifié
-- d'insérer un nouveau membre d'équipe (pour rejoindre une équipe)
CREATE POLICY "Allow users to insert team members" 
ON public.team_members FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Politique pour permettre la mise à jour des membres d'équipe
DROP POLICY IF EXISTS "Allow users to update team members" ON public.team_members;
CREATE POLICY "Allow users to update team members" 
ON public.team_members FOR UPDATE
USING (auth.role() = 'authenticated');
