-- Fix Security Advisor Supabase - Correctifs pour AL MAHIR
-- Date: 2025-04-14

-- ================================
-- CORRECTIFS DE SÉCURITÉ
-- ================================

-- 1. Correction pour l'alerte "auth_users_exposed"
-- Problème: La vue user_permissions_view expose des données d'auth.users aux utilisateurs non connectés
-- Solution: Révoquer l'accès pour le rôle anonyme uniquement, tout en maintenant l'accès pour les utilisateurs authentifiés
REVOKE ALL ON TABLE public.user_permissions_view FROM anon;

-- 2. Correction pour l'alerte "security_definer_view"
-- Problème: La fonction accept_team_invitation_by_token utilise SECURITY DEFINER sans restriction de search_path
-- Solution: Ajouter une clause search_path pour limiter la portée d'exécution de la fonction
ALTER FUNCTION public.accept_team_invitation_by_token(text) 
SET search_path = public, pg_temp;

-- ================================
-- REQUÊTES DE ROLLBACK (en cas de problème)
-- ================================

/*
-- 1. Annuler la révocation d'accès à la vue user_permissions_view
GRANT ALL ON TABLE public.user_permissions_view TO anon;

-- 2. Annuler la modification de la fonction accept_team_invitation_by_token
ALTER FUNCTION public.accept_team_invitation_by_token(text) 
RESET search_path;
*/

-- ================================
-- NOTES D'IMPLÉMENTATION
-- ================================
/*
Ces modifications sont minimalement invasives et ne devraient pas affecter le fonctionnement de l'application AL MAHIR:

1. Pour user_permissions_view:
   - Seul l'accès anonyme (non connecté) est révoqué
   - Les utilisateurs authentifiés conservent tous leurs accès
   - L'application exige déjà que les utilisateurs soient connectés pour accéder aux fonctionnalités

2. Pour accept_team_invitation_by_token:
   - La fonction conserve SECURITY DEFINER (nécessaire pour son fonctionnement)
   - L'ajout de SET search_path est une bonne pratique de sécurité
   - Aucun changement de comportement ou de logique métier

En cas de problème inattendu, utilisez les requêtes de rollback commentées ci-dessus.
*/
