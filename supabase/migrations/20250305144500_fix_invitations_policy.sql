-- Ce script corrige les politiques RLS pour la table invitations
-- pour éviter d'accéder directement à auth.users

-- Supprimer la politique existante qui cause l'erreur de permission
DROP POLICY IF EXISTS "invitations_select_received_policy" ON public.invitations;

-- Créer une nouvelle politique qui utilise auth.jwt() au lieu d'accéder directement à auth.users
CREATE POLICY "invitations_select_received_policy" 
ON public.invitations FOR SELECT 
USING (
  -- Utiliser le claim email du JWT au lieu d'accéder à auth.users
  email = (SELECT coalesce(nullif(current_setting('request.jwt.claim.email', true), ''), 
                          nullif(current_setting('request.jwt.claims.email', true), ''))
          )
);
