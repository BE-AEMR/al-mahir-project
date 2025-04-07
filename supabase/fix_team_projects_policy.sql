-- Ce script corrige la politique RLS pour l'insertion dans la table team_projects
-- Le problème: Actuellement, seul le créateur de l'équipe peut ajouter des projets à cette équipe
-- La solution: Permettre aussi aux administrateurs de l'équipe d'ajouter des projets

-- 1. Suppression de la politique existante
DROP POLICY IF EXISTS "team_projects_insert_policy" ON public.team_projects;

-- 2. Création de la nouvelle politique
CREATE POLICY "team_projects_insert_policy" ON "public"."team_projects" 
FOR INSERT WITH CHECK (
  -- Permet au créateur de l'équipe d'ajouter des projets
  ("team_id" IN ( 
    SELECT "teams"."id" FROM "public"."teams" WHERE ("teams"."created_by" = "auth"."uid"())
  ))
  OR
  -- Permet aux administrateurs de l'équipe d'ajouter des projets
  ("team_id" IN (
    SELECT "team_id" FROM "public"."team_members" 
    WHERE "user_id" = "auth"."uid"() AND "role" = 'admin' AND "status" = 'active'
  ))
);

-- Affichage d'un message de confirmation
SELECT 'Politique team_projects_insert_policy mise à jour avec succès' as message;
