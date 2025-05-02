-- Script pour supprimer tous les enregistrements d'un utilisateur spécifique dans la table rbac_logs
DELETE FROM public.rbac_logs 
WHERE user_id = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';
