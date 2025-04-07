

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pgsodium";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."accept_team_invitation_by_token"("p_token" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_invitation_id uuid;
  v_team_id uuid;
  v_invited_by uuid;
  v_user_id uuid;
  v_role_id uuid;
  v_now timestamp with time zone;
BEGIN
  -- Obtenir l'ID de l'utilisateur courant
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non connecté';
  END IF;
  
  -- Récupérer les informations de l'invitation
  SELECT id, team_id, invited_by INTO v_invitation_id, v_team_id, v_invited_by
  FROM public.invitations
  WHERE token = p_token
    AND status = 'pending';
    
  IF v_invitation_id IS NULL THEN
    RAISE EXCEPTION 'Aucune invitation en attente trouvée avec ce code';
  END IF;
  
  -- Vérifier si l'invitation est expirée
  IF (SELECT expires_at FROM public.invitations WHERE id = v_invitation_id) < now() THEN
    UPDATE public.invitations SET status = 'expired' WHERE id = v_invitation_id;
    RAISE EXCEPTION 'Cette invitation a expiré';
  END IF;
  
  -- Récupérer l'ID du rôle team_member
  SELECT id INTO v_role_id FROM public.roles WHERE name = 'team_member';
  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'Rôle team_member introuvable';
  END IF;
  
  v_now := now();
  
  -- Traitement pour team_members - Approche atomique
  PERFORM id FROM public.team_members 
  WHERE team_id = v_team_id AND user_id = v_user_id;
  
  IF FOUND THEN
    -- Mettre à jour le membre existant
    UPDATE public.team_members
    SET status = 'active', 
        role = 'member',
        joined_at = COALESCE(joined_at, v_now)
    WHERE team_id = v_team_id AND user_id = v_user_id;
  ELSE
    BEGIN
      -- Insérer un nouveau membre
      INSERT INTO public.team_members(id, team_id, user_id, role, status, invited_by, joined_at)
      VALUES (gen_random_uuid(), v_team_id, v_user_id, 'member', 'active', v_invited_by, v_now);
    EXCEPTION WHEN others THEN
      -- Ignorer les erreurs et réessayer avec une mise à jour
      UPDATE public.team_members
      SET status = 'active', 
          role = 'member',
          joined_at = COALESCE(joined_at, v_now)
      WHERE team_id = v_team_id AND user_id = v_user_id;
    END;
  END IF;
  
  -- Traitement pour user_roles - Approche atomique et indépendante
  PERFORM id FROM public.user_roles
  WHERE user_id = v_user_id AND team_id = v_team_id AND role_id = v_role_id;
  
  IF NOT FOUND THEN
    BEGIN
      -- Insérer le rôle uniquement s'il n'existe pas déjà
      INSERT INTO public.user_roles(id, user_id, role_id, team_id, project_id, created_by)
      VALUES (gen_random_uuid(), v_user_id, v_role_id, v_team_id, NULL, v_invited_by);
    EXCEPTION WHEN others THEN
      -- Si erreur, ignorer (probablement déjà inséré entre-temps)
      NULL;
    END;
  END IF;
  
  -- Mettre à jour le statut de l'invitation
  UPDATE public.invitations
  SET status = 'accepted'
  WHERE id = v_invitation_id;
  
END;
$$;


ALTER FUNCTION "public"."accept_team_invitation_by_token"("p_token" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."accept_team_invitation_by_token"("p_token" "text") IS 'Accepte une invitation d''équipe en utilisant le token d''invitation. 
Cette fonction centralise la logique pour gérer les deux systèmes (legacy et RBAC).';



CREATE OR REPLACE FUNCTION "public"."allocate_budget_to_project"("p_budget_id" "text", "p_project_id" "text", "p_amount" double precision) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_budget_current_amount double precision;
BEGIN
  -- Vérifier si le budget a suffisamment de fonds
  SELECT current_amount INTO v_budget_current_amount
  FROM budgets
  WHERE id = p_budget_id;
  
  IF v_budget_current_amount < p_amount THEN
    RAISE EXCEPTION 'Budget insuffisant: % disponible, % demandé', v_budget_current_amount, p_amount;
  END IF;
  
  -- Mettre à jour le montant actuel du budget global
  UPDATE budgets
  SET 
    current_amount = current_amount - p_amount,
    updated_at = NOW()
  WHERE id = p_budget_id;
  
  -- Mettre à jour le budget alloué du projet
  UPDATE projects
  SET 
    budget_allocated = COALESCE(budget_allocated, 0) + p_amount,
    updated_at = NOW()
  WHERE id = p_project_id;
  
  -- Insérer une entrée dans la table des allocations budgétaires
  INSERT INTO budget_allocations (
    id, 
    budget_id, 
    project_id, 
    amount, 
    allocation_date, 
    created_at, 
    created_by
  )
  VALUES (
    gen_random_uuid(), 
    p_budget_id, 
    p_project_id, 
    p_amount, 
    NOW(), 
    NOW(), 
    auth.uid()
  );
END;
$$;


ALTER FUNCTION "public"."allocate_budget_to_project"("p_budget_id" "text", "p_project_id" "text", "p_amount" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_user_role"("p_user_id" "uuid", "p_role_name" "text", "p_team_id" "uuid" DEFAULT NULL::"uuid", "p_project_id" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_role_id uuid;
BEGIN
    -- Récupérer l'ID du rôle
    SELECT id INTO v_role_id FROM roles WHERE name = p_role_name;
    
    IF v_role_id IS NULL THEN
        RAISE EXCEPTION 'Rôle non trouvé: %', p_role_name;
    END IF;
    
    -- Insérer le rôle utilisateur
    INSERT INTO user_roles (user_id, role_id, team_id, project_id)
    VALUES (p_user_id, v_role_id, p_team_id, p_project_id)
    ON CONFLICT (user_id, role_id, COALESCE(team_id, '00000000-0000-0000-0000-000000000000'::uuid), 
                COALESCE(project_id, '00000000-0000-0000-0000-000000000000'::uuid))
    DO NOTHING;
    
    RETURN true;
END;
$$;


ALTER FUNCTION "public"."assign_user_role"("p_user_id" "uuid", "p_role_name" "text", "p_team_id" "uuid", "p_project_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_access_project"("project_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Admin système
    IF user_has_permission(auth.uid(), 'read_all_projects') THEN
        RETURN true;
    END IF;
    
    -- Chef de projet ou autre rôle avec permission spécifique pour ce projet
    IF user_has_permission(auth.uid(), 'read_project', NULL, project_id) THEN
        RETURN true;
    END IF;
    
    -- Membre d'équipe associée au projet
    RETURN EXISTS (
        SELECT 1 FROM "public"."team_projects" tp
        JOIN "public"."team_members" tm ON tp.team_id = tm.team_id
        WHERE tp.project_id = project_id
        AND tm.user_id = auth.uid()
        AND tm.status = 'active'
    );
END;
$$;


ALTER FUNCTION "public"."can_access_project"("project_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_modify_project"("project_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Admin système
    IF user_has_permission(auth.uid(), 'update_project') THEN
        RETURN true;
    END IF;
    
    -- Chef de projet pour ce projet spécifique
    IF user_has_permission(auth.uid(), 'update_project', NULL, project_id) THEN
        RETURN true;
    END IF;
    
    -- Admin d'équipe associée au projet
    RETURN EXISTS (
        SELECT 1 FROM "public"."team_projects" tp
        JOIN "public"."team_members" tm ON tp.team_id = tm.team_id
        WHERE tp.project_id = project_id
        AND tm.user_id = auth.uid()
        AND tm.role = 'admin'
        AND tm.status = 'active'
    );
END;
$$;


ALTER FUNCTION "public"."can_modify_project"("project_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."clean_old_rbac_logs"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  DELETE FROM public.rbac_logs
  WHERE log_timestamp < NOW() - INTERVAL '7 days';
END;
$$;


ALTER FUNCTION "public"."clean_old_rbac_logs"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."exec_sql"("query" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  EXECUTE query;
END;
$$;


ALTER FUNCTION "public"."exec_sql"("query" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."execute_sql"("query" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    EXECUTE query;
END;
$$;


ALTER FUNCTION "public"."execute_sql"("query" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name, avatar_url, updated_at)
  VALUES (new.id, new.email, COALESCE(new.raw_user_meta_data->>'display_name', new.email), new.raw_user_meta_data->>'avatar_url', now());
  RETURN new;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_task_changes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Vérifier que la tâche est associée à un projet valide
    IF NOT EXISTS (SELECT 1 FROM public.projects WHERE id = NEW.project_id) THEN
      RAISE EXCEPTION 'Le projet spécifié n''existe pas';
    END IF;
    
    -- Vérifier que la phase est associée au même projet que la tâche (si une phase est spécifiée)
    IF NEW.phase_id IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.phases 
        WHERE id = NEW.phase_id AND project_id = NEW.project_id
      ) THEN
        RAISE EXCEPTION 'La phase spécifiée n''appartient pas au projet spécifié';
      END IF;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Vérifier que la phase est associée au même projet que la tâche (si une phase est spécifiée)
    IF NEW.phase_id IS NOT NULL AND NEW.phase_id != OLD.phase_id THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.phases 
        WHERE id = NEW.phase_id AND project_id = NEW.project_id
      ) THEN
        RAISE EXCEPTION 'La phase spécifiée n''appartient pas au projet spécifié';
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_task_changes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."migrate_team_members_to_rbac"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    count_migrated integer := 0;
    rec record;
    v_role_id uuid;
BEGIN
    -- Parcourir tous les membres d'équipe actifs
    FOR rec IN 
        SELECT 
            user_id, team_id, role
        FROM 
            team_members
        WHERE 
            status = 'active'
    LOOP
        -- Déterminer l'ID du rôle RBAC en fonction du rôle legacy
        CASE rec.role
            WHEN 'admin' THEN
                SELECT id INTO v_role_id FROM roles WHERE name = 'system_admin';
            WHEN 'member' THEN
                SELECT id INTO v_role_id FROM roles WHERE name = 'team_member';
            WHEN 'guest' THEN
                SELECT id INTO v_role_id FROM roles WHERE name = 'observer';
            ELSE
                SELECT id INTO v_role_id FROM roles WHERE name = 'observer';
        END CASE;
        
        -- Insertion dans user_roles
        INSERT INTO user_roles (user_id, role_id, team_id, project_id)
        VALUES (rec.user_id, v_role_id, rec.team_id, NULL)
        ON CONFLICT (user_id, role_id, COALESCE(team_id, '00000000-0000-0000-0000-000000000000'::uuid), 
                    COALESCE(project_id, '00000000-0000-0000-0000-000000000000'::uuid))
        DO NOTHING;
        
        count_migrated := count_migrated + 1;
    END LOOP;
    
    RETURN count_migrated;
END;
$$;


ALTER FUNCTION "public"."migrate_team_members_to_rbac"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_budget_transaction"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Si c'est une insertion
  IF TG_OP = 'INSERT' THEN
    -- Si la transaction est associée à un budget ET PAS à une phase ou une tâche,
    -- mettre à jour le montant du budget (le project_id peut être non-null)
    IF NEW.budget_id IS NOT NULL AND NEW.phase_id IS NULL AND NEW.task_id IS NULL THEN
      UPDATE budgets
      SET 
        current_amount = current_amount + NEW.amount,
        updated_at = NOW()
      WHERE id = NEW.budget_id;
    END IF;
    
    -- Si la transaction est associée à un projet et que c'est une dépense (montant négatif),
    -- mettre à jour le budget consommé du projet
    IF NEW.project_id IS NOT NULL AND NEW.amount < 0 THEN
      -- Utilisation de l'appel RPC directement dans le trigger avec conversion explicite
      PERFORM public.update_project_budget_consumption(
        p_project_id := NEW.project_id,
        p_amount := ABS(NEW.amount)
      );
    END IF;
    
    -- Si la transaction est associée à une phase et que c'est une dépense (montant négatif),
    -- mettre à jour le budget consommé de la phase
    IF NEW.phase_id IS NOT NULL AND NEW.amount < 0 THEN
      -- Utilisation de l'appel RPC directement dans le trigger avec conversion explicite
      PERFORM public.update_phase_budget_consumption(
        p_phase_id := NEW.phase_id,
        p_amount := ABS(NEW.amount)
      );
    END IF;
    
    -- Si la transaction est associée à une tâche et que c'est une dépense (montant négatif),
    -- mettre à jour le budget consommé de la tâche
    IF NEW.task_id IS NOT NULL AND NEW.amount < 0 THEN
      UPDATE tasks
      SET 
        budget_consumed = COALESCE(budget_consumed, 0) + ABS(NEW.amount),
        updated_at = NOW()
      WHERE id = NEW.task_id;
    END IF;
  
  -- Si c'est une mise à jour
  ELSIF TG_OP = 'UPDATE' THEN
    -- Si la transaction est associée à un budget ET PAS à une phase ou une tâche,
    -- ajuster le montant du budget (le project_id peut être non-null)
    IF NEW.budget_id IS NOT NULL AND NEW.phase_id IS NULL AND NEW.task_id IS NULL THEN
      UPDATE budgets
      SET 
        current_amount = current_amount - OLD.amount + NEW.amount,
        updated_at = NOW()
      WHERE id = NEW.budget_id;
    END IF;
    
    -- Gérer les modifications de budget consommé pour les projets, phases et tâches
    IF NEW.project_id IS NOT NULL OR OLD.project_id IS NOT NULL THEN
      -- Si l'ancien enregistrement avait un projet et que c'était une dépense
      IF OLD.project_id IS NOT NULL AND OLD.amount < 0 AND 
         (NEW.project_id IS NULL OR NEW.project_id <> OLD.project_id OR NEW.amount <> OLD.amount) THEN
        -- Réduire le budget consommé de l'ancien projet
        PERFORM public.update_project_budget_consumption(
          p_project_id := OLD.project_id,
          p_amount := -ABS(OLD.amount)
        );
      END IF;
      
      -- Si le nouvel enregistrement a un projet et que c'est une dépense
      IF NEW.project_id IS NOT NULL AND NEW.amount < 0 AND 
         (OLD.project_id IS NULL OR NEW.project_id <> OLD.project_id OR NEW.amount <> OLD.amount) THEN
        -- Augmenter le budget consommé du nouveau projet
        PERFORM public.update_project_budget_consumption(
          p_project_id := NEW.project_id,
          p_amount := ABS(NEW.amount)
        );
      END IF;
    END IF;
  
  -- Si c'est une suppression
  ELSIF TG_OP = 'DELETE' THEN
    -- Si la transaction est associée à un budget ET PAS à une phase ou une tâche,
    -- ajuster le montant du budget (le project_id peut être non-null)
    IF OLD.budget_id IS NOT NULL AND OLD.phase_id IS NULL AND OLD.task_id IS NULL THEN
      UPDATE budgets
      SET 
        current_amount = current_amount - OLD.amount,
        updated_at = NOW()
      WHERE id = OLD.budget_id;
    END IF;
    
    -- Si la transaction supprimée était associée à un projet et que c'était une dépense,
    -- réduire le budget consommé du projet
    IF OLD.project_id IS NOT NULL AND OLD.amount < 0 THEN
      PERFORM public.update_project_budget_consumption(
        p_project_id := OLD.project_id,
        p_amount := -ABS(OLD.amount)
      );
    END IF;
    
    -- Si la transaction supprimée était associée à une phase et que c'était une dépense,
    -- réduire le budget consommé de la phase
    IF OLD.phase_id IS NOT NULL AND OLD.amount < 0 THEN
      PERFORM public.update_phase_budget_consumption(
        p_phase_id := OLD.phase_id,
        p_amount := -ABS(OLD.amount)
      );
    END IF;
  END IF;
  
  -- Pour les opérations INSERT et UPDATE, retourner NEW, pour DELETE retourner OLD
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;


ALTER FUNCTION "public"."process_budget_transaction"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalculate_phase_budget_consumption"("p_phase_id" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_total_consumed double precision := 0;
BEGIN
  -- Calculer le total consommé par les tâches
  SELECT COALESCE(SUM(COALESCE(budget_consumed, 0)), 0)
  INTO v_total_consumed
  FROM tasks
  WHERE phase_id = p_phase_id;
  
  -- Mettre à jour le budget consommé de la phase
  UPDATE phases
  SET 
    budget_consumed = v_total_consumed,
    updated_at = NOW()
  WHERE id = p_phase_id;
END;
$$;


ALTER FUNCTION "public"."recalculate_phase_budget_consumption"("p_phase_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalculate_phase_budget_consumption"("p_phase_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  total_consumed numeric;
BEGIN
  -- Calculer le budget consommé total à partir des tâches
  SELECT COALESCE(SUM(budget_consumed), 0)
  INTO total_consumed
  FROM tasks
  WHERE phase_id = p_phase_id;
  
  -- Mettre à jour le budget consommé de la phase
  UPDATE phases
  SET 
    budget_consumed = total_consumed,
    updated_at = NOW()
  WHERE id = p_phase_id;
END;
$$;


ALTER FUNCTION "public"."recalculate_phase_budget_consumption"("p_phase_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalculate_project_budget_consumption"("p_project_id" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_tasks_consumed double precision := 0;
  v_phases_tasks_consumed double precision := 0;
BEGIN
  -- Calculer le total consommé par les tâches directement liées au projet (sans phase)
  SELECT COALESCE(SUM(COALESCE(budget_consumed, 0)), 0)
  INTO v_tasks_consumed
  FROM tasks
  WHERE project_id = p_project_id AND phase_id IS NULL;
  
  -- Calculer le total consommé par les tâches des phases du projet
  SELECT COALESCE(SUM(COALESCE(budget_consumed, 0)), 0)
  INTO v_phases_tasks_consumed
  FROM tasks
  WHERE project_id = p_project_id AND phase_id IS NOT NULL;
  
  -- Mettre à jour le budget consommé du projet
  UPDATE projects
  SET 
    budget_consumed = v_tasks_consumed + v_phases_tasks_consumed,
    updated_at = NOW()
  WHERE id = p_project_id;
END;
$$;


ALTER FUNCTION "public"."recalculate_project_budget_consumption"("p_project_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalculate_project_budget_consumption"("p_project_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  total_consumed numeric;
BEGIN
  -- Calculer le budget consommé total à partir des phases
  SELECT COALESCE(SUM(budget_consumed), 0)
  INTO total_consumed
  FROM phases
  WHERE project_id = p_project_id;
  
  -- Mettre à jour le budget consommé du projet
  UPDATE projects
  SET 
    budget_consumed = total_consumed,
    updated_at = NOW()
  WHERE id = p_project_id;
END;
$$;


ALTER FUNCTION "public"."recalculate_project_budget_consumption"("p_project_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_budget_team_id"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.team_id IS NULL THEN
    -- Si team_id n'est pas défini, on prend la première équipe de l'utilisateur
    NEW.team_id := (
      SELECT team_id 
      FROM team_members 
      WHERE user_id = NEW.created_by AND status = 'active'
      LIMIT 1
    );
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_budget_team_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_team_member_to_user_role"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_role_id uuid;
BEGIN
    -- Trouver l'ID du rôle team_member
    SELECT id INTO v_role_id FROM public.roles WHERE name = 'team_member';
    
    IF v_role_id IS NULL THEN
        RAISE EXCEPTION 'Rôle team_member introuvable';
    END IF;
    
    -- Vérifier si l'entrée existe déjà
    IF NOT EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = NEW.user_id
        AND role_id = v_role_id
        AND team_id = NEW.team_id
        AND project_id IS NULL
    ) THEN
        -- Insérer seulement si ça n'existe pas déjà
        INSERT INTO public.user_roles (id, user_id, role_id, team_id, project_id, created_by)
        VALUES (gen_random_uuid(), NEW.user_id, v_role_id, NEW.team_id, NULL, NEW.invited_by);
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_team_member_to_user_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."task_budget_trigger_function"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Si le budget consommé a changé
  IF OLD.budget_consumed IS DISTINCT FROM NEW.budget_consumed THEN
    -- Si la tâche appartient à une phase, mettre à jour le budget de la phase
    IF NEW.phase_id IS NOT NULL THEN
      PERFORM update_phase_budget_consumption(NEW.phase_id, NEW.budget_consumed - COALESCE(OLD.budget_consumed, 0));
    END IF;
    
    -- Mettre à jour le budget du projet
    PERFORM update_project_budget_consumption(NEW.project_id, NEW.budget_consumed - COALESCE(OLD.budget_consumed, 0));
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."task_budget_trigger_function"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_budget_current_amount"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Mise à jour du montant actuel du budget
        IF NEW.budget_id IS NOT NULL THEN
            UPDATE public.budgets
            SET current_amount = current_amount + NEW.amount
            WHERE id = NEW.budget_id;
        END IF;

        -- Mise à jour du budget consommé du projet si c'est une dépense
        IF NEW.project_id IS NOT NULL AND NEW.amount < 0 THEN
            UPDATE public.projects
            SET budget_consumed = budget_consumed - NEW.amount
            WHERE id = NEW.project_id;
        END IF;

        -- Mise à jour du budget consommé de la phase si c'est une dépense
        IF NEW.phase_id IS NOT NULL AND NEW.amount < 0 THEN
            UPDATE public.phases
            SET budget_consumed = budget_consumed - NEW.amount
            WHERE id = NEW.phase_id;
        END IF;

        -- Mise à jour du budget consommé de la tâche si c'est une dépense
        IF NEW.task_id IS NOT NULL AND NEW.amount < 0 THEN
            UPDATE public.tasks
            SET budget_consumed = budget_consumed - NEW.amount
            WHERE id = NEW.task_id;
        END IF;

    ELSIF TG_OP = 'UPDATE' THEN
        -- Mettre à jour le montant du budget si le budget_id ou le montant a changé
        IF (OLD.budget_id IS DISTINCT FROM NEW.budget_id) OR (OLD.amount IS DISTINCT FROM NEW.amount) THEN
            -- Annuler l'effet de l'ancienne transaction sur l'ancien budget
            IF OLD.budget_id IS NOT NULL THEN
                UPDATE public.budgets
                SET current_amount = current_amount - OLD.amount
                WHERE id = OLD.budget_id;
            END IF;

            -- Appliquer l'effet de la nouvelle transaction sur le nouveau budget
            IF NEW.budget_id IS NOT NULL THEN
                UPDATE public.budgets
                SET current_amount = current_amount + NEW.amount
                WHERE id = NEW.budget_id;
            END IF;
        END IF;

        -- Mise à jour du budget consommé du projet
        IF (OLD.project_id IS DISTINCT FROM NEW.project_id) OR (OLD.amount IS DISTINCT FROM NEW.amount) THEN
            -- Annuler l'effet sur l'ancien projet
            IF OLD.project_id IS NOT NULL AND OLD.amount < 0 THEN
                UPDATE public.projects
                SET budget_consumed = budget_consumed + OLD.amount
                WHERE id = OLD.project_id;
            END IF;

            -- Appliquer l'effet sur le nouveau projet
            IF NEW.project_id IS NOT NULL AND NEW.amount < 0 THEN
                UPDATE public.projects
                SET budget_consumed = budget_consumed - NEW.amount
                WHERE id = NEW.project_id;
            END IF;
        END IF;

        -- Mise à jour du budget consommé de la phase
        IF (OLD.phase_id IS DISTINCT FROM NEW.phase_id) OR (OLD.amount IS DISTINCT FROM NEW.amount) THEN
            -- Annuler l'effet sur l'ancienne phase
            IF OLD.phase_id IS NOT NULL AND OLD.amount < 0 THEN
                UPDATE public.phases
                SET budget_consumed = budget_consumed + OLD.amount
                WHERE id = OLD.phase_id;
            END IF;

            -- Appliquer l'effet sur la nouvelle phase
            IF NEW.phase_id IS NOT NULL AND NEW.amount < 0 THEN
                UPDATE public.phases
                SET budget_consumed = budget_consumed - NEW.amount
                WHERE id = NEW.phase_id;
            END IF;
        END IF;

        -- Mise à jour du budget consommé de la tâche
        IF (OLD.task_id IS DISTINCT FROM NEW.task_id) OR (OLD.amount IS DISTINCT FROM NEW.amount) THEN
            -- Annuler l'effet sur l'ancienne tâche
            IF OLD.task_id IS NOT NULL AND OLD.amount < 0 THEN
                UPDATE public.tasks
                SET budget_consumed = budget_consumed + OLD.amount
                WHERE id = OLD.task_id;
            END IF;

            -- Appliquer l'effet sur la nouvelle tâche
            IF NEW.task_id IS NOT NULL AND NEW.amount < 0 THEN
                UPDATE public.tasks
                SET budget_consumed = budget_consumed - NEW.amount
                WHERE id = NEW.task_id;
            END IF;
        END IF;

    ELSIF TG_OP = 'DELETE' THEN
        -- Annuler l'effet de la transaction supprimée sur le budget
        IF OLD.budget_id IS NOT NULL THEN
            UPDATE public.budgets
            SET current_amount = current_amount - OLD.amount
            WHERE id = OLD.budget_id;
        END IF;

        -- Annuler l'effet sur le projet
        IF OLD.project_id IS NOT NULL AND OLD.amount < 0 THEN
            UPDATE public.projects
            SET budget_consumed = budget_consumed + OLD.amount
            WHERE id = OLD.project_id;
        END IF;

        -- Annuler l'effet sur la phase
        IF OLD.phase_id IS NOT NULL AND OLD.amount < 0 THEN
            UPDATE public.phases
            SET budget_consumed = budget_consumed + OLD.amount
            WHERE id = OLD.phase_id;
        END IF;

        -- Annuler l'effet sur la tâche
        IF OLD.task_id IS NOT NULL AND OLD.amount < 0 THEN
            UPDATE public.tasks
            SET budget_consumed = budget_consumed + OLD.amount
            WHERE id = OLD.task_id;
        END IF;
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."update_budget_current_amount"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_phase_budget_consumption"("p_phase_id" "text", "p_amount" double precision) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Mettre à jour le budget consommé de la phase
  UPDATE phases
  SET 
    budget_consumed = COALESCE(budget_consumed, 0) + p_amount,
    updated_at = NOW()
  WHERE id = p_phase_id;
END;
$$;


ALTER FUNCTION "public"."update_phase_budget_consumption"("p_phase_id" "text", "p_amount" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_phase_budget_consumption"("p_phase_id" "uuid", "p_amount" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Mettre à jour le budget consommé de la phase - SANS conversion ::text
  UPDATE phases
  SET 
    budget_consumed = COALESCE(budget_consumed, 0) + p_amount,
    updated_at = NOW()
  WHERE id = p_phase_id;
END;
$$;


ALTER FUNCTION "public"."update_phase_budget_consumption"("p_phase_id" "uuid", "p_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_project_budget_allocation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Mise à jour du budget alloué du projet
        UPDATE public.projects
        SET budget_allocated = budget_allocated + NEW.amount
        WHERE id = NEW.project_id;

    ELSIF TG_OP = 'UPDATE' THEN
        -- Si le projet ou le montant a changé
        IF (OLD.project_id IS DISTINCT FROM NEW.project_id) OR (OLD.amount IS DISTINCT FROM NEW.amount) THEN
            -- Annuler l'allocation sur l'ancien projet
            UPDATE public.projects
            SET budget_allocated = budget_allocated - OLD.amount
            WHERE id = OLD.project_id;

            -- Appliquer l'allocation sur le nouveau projet
            UPDATE public.projects
            SET budget_allocated = budget_allocated + NEW.amount
            WHERE id = NEW.project_id;
        END IF;

    ELSIF TG_OP = 'DELETE' THEN
        -- Annuler l'allocation sur le projet
        UPDATE public.projects
        SET budget_allocated = budget_allocated - OLD.amount
        WHERE id = OLD.project_id;
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."update_project_budget_allocation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_project_budget_consumption"("p_project_id" "text", "p_amount" double precision) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Mettre à jour le budget consommé du projet
  UPDATE projects
  SET 
    budget_consumed = COALESCE(budget_consumed, 0) + p_amount,
    updated_at = NOW()
  WHERE id = p_project_id;
END;
$$;


ALTER FUNCTION "public"."update_project_budget_consumption"("p_project_id" "text", "p_amount" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_project_budget_consumption"("p_project_id" "uuid", "p_amount" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Mettre à jour le budget consommé du projet - SANS conversion ::text
  UPDATE projects
  SET 
    budget_consumed = COALESCE(budget_consumed, 0) + p_amount,
    updated_at = NOW()
  WHERE id = p_project_id;
END;
$$;


ALTER FUNCTION "public"."update_project_budget_consumption"("p_project_id" "uuid", "p_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_has_permission"("p_user_id" "uuid", "p_permission_name" "text", "p_team_id" "uuid" DEFAULT NULL::"uuid", "p_project_id" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    has_perm boolean := false;
    has_team_perm boolean := false;
    has_project_perm boolean := false;
    has_direct_project_perm boolean := false;
    v_project_ids uuid[];
    user_roles text[];
    v_debug_info jsonb;
BEGIN
    -- Récupérer les noms des rôles de l'utilisateur pour le débogage
    SELECT array_agg(r.name) INTO user_roles
    FROM user_roles ur
    JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = p_user_id;
    
    -- Les admins système ont automatiquement toutes les permissions
    IF user_roles IS NOT NULL AND 'system_admin' = ANY(user_roles) THEN
        RETURN true;
    END IF;

    -- Cas 1 & 2: Vérification directe sur l'équipe ou globale
    SELECT EXISTS (
        SELECT 1
        FROM user_roles ur
        JOIN role_permissions rp ON ur.role_id = rp.role_id
        JOIN permissions p ON rp.permission_id = p.id
        WHERE ur.user_id = p_user_id
          AND p.name = p_permission_name
          AND (
              -- Cas 1: Rôle global (sans contexte)
              (ur.team_id IS NULL AND ur.project_id IS NULL)
              OR
              -- Cas 2: Rôle dans le contexte d'équipe spécifié
              (p_team_id IS NOT NULL AND ur.team_id = p_team_id)
          )
    ) INTO has_team_perm;
    
    -- Cas 5 (NOUVEAU): Vérification directe sur un projet spécifique
    -- Ce cas gère les rôles assignés directement à un projet sans passer par une équipe
    IF p_project_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
            FROM user_roles ur
            JOIN role_permissions rp ON ur.role_id = rp.role_id
            JOIN permissions p ON rp.permission_id = p.id
            WHERE ur.user_id = p_user_id
              AND p.name = p_permission_name
              AND ur.project_id = p_project_id
        ) INTO has_direct_project_perm;
        
        -- Journaliser cette vérification
        INSERT INTO rbac_logs (
            user_id, permission_name, team_id, project_id, result, log_timestamp, debug_info
        ) VALUES (
            p_user_id, 
            'CHECK_DIRECT_PROJECT_PERMISSION', 
            NULL, 
            p_project_id, 
            has_direct_project_perm, 
            NOW(),
            jsonb_build_object(
                'permission', p_permission_name,
                'project_id', p_project_id,
                'result', has_direct_project_perm
            )
        );
    END IF;
    
    -- Cas 3 & 4: Vérification via projets liés à l'équipe spécifiée
    IF NOT has_team_perm AND p_team_id IS NOT NULL THEN
        -- Récupérer les projets de l'équipe
        SELECT array_agg(tp.project_id) INTO v_project_ids
        FROM team_projects tp
        WHERE tp.team_id = p_team_id;
        
        -- Récupérer les projets sur lesquels l'utilisateur a un rôle
        WITH user_project_roles AS (
            SELECT ur.project_id, r.name as role_name
            FROM user_roles ur
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = p_user_id AND ur.project_id IS NOT NULL
        )
        SELECT jsonb_build_object(
            'team_id', p_team_id,
            'team_projects', v_project_ids,
            'user_project_roles', (SELECT jsonb_agg(row_to_json(upr)) FROM user_project_roles upr)
        ) INTO v_debug_info;
        
        -- Insérer des informations de débogage
        INSERT INTO rbac_logs (
            user_id, permission_name, team_id, project_id, result, log_timestamp, debug_info
        ) VALUES (
            p_user_id, 'DEBUG_PROJ_TEAM_RELATION', p_team_id, NULL, false, NOW(), v_debug_info
        );
        
        -- Vérification spécifique pour le cas 4: projet lié à l'équipe
        WITH team_related_projects AS (
            -- Obtenir tous les projets liés à cette équipe
            SELECT project_id FROM team_projects WHERE team_id = p_team_id
        ),
        user_permissions AS (
            -- Vérifier si l'utilisateur a la permission via un de ces projets
            SELECT COUNT(*) > 0 AS has_permission
            FROM user_roles ur
            JOIN role_permissions rp ON ur.role_id = rp.role_id
            JOIN permissions p ON rp.permission_id = p.id
            JOIN team_related_projects trp ON trp.project_id = ur.project_id
            WHERE ur.user_id = p_user_id
              AND p.name = p_permission_name
        )
        SELECT has_permission INTO has_project_perm FROM user_permissions;
        
        -- Journalisation du résultat de la vérification via projet
        INSERT INTO rbac_logs (
            user_id, permission_name, team_id, project_id, result, log_timestamp, debug_info
        ) VALUES (
            p_user_id, 
            'CHECK_PERMISSION_VIA_PROJECT', 
            p_team_id, 
            NULL, 
            has_project_perm, 
            NOW(),
            jsonb_build_object(
                'permission', p_permission_name,
                'team_projects', v_project_ids,
                'result', has_project_perm
            )
        );
    END IF;
    
    -- Combiner les résultats (ajout de has_direct_project_perm)
    has_perm := has_team_perm OR has_project_perm OR has_direct_project_perm;

    -- Journaliser le résultat final
    INSERT INTO rbac_logs (
        user_id, 
        permission_name, 
        team_id, 
        project_id, 
        result,
        log_timestamp,
        debug_info
    ) VALUES (
        p_user_id,
        p_permission_name,
        p_team_id,
        p_project_id,
        has_perm,
        NOW(),
        jsonb_build_object(
            'has_team_perm', has_team_perm,
            'has_project_perm', has_project_perm,
            'has_direct_project_perm', has_direct_project_perm,
            'team_id', p_team_id,
            'project_id', p_project_id,
            'user_roles', user_roles
        )
    );

    RETURN has_perm;
END;
$$;


ALTER FUNCTION "public"."user_has_permission"("p_user_id" "uuid", "p_permission_name" "text", "p_team_id" "uuid", "p_project_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."user_has_permission"("p_user_id" "uuid", "p_permission_name" "text", "p_team_id" "uuid", "p_project_id" "uuid") IS 'Fonction améliorée qui vérifie si un utilisateur a une permission, avec prise en charge plus cohérente des contextes.';


SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."attachments" (
    "id" "uuid" NOT NULL,
    "task_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "url" "text" NOT NULL,
    "path" "text" NOT NULL,
    "uploaded_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."attachments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."budget_allocations" (
    "id" "uuid" NOT NULL,
    "budget_id" "uuid" NOT NULL,
    "project_id" "uuid" NOT NULL,
    "amount" numeric(15,2) NOT NULL,
    "allocation_date" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone,
    "created_by" "uuid" NOT NULL,
    "description" "text"
);


ALTER TABLE "public"."budget_allocations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."budget_allocations"."description" IS 'description';



CREATE TABLE IF NOT EXISTS "public"."budget_transactions" (
    "id" "uuid" NOT NULL,
    "budget_id" "uuid",
    "project_id" "uuid",
    "phase_id" "uuid",
    "task_id" "uuid",
    "amount" numeric(15,2) NOT NULL,
    "description" "text" NOT NULL,
    "transaction_date" timestamp with time zone NOT NULL,
    "transaction_type" "text" NOT NULL,
    "category" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone,
    "created_by" "uuid" NOT NULL,
    "subcategory" "text",
    "notes" "text",
    "category_id" "uuid",
    "subcategory_id" "uuid",
    CONSTRAINT "budget_transactions_transaction_type_check" CHECK (("transaction_type" = ANY (ARRAY['income'::"text", 'expense'::"text"])))
);


ALTER TABLE "public"."budget_transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."budgets" (
    "id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "initial_amount" numeric(15,2) DEFAULT 0 NOT NULL,
    "current_amount" numeric(15,2) DEFAULT 0 NOT NULL,
    "start_date" timestamp with time zone NOT NULL,
    "end_date" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone,
    "created_by" "uuid" NOT NULL,
    "project_id" "uuid",
    "team_id" "uuid"
);


ALTER TABLE "public"."budgets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."invitations" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "email" "text" NOT NULL,
    "team_id" "uuid" NOT NULL,
    "invited_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone DEFAULT ("now"() + '7 days'::interval) NOT NULL,
    "token" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "metadata" "jsonb",
    CONSTRAINT "invitations_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'accepted'::"text", 'rejected'::"text", 'expired'::"text"])))
);


ALTER TABLE "public"."invitations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."invitations"."metadata" IS 'Stocke les métadonnées RBAC comme les IDs et noms de rôles';



CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "title" "text" NOT NULL,
    "message" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_read" boolean DEFAULT false NOT NULL,
    "type" "text" NOT NULL,
    "related_id" "uuid",
    "user_id" "uuid",
    CONSTRAINT "notifications_type_check" CHECK (("type" = ANY (ARRAY['projectCreated'::"text", 'projectStatusChanged'::"text", 'projectBudgetAlert'::"text", 'phaseCreated'::"text", 'phaseStatusChanged'::"text", 'taskAssigned'::"text", 'taskDueSoon'::"text", 'taskOverdue'::"text", 'taskStatusChanged'::"text", 'projectInvitation'::"text", 'newUser'::"text"])))
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."permissions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "resource_type" "text" NOT NULL,
    "action" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."permissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."phases" (
    "id" "uuid" NOT NULL,
    "project_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone,
    "created_by" "uuid" NOT NULL,
    "order_index" integer NOT NULL,
    "status" "text" NOT NULL,
    "budget_allocated" numeric(15,2) DEFAULT 0,
    "budget_consumed" numeric(15,2) DEFAULT 0,
    CONSTRAINT "phases_status_check" CHECK (("status" = ANY (ARRAY['not_started'::"text", 'in_progress'::"text", 'completed'::"text", 'on_hold'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."phases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "display_name" "text",
    "avatar_url" "text",
    "bio" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "phone_number" "text"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projects" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone,
    "created_by" "uuid",
    "members" "text"[] DEFAULT '{}'::"text"[],
    "status" "text" NOT NULL,
    "budget_allocated" numeric(15,2) DEFAULT 0,
    "budget_consumed" numeric(15,2) DEFAULT 0,
    "planned_budget" numeric DEFAULT 0
);


ALTER TABLE "public"."projects" OWNER TO "postgres";


COMMENT ON COLUMN "public"."projects"."planned_budget" IS 'Budget prévisionnel du projet';



CREATE TABLE IF NOT EXISTS "public"."rbac_logs" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "permission_name" "text" NOT NULL,
    "team_id" "uuid",
    "project_id" "uuid",
    "result" boolean NOT NULL,
    "log_timestamp" timestamp with time zone DEFAULT "now"() NOT NULL,
    "debug_info" "jsonb"
);


ALTER TABLE "public"."rbac_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."role_permissions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "role_id" "uuid" NOT NULL,
    "permission_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."role_permissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."roles" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "task_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "comment" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone
);


ALTER TABLE "public"."task_comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "task_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "field_name" "text" NOT NULL,
    "old_value" "text",
    "new_value" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."task_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tasks" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "project_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone,
    "due_date" timestamp with time zone,
    "assigned_to" "text",
    "created_by" "uuid",
    "status" "text" NOT NULL,
    "priority" integer NOT NULL,
    "phase_id" "uuid",
    "team_id" "uuid",
    "budget_allocated" numeric(15,2) DEFAULT 0,
    "budget_consumed" numeric(15,2) DEFAULT 0
);


ALTER TABLE "public"."tasks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."team_members" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "team_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "invited_by" "uuid",
    "status" "text" DEFAULT 'invited'::"text" NOT NULL,
    CONSTRAINT "team_members_role_check" CHECK (("role" = ANY (ARRAY['admin'::"text", 'member'::"text", 'guest'::"text"]))),
    CONSTRAINT "team_members_status_check" CHECK (("status" = ANY (ARRAY['invited'::"text", 'active'::"text", 'inactive'::"text"])))
);


ALTER TABLE "public"."team_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."team_projects" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "team_id" "uuid" NOT NULL,
    "project_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."team_projects" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."team_tasks" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "team_id" "uuid" NOT NULL,
    "task_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."team_tasks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."teams" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid" NOT NULL,
    "updated_at" timestamp with time zone
);


ALTER TABLE "public"."teams" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transaction_categories" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "transaction_type" "text" NOT NULL,
    "description" "text",
    "icon" "text",
    "color" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."transaction_categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transaction_subcategories" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "category_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."transaction_subcategories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role_id" "uuid" NOT NULL,
    "team_id" "uuid",
    "project_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid"
);


ALTER TABLE "public"."user_roles" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."user_permissions_view" AS
 SELECT "u"."id" AS "user_id",
    "u"."email",
    "p"."display_name" AS "user_name",
    "r"."name" AS "role_name",
    "r"."description" AS "role_description",
    "perm"."name" AS "permission_name",
    "perm"."resource_type",
    "perm"."action",
    "t"."name" AS "team_name",
    "t"."id" AS "team_id",
    "pr"."name" AS "project_name",
    "pr"."id" AS "project_id"
   FROM ((((((("auth"."users" "u"
     JOIN "public"."profiles" "p" ON (("u"."id" = "p"."id")))
     JOIN "public"."user_roles" "ur" ON (("u"."id" = "ur"."user_id")))
     JOIN "public"."roles" "r" ON (("ur"."role_id" = "r"."id")))
     JOIN "public"."role_permissions" "rp" ON (("r"."id" = "rp"."role_id")))
     JOIN "public"."permissions" "perm" ON (("rp"."permission_id" = "perm"."id")))
     LEFT JOIN "public"."teams" "t" ON (("ur"."team_id" = "t"."id")))
     LEFT JOIN "public"."projects" "pr" ON (("ur"."project_id" = "pr"."id")));


ALTER TABLE "public"."user_permissions_view" OWNER TO "postgres";


ALTER TABLE ONLY "public"."attachments"
    ADD CONSTRAINT "attachments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."budget_allocations"
    ADD CONSTRAINT "budget_allocations_budget_id_project_id_key" UNIQUE ("budget_id", "project_id");



ALTER TABLE ONLY "public"."budget_allocations"
    ADD CONSTRAINT "budget_allocations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."budget_transactions"
    ADD CONSTRAINT "budget_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."budgets"
    ADD CONSTRAINT "budgets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invitations"
    ADD CONSTRAINT "invitations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invitations"
    ADD CONSTRAINT "invitations_token_key" UNIQUE ("token");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."permissions"
    ADD CONSTRAINT "permissions_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."permissions"
    ADD CONSTRAINT "permissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."phases"
    ADD CONSTRAINT "phases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projects"
    ADD CONSTRAINT "projects_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."rbac_logs"
    ADD CONSTRAINT "rbac_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."role_permissions"
    ADD CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."role_permissions"
    ADD CONSTRAINT "role_permissions_role_permission_key" UNIQUE ("role_id", "permission_id");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_comments"
    ADD CONSTRAINT "task_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_history"
    ADD CONSTRAINT "task_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_team_id_user_id_key" UNIQUE ("team_id", "user_id");



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_user_team_key" UNIQUE ("user_id", "team_id");



ALTER TABLE ONLY "public"."team_projects"
    ADD CONSTRAINT "team_projects_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_projects"
    ADD CONSTRAINT "team_projects_team_id_project_id_key" UNIQUE ("team_id", "project_id");



ALTER TABLE ONLY "public"."team_tasks"
    ADD CONSTRAINT "team_tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_tasks"
    ADD CONSTRAINT "team_tasks_team_id_task_id_key" UNIQUE ("team_id", "task_id");



ALTER TABLE ONLY "public"."teams"
    ADD CONSTRAINT "teams_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transaction_categories"
    ADD CONSTRAINT "transaction_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transaction_subcategories"
    ADD CONSTRAINT "transaction_subcategories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_unique_context" UNIQUE ("user_id", "role_id", "team_id", "project_id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_team_role_key" UNIQUE ("user_id", "team_id", "role_id");



CREATE INDEX "attachments_task_id_idx" ON "public"."attachments" USING "btree" ("task_id");



CREATE INDEX "budget_allocations_budget_id_idx" ON "public"."budget_allocations" USING "btree" ("budget_id");



CREATE INDEX "budget_allocations_project_id_idx" ON "public"."budget_allocations" USING "btree" ("project_id");



CREATE INDEX "budget_transactions_budget_id_idx" ON "public"."budget_transactions" USING "btree" ("budget_id");



CREATE INDEX "budget_transactions_category_idx" ON "public"."budget_transactions" USING "btree" ("transaction_type");



CREATE INDEX "budget_transactions_date_idx" ON "public"."budget_transactions" USING "btree" ("transaction_date");



CREATE INDEX "budget_transactions_project_id_idx" ON "public"."budget_transactions" USING "btree" ("project_id");



CREATE INDEX "idx_budget_transactions_category_id" ON "public"."budget_transactions" USING "btree" ("category_id");



CREATE INDEX "idx_budget_transactions_subcategory_id" ON "public"."budget_transactions" USING "btree" ("subcategory_id");



CREATE INDEX "idx_rbac_logs_permission" ON "public"."rbac_logs" USING "btree" ("permission_name");



CREATE INDEX "idx_rbac_logs_timestamp" ON "public"."rbac_logs" USING "btree" ("log_timestamp");



CREATE INDEX "idx_rbac_logs_user_id" ON "public"."rbac_logs" USING "btree" ("user_id");



CREATE INDEX "idx_task_comments_task_id" ON "public"."task_comments" USING "btree" ("task_id");



CREATE INDEX "idx_task_comments_user_id" ON "public"."task_comments" USING "btree" ("user_id");



CREATE INDEX "idx_transaction_categories_type" ON "public"."transaction_categories" USING "btree" ("transaction_type");



CREATE INDEX "idx_transaction_subcategories_category" ON "public"."transaction_subcategories" USING "btree" ("category_id");



CREATE INDEX "notifications_created_at_idx" ON "public"."notifications" USING "btree" ("created_at" DESC);



CREATE INDEX "notifications_is_read_idx" ON "public"."notifications" USING "btree" ("is_read");



CREATE INDEX "notifications_related_id_idx" ON "public"."notifications" USING "btree" ("related_id");



CREATE INDEX "notifications_user_id_idx" ON "public"."notifications" USING "btree" ("user_id");



CREATE INDEX "phases_project_id_idx" ON "public"."phases" USING "btree" ("project_id");



CREATE INDEX "profiles_email_idx" ON "public"."profiles" USING "btree" ("email");



CREATE INDEX "task_history_task_id_idx" ON "public"."task_history" USING "btree" ("task_id");



CREATE INDEX "tasks_phase_id_idx" ON "public"."tasks" USING "btree" ("phase_id");



CREATE OR REPLACE TRIGGER "after_budget_allocation_changes" AFTER INSERT OR DELETE OR UPDATE ON "public"."budget_allocations" FOR EACH ROW EXECUTE FUNCTION "public"."update_project_budget_allocation"();



CREATE OR REPLACE TRIGGER "after_budget_transaction_changes" AFTER INSERT OR DELETE OR UPDATE ON "public"."budget_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."update_budget_current_amount"();



CREATE OR REPLACE TRIGGER "budget_transaction_trigger" AFTER INSERT OR DELETE OR UPDATE ON "public"."budget_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."process_budget_transaction"();



CREATE OR REPLACE TRIGGER "set_budget_team_id_trigger" BEFORE INSERT ON "public"."budgets" FOR EACH ROW EXECUTE FUNCTION "public"."set_budget_team_id"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."task_comments" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "task_budget_trigger" AFTER UPDATE ON "public"."tasks" FOR EACH ROW WHEN (("old"."budget_consumed" IS DISTINCT FROM "new"."budget_consumed")) EXECUTE FUNCTION "public"."task_budget_trigger_function"();



CREATE OR REPLACE TRIGGER "task_validation_trigger" BEFORE INSERT OR UPDATE ON "public"."tasks" FOR EACH ROW EXECUTE FUNCTION "public"."handle_task_changes"();



CREATE OR REPLACE TRIGGER "team_member_rbac_sync" AFTER INSERT OR UPDATE ON "public"."team_members" FOR EACH ROW WHEN (("new"."status" = 'active'::"text")) EXECUTE FUNCTION "public"."sync_team_member_to_user_role"();



CREATE OR REPLACE TRIGGER "update_transaction_categories_timestamp" BEFORE UPDATE ON "public"."transaction_categories" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at"();



CREATE OR REPLACE TRIGGER "update_transaction_subcategories_timestamp" BEFORE UPDATE ON "public"."transaction_subcategories" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at"();



ALTER TABLE ONLY "public"."attachments"
    ADD CONSTRAINT "attachments_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attachments"
    ADD CONSTRAINT "attachments_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."budget_allocations"
    ADD CONSTRAINT "budget_allocations_budget_id_fkey" FOREIGN KEY ("budget_id") REFERENCES "public"."budgets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."budget_allocations"
    ADD CONSTRAINT "budget_allocations_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."budget_allocations"
    ADD CONSTRAINT "budget_allocations_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."budget_transactions"
    ADD CONSTRAINT "budget_transactions_budget_id_fkey" FOREIGN KEY ("budget_id") REFERENCES "public"."budgets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."budget_transactions"
    ADD CONSTRAINT "budget_transactions_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."transaction_categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."budget_transactions"
    ADD CONSTRAINT "budget_transactions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."budget_transactions"
    ADD CONSTRAINT "budget_transactions_phase_id_fkey" FOREIGN KEY ("phase_id") REFERENCES "public"."phases"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."budget_transactions"
    ADD CONSTRAINT "budget_transactions_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."budget_transactions"
    ADD CONSTRAINT "budget_transactions_subcategory_id_fkey" FOREIGN KEY ("subcategory_id") REFERENCES "public"."transaction_subcategories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."budget_transactions"
    ADD CONSTRAINT "budget_transactions_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."budgets"
    ADD CONSTRAINT "budgets_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."budgets"
    ADD CONSTRAINT "budgets_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id");



ALTER TABLE ONLY "public"."budgets"
    ADD CONSTRAINT "budgets_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id");



ALTER TABLE ONLY "public"."invitations"
    ADD CONSTRAINT "invitations_invited_by_fkey" FOREIGN KEY ("invited_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."invitations"
    ADD CONSTRAINT "invitations_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."phases"
    ADD CONSTRAINT "phases_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."phases"
    ADD CONSTRAINT "phases_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projects"
    ADD CONSTRAINT "projects_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."rbac_logs"
    ADD CONSTRAINT "rbac_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."role_permissions"
    ADD CONSTRAINT "role_permissions_permission_id_fkey" FOREIGN KEY ("permission_id") REFERENCES "public"."permissions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."role_permissions"
    ADD CONSTRAINT "role_permissions_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_comments"
    ADD CONSTRAINT "task_comments_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_comments"
    ADD CONSTRAINT "task_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_history"
    ADD CONSTRAINT "task_history_task_id_fk" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_history"
    ADD CONSTRAINT "task_history_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_history"
    ADD CONSTRAINT "task_history_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_phase_id_fkey" FOREIGN KEY ("phase_id") REFERENCES "public"."phases"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_invited_by_fkey" FOREIGN KEY ("invited_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_user_id_auth_users_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_user_id_profiles_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_projects"
    ADD CONSTRAINT "team_projects_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_projects"
    ADD CONSTRAINT "team_projects_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_tasks"
    ADD CONSTRAINT "team_tasks_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_tasks"
    ADD CONSTRAINT "team_tasks_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."teams"
    ADD CONSTRAINT "teams_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transaction_subcategories"
    ADD CONSTRAINT "transaction_subcategories_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."transaction_categories"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Admins can manage permissions" ON "public"."permissions" USING ("public"."user_has_permission"("auth"."uid"(), 'manage_users'::"text")) WITH CHECK ("public"."user_has_permission"("auth"."uid"(), 'manage_users'::"text"));



CREATE POLICY "Admins can manage role_permissions" ON "public"."role_permissions" USING ("public"."user_has_permission"("auth"."uid"(), 'manage_users'::"text")) WITH CHECK ("public"."user_has_permission"("auth"."uid"(), 'manage_users'::"text"));



CREATE POLICY "Admins can manage roles" ON "public"."roles" USING ("public"."user_has_permission"("auth"."uid"(), 'manage_users'::"text")) WITH CHECK ("public"."user_has_permission"("auth"."uid"(), 'manage_users'::"text"));



CREATE POLICY "Admins can manage user_roles" ON "public"."user_roles" USING ("public"."user_has_permission"("auth"."uid"(), 'manage_users'::"text")) WITH CHECK ("public"."user_has_permission"("auth"."uid"(), 'manage_users'::"text"));



CREATE POLICY "Allow authenticated insert" ON "public"."team_members" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Allow authenticated insert" ON "public"."user_roles" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Allow users to insert team members" ON "public"."team_members" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow users to select invitations by token" ON "public"."invitations" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow users to update invitations" ON "public"."invitations" FOR UPDATE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow users to update team members" ON "public"."team_members" FOR UPDATE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Les administrateurs peuvent supprimer des notifications" ON "public"."notifications" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Les membres d'équipe peuvent voir les budgets des projets de l" ON "public"."budgets" FOR SELECT USING (((("project_id" IS NULL) AND ("auth"."uid"() = "created_by")) OR (("project_id" IS NOT NULL) AND ("auth"."uid"() IN ( SELECT "tm"."user_id"
   FROM ("public"."team_members" "tm"
     JOIN "public"."team_projects" "tp" ON (("tm"."team_id" = "tp"."team_id")))
  WHERE (("tp"."project_id" = "budgets"."project_id") AND ("tm"."status" = 'active'::"text")))))));



CREATE POLICY "Les membres d'équipe peuvent voir toutes les transactions des " ON "public"."budget_transactions" FOR SELECT USING ((("auth"."uid"() IN ( SELECT "tm"."user_id"
   FROM ("public"."team_members" "tm"
     JOIN "public"."team_projects" "tp" ON (("tm"."team_id" = "tp"."team_id")))
  WHERE (("tp"."project_id" = "budget_transactions"."project_id") AND ("tm"."status" = 'active'::"text")))) OR ("auth"."uid"() = "created_by")));



CREATE POLICY "Les utilisateurs authentifiés peuvent créer des notifications" ON "public"."notifications" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Les utilisateurs peuvent mettre à jour leurs propres notificat" ON "public"."notifications" FOR UPDATE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Les utilisateurs peuvent voir leurs propres notifications" ON "public"."notifications" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Project admins can delete any comments" ON "public"."task_comments" FOR DELETE USING (((EXISTS ( SELECT 1
   FROM ("public"."tasks" "t"
     JOIN "public"."projects" "p" ON (("t"."project_id" = "p"."id")))
  WHERE (("t"."id" = "task_comments"."task_id") AND ("p"."created_by" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM (("public"."tasks" "t"
     JOIN "public"."team_projects" "tp" ON (("t"."project_id" = "tp"."project_id")))
     JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
  WHERE (("t"."id" = "task_comments"."task_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text"))))));



CREATE POLICY "Project managers can assign roles for their projects" ON "public"."user_roles" USING (("public"."user_has_permission"("auth"."uid"(), 'update_project'::"text", NULL::"uuid", "project_id") AND (( SELECT "roles"."id"
   FROM "public"."roles"
  WHERE ("roles"."name" = 'system_admin'::"text")) <> "role_id"))) WITH CHECK (("public"."user_has_permission"("auth"."uid"(), 'update_project'::"text", NULL::"uuid", "project_id") AND (( SELECT "roles"."id"
   FROM "public"."roles"
  WHERE ("roles"."name" = 'system_admin'::"text")) <> "role_id")));



CREATE POLICY "Seuls les créateurs et admins peuvent modifier les budgets" ON "public"."budgets" FOR UPDATE USING ((("auth"."uid"() = "created_by") OR (("project_id" IS NOT NULL) AND ("auth"."uid"() IN ( SELECT "tm"."user_id"
   FROM ("public"."team_members" "tm"
     JOIN "public"."team_projects" "tp" ON (("tm"."team_id" = "tp"."team_id")))
  WHERE (("tp"."project_id" = "budgets"."project_id") AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text")))))));



CREATE POLICY "Seuls les créateurs et admins peuvent modifier les transaction" ON "public"."budget_transactions" FOR UPDATE USING ((("auth"."uid"() = "created_by") OR ("auth"."uid"() IN ( SELECT "tm"."user_id"
   FROM ("public"."team_members" "tm"
     JOIN "public"."team_projects" "tp" ON (("tm"."team_id" = "tp"."team_id")))
  WHERE (("tp"."project_id" = "budget_transactions"."project_id") AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text"))))));



CREATE POLICY "Seuls les créateurs et admins peuvent supprimer les budgets" ON "public"."budgets" FOR DELETE USING ((("auth"."uid"() = "created_by") OR (("project_id" IS NOT NULL) AND ("auth"."uid"() IN ( SELECT "tm"."user_id"
   FROM ("public"."team_members" "tm"
     JOIN "public"."team_projects" "tp" ON (("tm"."team_id" = "tp"."team_id")))
  WHERE (("tp"."project_id" = "budgets"."project_id") AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text")))))));



CREATE POLICY "Seuls les créateurs et admins peuvent supprimer les transactio" ON "public"."budget_transactions" FOR DELETE USING ((("auth"."uid"() = "created_by") OR ("auth"."uid"() IN ( SELECT "tm"."user_id"
   FROM ("public"."team_members" "tm"
     JOIN "public"."team_projects" "tp" ON (("tm"."team_id" = "tp"."team_id")))
  WHERE (("tp"."project_id" = "budget_transactions"."project_id") AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text"))))));



CREATE POLICY "Seuls les utilisateurs authentifiés peuvent ajouter des catég" ON "public"."transaction_categories" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Seuls les utilisateurs authentifiés peuvent ajouter des sous-c" ON "public"."transaction_subcategories" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Seuls les utilisateurs authentifiés peuvent modifier des caté" ON "public"."transaction_categories" FOR UPDATE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Seuls les utilisateurs authentifiés peuvent modifier des sous-" ON "public"."transaction_subcategories" FOR UPDATE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Seuls les utilisateurs authentifiés peuvent supprimer des cat" ON "public"."transaction_categories" FOR DELETE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Seuls les utilisateurs authentifiés peuvent supprimer des sous" ON "public"."transaction_subcategories" FOR DELETE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Team admins can assign tasks to their teams" ON "public"."team_tasks" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."team_members" "tm"
  WHERE (("tm"."team_id" = "team_tasks"."team_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text")))));



CREATE POLICY "Team admins can remove tasks from their teams" ON "public"."team_tasks" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."team_members" "tm"
  WHERE (("tm"."team_id" = "team_tasks"."team_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text")))));



CREATE POLICY "Temporary allow all operations on invitations" ON "public"."invitations" USING (true);



CREATE POLICY "Temporary allow all operations on profiles" ON "public"."profiles" USING (true);



CREATE POLICY "Temporary allow all operations on team_members" ON "public"."team_members" USING (true);



CREATE POLICY "Temporary allow all operations on teams" ON "public"."teams" USING (true);



CREATE POLICY "Tous les utilisateurs peuvent créer des budgets" ON "public"."budgets" FOR INSERT WITH CHECK (("auth"."uid"() = "created_by"));



CREATE POLICY "Tous les utilisateurs peuvent créer des transactions" ON "public"."budget_transactions" FOR INSERT WITH CHECK (("auth"."uid"() = "created_by"));



CREATE POLICY "Tout le monde peut voir les catégories" ON "public"."transaction_categories" FOR SELECT USING (true);



CREATE POLICY "Tout le monde peut voir les sous-catégories" ON "public"."transaction_subcategories" FOR SELECT USING (true);



CREATE POLICY "Users can add comments to tasks they have access to" ON "public"."task_comments" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") AND (EXISTS ( SELECT 1
   FROM "public"."tasks"
  WHERE (("tasks"."id" = "task_comments"."task_id") AND (("tasks"."created_by" = "auth"."uid"()) OR ("tasks"."assigned_to" = ("auth"."uid"())::"text") OR (EXISTS ( SELECT 1
           FROM ("public"."team_tasks" "tt"
             JOIN "public"."team_members" "tm" ON (("tt"."team_id" = "tm"."team_id")))
          WHERE (("tt"."task_id" = "task_comments"."task_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))) OR (EXISTS ( SELECT 1
           FROM (("public"."tasks" "t"
             JOIN "public"."team_projects" "tp" ON (("t"."project_id" = "tp"."project_id")))
             JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
          WHERE (("t"."id" = "task_comments"."task_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text"))))))))));



CREATE POLICY "Users can delete projects based on RBAC" ON "public"."projects" FOR DELETE USING (("public"."user_has_permission"("auth"."uid"(), 'delete_project'::"text") OR "public"."user_has_permission"("auth"."uid"(), 'delete_project'::"text", NULL::"uuid", "id")));



CREATE POLICY "Users can delete tasks in their projects" ON "public"."tasks" FOR DELETE USING ((("auth"."uid"() = "created_by") OR ("auth"."uid"() IN ( SELECT "projects"."created_by"
   FROM "public"."projects"
  WHERE ("projects"."id" = "tasks"."project_id")))));



CREATE POLICY "Users can delete their own comments" ON "public"."task_comments" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their own projects or team projects" ON "public"."projects" FOR DELETE USING ((("auth"."uid"() = "created_by") OR (EXISTS ( SELECT 1
   FROM ("public"."team_projects" "tp"
     JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
  WHERE (("tp"."project_id" = "projects"."id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text"))))));



CREATE POLICY "Users can delete their own tasks or team tasks" ON "public"."tasks" FOR DELETE USING ((("created_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."team_tasks" "tt"
     JOIN "public"."team_members" "tm" ON (("tt"."team_id" = "tm"."team_id")))
  WHERE (("tt"."task_id" = "tasks"."id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text"))))));



CREATE POLICY "Users can insert projects based on RBAC" ON "public"."projects" FOR INSERT WITH CHECK ("public"."user_has_permission"("auth"."uid"(), 'create_project'::"text"));



CREATE POLICY "Users can insert task history if they can modify the task" ON "public"."task_history" FOR INSERT WITH CHECK (((("auth"."uid"())::"text" = ("user_id")::"text") AND (("auth"."uid"())::"text" IN ( SELECT ("tasks"."created_by")::"text" AS "created_by"
   FROM "public"."tasks"
  WHERE ("tasks"."id" = "task_history"."task_id")
UNION
 SELECT "tasks"."assigned_to"
   FROM "public"."tasks"
  WHERE (("tasks"."id" = "task_history"."task_id") AND ("tasks"."assigned_to" IS NOT NULL))
UNION
 SELECT ("tm"."user_id")::"text" AS "user_id"
   FROM ("public"."team_members" "tm"
     JOIN "public"."team_tasks" "tt" ON (("tm"."team_id" = "tt"."team_id")))
  WHERE ("tt"."task_id" = "tt"."task_id")
UNION
 SELECT ("tm"."user_id")::"text" AS "user_id"
   FROM (("public"."team_members" "tm"
     JOIN "public"."team_projects" "tp" ON (("tm"."team_id" = "tp"."team_id")))
     JOIN "public"."tasks" "t" ON (("tp"."project_id" = "t"."project_id")))
  WHERE ("t"."id" = "task_history"."task_id")))));



CREATE POLICY "Users can insert tasks" ON "public"."tasks" FOR INSERT WITH CHECK ((("created_by" = "auth"."uid"()) AND (("assigned_to" IS NULL) OR ("assigned_to" = ("auth"."uid"())::"text") OR (EXISTS ( SELECT 1
   FROM ("public"."team_members" "tm"
     JOIN "public"."team_members" "current_user_tm" ON (("tm"."team_id" = "current_user_tm"."team_id")))
  WHERE ((("tm"."user_id")::"text" = "tasks"."assigned_to") AND ("current_user_tm"."user_id" = "auth"."uid"()) AND ("current_user_tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text") AND ("current_user_tm"."status" = 'active'::"text")))))));



CREATE POLICY "Users can insert tasks in their projects" ON "public"."tasks" FOR INSERT WITH CHECK (("auth"."uid"() IN ( SELECT "projects"."created_by"
   FROM "public"."projects"
  WHERE ("projects"."id" = "tasks"."project_id"))));



CREATE POLICY "Users can insert their own projects" ON "public"."projects" FOR INSERT WITH CHECK (("auth"."uid"() = "created_by"));



CREATE POLICY "Users can update projects based on RBAC" ON "public"."projects" FOR UPDATE USING ("public"."can_modify_project"("id")) WITH CHECK ("public"."can_modify_project"("id"));



CREATE POLICY "Users can update tasks in their projects" ON "public"."tasks" FOR UPDATE USING ((("auth"."uid"() = "created_by") OR ("auth"."uid"() IN ( SELECT "projects"."created_by"
   FROM "public"."projects"
  WHERE ("projects"."id" = "tasks"."project_id")))));



CREATE POLICY "Users can update their assigned tasks or team tasks" ON "public"."tasks" FOR UPDATE USING ((("assigned_to" = ("auth"."uid"())::"text") OR ("created_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."team_tasks" "tt"
     JOIN "public"."team_members" "tm" ON (("tt"."team_id" = "tm"."team_id")))
  WHERE (("tt"."task_id" = "tasks"."id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text"))))));



CREATE POLICY "Users can update their own comments" ON "public"."task_comments" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own projects or team projects" ON "public"."projects" FOR UPDATE USING ((("auth"."uid"() = "created_by") OR (EXISTS ( SELECT 1
   FROM ("public"."team_projects" "tp"
     JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
  WHERE (("tp"."project_id" = "projects"."id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text"))))));



CREATE POLICY "Users can view comments for tasks they have access to" ON "public"."task_comments" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."tasks"
  WHERE (("tasks"."id" = "task_comments"."task_id") AND (("tasks"."created_by" = "auth"."uid"()) OR ("tasks"."assigned_to" = ("auth"."uid"())::"text") OR (EXISTS ( SELECT 1
           FROM ("public"."team_tasks" "tt"
             JOIN "public"."team_members" "tm" ON (("tt"."team_id" = "tm"."team_id")))
          WHERE (("tt"."task_id" = "task_comments"."task_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))) OR (EXISTS ( SELECT 1
           FROM (("public"."tasks" "t"
             JOIN "public"."team_projects" "tp" ON (("t"."project_id" = "tp"."project_id")))
             JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
          WHERE (("t"."id" = "task_comments"."task_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))))))));



CREATE POLICY "Users can view permissions" ON "public"."permissions" FOR SELECT USING (true);



CREATE POLICY "Users can view projects based on RBAC" ON "public"."projects" FOR SELECT USING ("public"."can_access_project"("id"));



CREATE POLICY "Users can view role_permissions" ON "public"."role_permissions" FOR SELECT USING (true);



CREATE POLICY "Users can view roles" ON "public"."roles" FOR SELECT USING (true);



CREATE POLICY "Users can view task history if they can view the task" ON "public"."task_history" FOR SELECT USING ((("auth"."uid"())::"text" IN ( SELECT ("tasks"."created_by")::"text" AS "created_by"
   FROM "public"."tasks"
  WHERE ("tasks"."id" = "task_history"."task_id")
UNION
 SELECT "tasks"."assigned_to"
   FROM "public"."tasks"
  WHERE (("tasks"."id" = "task_history"."task_id") AND ("tasks"."assigned_to" IS NOT NULL))
UNION
 SELECT ("tm"."user_id")::"text" AS "user_id"
   FROM ("public"."team_members" "tm"
     JOIN "public"."team_tasks" "tt" ON (("tm"."team_id" = "tt"."team_id")))
  WHERE ("tt"."task_id" = "tt"."task_id")
UNION
 SELECT ("tm"."user_id")::"text" AS "user_id"
   FROM (("public"."team_members" "tm"
     JOIN "public"."team_projects" "tp" ON (("tm"."team_id" = "tp"."team_id")))
     JOIN "public"."tasks" "t" ON (("tp"."project_id" = "t"."project_id")))
  WHERE ("t"."id" = "task_history"."task_id"))));



CREATE POLICY "Users can view tasks of their projects" ON "public"."tasks" FOR SELECT USING ((("auth"."uid"() = "created_by") OR ("auth"."uid"() IN ( SELECT "projects"."created_by"
   FROM "public"."projects"
  WHERE ("projects"."id" = "tasks"."project_id")))));



CREATE POLICY "Users can view their assigned tasks or team tasks" ON "public"."tasks" FOR SELECT USING ((("assigned_to" = ("auth"."uid"())::"text") OR ("created_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."team_tasks" "tt"
     JOIN "public"."team_members" "tm" ON (("tt"."team_id" = "tm"."team_id")))
  WHERE (("tt"."task_id" = "tasks"."id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))) OR (EXISTS ( SELECT 1
   FROM (("public"."projects" "p"
     JOIN "public"."team_projects" "tp" ON (("p"."id" = "tp"."project_id")))
     JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
  WHERE (("tasks"."project_id" = "p"."id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text"))))));



CREATE POLICY "Users can view their own projects or team projects" ON "public"."projects" FOR SELECT USING ((("auth"."uid"() = "created_by") OR (EXISTS ( SELECT 1
   FROM ("public"."team_projects" "tp"
     JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
  WHERE (("tp"."project_id" = "projects"."id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text"))))));



CREATE POLICY "Users can view their roles" ON "public"."user_roles" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR "public"."user_has_permission"("auth"."uid"(), 'manage_users'::"text") OR (("project_id" IS NOT NULL) AND "public"."can_access_project"("project_id")) OR (("team_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."team_members"
  WHERE (("team_members"."team_id" = "user_roles"."team_id") AND ("team_members"."user_id" = "auth"."uid"()) AND ("team_members"."status" = 'active'::"text")))))));



CREATE POLICY "Users can view their team tasks" ON "public"."team_tasks" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."team_members" "tm"
  WHERE (("tm"."team_id" = "team_tasks"."team_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))));



CREATE POLICY "Utilisateurs authentifiés peuvent appeler accept_team_invitati" ON "public"."invitations" TO "authenticated" USING (true);



CREATE POLICY "Utilisateurs peuvent créer des allocations" ON "public"."budget_allocations" FOR INSERT WITH CHECK ((("created_by" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."budgets"
  WHERE (("budgets"."id" = "budget_allocations"."budget_id") AND ("budgets"."created_by" = "auth"."uid"()))))));



CREATE POLICY "Utilisateurs peuvent créer des phases pour leurs projets" ON "public"."phases" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."projects"
  WHERE (("projects"."id" = "phases"."project_id") AND (("projects"."created_by" = "auth"."uid"()) OR (("auth"."uid"())::"text" = ANY ("projects"."members")) OR (EXISTS ( SELECT 1
           FROM ("public"."team_projects" "tp"
             JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
          WHERE (("tp"."project_id" = "phases"."project_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))))))));



CREATE POLICY "Utilisateurs peuvent créer des pièces jointes pour les tâche" ON "public"."attachments" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."tasks"
     JOIN "public"."projects" ON (("tasks"."project_id" = "projects"."id")))
  WHERE (("tasks"."id" = "attachments"."task_id") AND (("projects"."created_by" = "auth"."uid"()) OR (("auth"."uid"())::"text" = ANY ("projects"."members")) OR (EXISTS ( SELECT 1
           FROM ("public"."team_projects" "tp"
             JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
          WHERE (("tp"."project_id" = "projects"."id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))))))));



CREATE POLICY "Utilisateurs peuvent créer des transactions" ON "public"."budget_transactions" FOR INSERT WITH CHECK ((("created_by" = "auth"."uid"()) AND (("budget_id" IS NULL) OR (EXISTS ( SELECT 1
   FROM "public"."budgets"
  WHERE (("budgets"."id" = "budget_transactions"."budget_id") AND ("budgets"."created_by" = "auth"."uid"())))))));



CREATE POLICY "Utilisateurs peuvent créer des tâches pour les projets auxque" ON "public"."tasks" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."projects"
  WHERE (("projects"."id" = "tasks"."project_id") AND (("projects"."created_by" = "auth"."uid"()) OR (("auth"."uid"())::"text" = ANY ("projects"."members")) OR (EXISTS ( SELECT 1
           FROM ("public"."team_projects" "tp"
             JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
          WHERE (("tp"."project_id" = "tasks"."project_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))))))));



CREATE POLICY "Utilisateurs peuvent créer leurs budgets" ON "public"."budgets" FOR INSERT WITH CHECK (("created_by" = "auth"."uid"()));



CREATE POLICY "Utilisateurs peuvent mettre à jour les phases de leurs projets" ON "public"."phases" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."projects"
  WHERE (("projects"."id" = "phases"."project_id") AND (("projects"."created_by" = "auth"."uid"()) OR (("auth"."uid"())::"text" = ANY ("projects"."members")) OR (EXISTS ( SELECT 1
           FROM ("public"."team_projects" "tp"
             JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
          WHERE (("tp"."project_id" = "phases"."project_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))))))));



CREATE POLICY "Utilisateurs peuvent mettre à jour les tâches des projets aux" ON "public"."tasks" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."projects"
  WHERE (("projects"."id" = "tasks"."project_id") AND (("projects"."created_by" = "auth"."uid"()) OR (("auth"."uid"())::"text" = ANY ("projects"."members")) OR (EXISTS ( SELECT 1
           FROM ("public"."team_projects" "tp"
             JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
          WHERE (("tp"."project_id" = "tasks"."project_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))))))));



CREATE POLICY "Utilisateurs peuvent mettre à jour leurs allocations" ON "public"."budget_allocations" FOR UPDATE USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Utilisateurs peuvent mettre à jour leurs budgets" ON "public"."budgets" FOR UPDATE USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Utilisateurs peuvent mettre à jour leurs transactions" ON "public"."budget_transactions" FOR UPDATE USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Utilisateurs peuvent supprimer les phases des projets qu'ils on" ON "public"."phases" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."projects"
  WHERE (("projects"."id" = "phases"."project_id") AND ("projects"."created_by" = "auth"."uid"())))));



CREATE POLICY "Utilisateurs peuvent supprimer leurs allocations" ON "public"."budget_allocations" FOR DELETE USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Utilisateurs peuvent supprimer leurs budgets" ON "public"."budgets" FOR DELETE USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Utilisateurs peuvent supprimer leurs propres pièces jointes" ON "public"."attachments" FOR DELETE USING ((("uploaded_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."tasks"
     JOIN "public"."projects" ON (("tasks"."project_id" = "projects"."id")))
  WHERE (("tasks"."id" = "attachments"."task_id") AND ("projects"."created_by" = "auth"."uid"()))))));



CREATE POLICY "Utilisateurs peuvent supprimer leurs transactions" ON "public"."budget_transactions" FOR DELETE USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Utilisateurs peuvent voir les budgets de leurs équipes" ON "public"."budgets" FOR SELECT USING ((("auth"."uid"() = "created_by") OR ("team_id" IN ( SELECT "team_members"."team_id"
   FROM "public"."team_members"
  WHERE (("team_members"."user_id" = "auth"."uid"()) AND ("team_members"."status" = 'active'::"text"))))));



CREATE POLICY "Utilisateurs peuvent voir les phases des projets auxquels ils a" ON "public"."phases" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."projects"
  WHERE (("projects"."id" = "phases"."project_id") AND (("projects"."created_by" = "auth"."uid"()) OR (("auth"."uid"())::"text" = ANY ("projects"."members")) OR (EXISTS ( SELECT 1
           FROM ("public"."team_projects" "tp"
             JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
          WHERE (("tp"."project_id" = "phases"."project_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))))))));



CREATE POLICY "Utilisateurs peuvent voir les pièces jointes des tâches auxqu" ON "public"."attachments" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."tasks"
     JOIN "public"."projects" ON (("tasks"."project_id" = "projects"."id")))
  WHERE (("tasks"."id" = "attachments"."task_id") AND (("projects"."created_by" = "auth"."uid"()) OR (("auth"."uid"())::"text" = ANY ("projects"."members")) OR (EXISTS ( SELECT 1
           FROM ("public"."team_projects" "tp"
             JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
          WHERE (("tp"."project_id" = "projects"."id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))))))));



CREATE POLICY "Utilisateurs peuvent voir les tâches des projets auxquels ils " ON "public"."tasks" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."projects"
  WHERE (("projects"."id" = "tasks"."project_id") AND (("projects"."created_by" = "auth"."uid"()) OR (("auth"."uid"())::"text" = ANY ("projects"."members")) OR (EXISTS ( SELECT 1
           FROM ("public"."team_projects" "tp"
             JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
          WHERE (("tp"."project_id" = "tasks"."project_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))))))));



CREATE POLICY "Utilisateurs peuvent voir leurs allocations" ON "public"."budget_allocations" FOR SELECT USING ((("created_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."budgets"
  WHERE (("budgets"."id" = "budget_allocations"."budget_id") AND ("budgets"."created_by" = "auth"."uid"()))))));



CREATE POLICY "Utilisateurs peuvent voir leurs budgets" ON "public"."budgets" FOR SELECT USING (("created_by" = "auth"."uid"()));



CREATE POLICY "Utilisateurs peuvent voir leurs transactions" ON "public"."budget_transactions" FOR SELECT USING ((("created_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."budgets"
  WHERE (("budgets"."id" = "budget_transactions"."budget_id") AND ("budgets"."created_by" = "auth"."uid"()))))));



ALTER TABLE "public"."attachments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "autoriser_invitations" ON "public"."user_roles" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."invitations" "i"
  WHERE (("i"."team_id" = "i"."team_id") AND ("i"."status" = 'pending'::"text") AND ("i"."expires_at" > "now"())))));



ALTER TABLE "public"."budget_allocations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."budget_transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."budgets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."invitations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "invitations_delete_policy" ON "public"."invitations" FOR DELETE USING (("team_id" IN ( SELECT "team_members"."team_id"
   FROM "public"."team_members"
  WHERE (("team_members"."user_id" = "auth"."uid"()) AND ("team_members"."role" = 'admin'::"text") AND ("team_members"."status" = 'active'::"text")))));



CREATE POLICY "invitations_insert_policy" ON "public"."invitations" FOR INSERT WITH CHECK (("team_id" IN ( SELECT "team_members"."team_id"
   FROM "public"."team_members"
  WHERE (("team_members"."user_id" = "auth"."uid"()) AND ("team_members"."role" = 'admin'::"text") AND ("team_members"."status" = 'active'::"text")))));



CREATE POLICY "invitations_select_received_policy" ON "public"."invitations" FOR SELECT USING (("email" = ( SELECT COALESCE(NULLIF("current_setting"('request.jwt.claim.email'::"text", true), ''::"text"), NULLIF("current_setting"('request.jwt.claims.email'::"text", true), ''::"text")) AS "coalesce")));



CREATE POLICY "invitations_select_sent_policy" ON "public"."invitations" FOR SELECT USING (("invited_by" = "auth"."uid"()));



CREATE POLICY "invitations_update_received_policy" ON "public"."invitations" FOR UPDATE USING (("email" = (( SELECT "users"."email"
   FROM "auth"."users"
  WHERE ("users"."id" = "auth"."uid"())))::"text"));



CREATE POLICY "invitations_update_sent_policy" ON "public"."invitations" FOR UPDATE USING ((("invited_by" = "auth"."uid"()) AND ("team_id" IN ( SELECT "team_members"."team_id"
   FROM "public"."team_members"
  WHERE (("team_members"."user_id" = "auth"."uid"()) AND ("team_members"."role" = 'admin'::"text") AND ("team_members"."status" = 'active'::"text"))))));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."permissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."phases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_select_policy" ON "public"."profiles" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "profiles_update_policy" ON "public"."profiles" FOR UPDATE USING (("id" = "auth"."uid"()));



ALTER TABLE "public"."projects" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."rbac_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "rbac_logs_insert_policy" ON "public"."rbac_logs" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "rbac_logs_select_policy" ON "public"."rbac_logs" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."user_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."role_id" = "r"."id")))
  WHERE (("ur"."user_id" = "auth"."uid"()) AND ("r"."name" = 'system_admin'::"text"))))));



ALTER TABLE "public"."role_permissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."task_comments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."task_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tasks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."team_members" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "team_members_delete_policy" ON "public"."team_members" FOR DELETE USING (("team_id" IN ( SELECT "teams"."id"
   FROM "public"."teams"
  WHERE ("teams"."created_by" = "auth"."uid"()))));



CREATE POLICY "team_members_insert_policy" ON "public"."team_members" FOR INSERT WITH CHECK (("team_id" IN ( SELECT "teams"."id"
   FROM "public"."teams"
  WHERE ("teams"."created_by" = "auth"."uid"()))));



CREATE POLICY "team_members_select_policy" ON "public"."team_members" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR ("team_id" IN ( SELECT "teams"."id"
   FROM "public"."teams"
  WHERE ("teams"."created_by" = "auth"."uid"())))));



CREATE POLICY "team_members_update_own_policy" ON "public"."team_members" FOR UPDATE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "team_members_update_policy" ON "public"."team_members" FOR UPDATE USING (("team_id" IN ( SELECT "teams"."id"
   FROM "public"."teams"
  WHERE ("teams"."created_by" = "auth"."uid"()))));



ALTER TABLE "public"."team_projects" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "team_projects_delete_policy" ON "public"."team_projects" FOR DELETE USING (("team_id" IN ( SELECT "teams"."id"
   FROM "public"."teams"
  WHERE ("teams"."created_by" = "auth"."uid"()))));



CREATE POLICY "team_projects_insert_policy" ON "public"."team_projects" FOR INSERT WITH CHECK ((("team_id" IN ( SELECT "teams"."id"
   FROM "public"."teams"
  WHERE ("teams"."created_by" = "auth"."uid"()))) OR ("team_id" IN ( SELECT "team_members"."team_id"
   FROM "public"."team_members"
  WHERE (("team_members"."user_id" = "auth"."uid"()) AND ("team_members"."role" = 'admin'::"text") AND ("team_members"."status" = 'active'::"text"))))));



CREATE POLICY "team_projects_select_policy" ON "public"."team_projects" FOR SELECT USING ((("team_id" IN ( SELECT "teams"."id"
   FROM "public"."teams"
  WHERE ("teams"."created_by" = "auth"."uid"()))) OR ("team_id" IN ( SELECT "team_members"."team_id"
   FROM "public"."team_members"
  WHERE (("team_members"."user_id" = "auth"."uid"()) AND ("team_members"."status" = 'active'::"text"))))));



CREATE POLICY "team_projects_update_policy" ON "public"."team_projects" FOR UPDATE USING (("team_id" IN ( SELECT "team_members"."team_id"
   FROM "public"."team_members"
  WHERE (("team_members"."user_id" = "auth"."uid"()) AND ("team_members"."role" = 'admin'::"text") AND ("team_members"."status" = 'active'::"text")))));



ALTER TABLE "public"."team_tasks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."teams" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "teams_delete_policy" ON "public"."teams" FOR DELETE USING (("created_by" = "auth"."uid"()));



CREATE POLICY "teams_insert_policy" ON "public"."teams" FOR INSERT WITH CHECK (("created_by" = "auth"."uid"()));



CREATE POLICY "teams_select_policy" ON "public"."teams" FOR SELECT USING (("created_by" = "auth"."uid"()));



CREATE POLICY "teams_update_policy" ON "public"."teams" FOR UPDATE USING (("created_by" = "auth"."uid"()));



ALTER TABLE "public"."transaction_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."transaction_subcategories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_roles" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";




















































































































































































GRANT ALL ON FUNCTION "public"."accept_team_invitation_by_token"("p_token" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."accept_team_invitation_by_token"("p_token" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."accept_team_invitation_by_token"("p_token" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."allocate_budget_to_project"("p_budget_id" "text", "p_project_id" "text", "p_amount" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."allocate_budget_to_project"("p_budget_id" "text", "p_project_id" "text", "p_amount" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."allocate_budget_to_project"("p_budget_id" "text", "p_project_id" "text", "p_amount" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."assign_user_role"("p_user_id" "uuid", "p_role_name" "text", "p_team_id" "uuid", "p_project_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."assign_user_role"("p_user_id" "uuid", "p_role_name" "text", "p_team_id" "uuid", "p_project_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."assign_user_role"("p_user_id" "uuid", "p_role_name" "text", "p_team_id" "uuid", "p_project_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_access_project"("project_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_access_project"("project_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_access_project"("project_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_modify_project"("project_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_modify_project"("project_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_modify_project"("project_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."clean_old_rbac_logs"() TO "anon";
GRANT ALL ON FUNCTION "public"."clean_old_rbac_logs"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."clean_old_rbac_logs"() TO "service_role";



GRANT ALL ON FUNCTION "public"."exec_sql"("query" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."exec_sql"("query" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."exec_sql"("query" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."execute_sql"("query" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."execute_sql"("query" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."execute_sql"("query" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_task_changes"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_task_changes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_task_changes"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."migrate_team_members_to_rbac"() TO "anon";
GRANT ALL ON FUNCTION "public"."migrate_team_members_to_rbac"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."migrate_team_members_to_rbac"() TO "service_role";



GRANT ALL ON FUNCTION "public"."process_budget_transaction"() TO "anon";
GRANT ALL ON FUNCTION "public"."process_budget_transaction"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_budget_transaction"() TO "service_role";



GRANT ALL ON FUNCTION "public"."recalculate_phase_budget_consumption"("p_phase_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."recalculate_phase_budget_consumption"("p_phase_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recalculate_phase_budget_consumption"("p_phase_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."recalculate_phase_budget_consumption"("p_phase_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recalculate_phase_budget_consumption"("p_phase_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recalculate_phase_budget_consumption"("p_phase_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."recalculate_project_budget_consumption"("p_project_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."recalculate_project_budget_consumption"("p_project_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recalculate_project_budget_consumption"("p_project_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."recalculate_project_budget_consumption"("p_project_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recalculate_project_budget_consumption"("p_project_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recalculate_project_budget_consumption"("p_project_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_budget_team_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_budget_team_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_budget_team_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_team_member_to_user_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_team_member_to_user_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_team_member_to_user_role"() TO "service_role";



GRANT ALL ON FUNCTION "public"."task_budget_trigger_function"() TO "anon";
GRANT ALL ON FUNCTION "public"."task_budget_trigger_function"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."task_budget_trigger_function"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_budget_current_amount"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_budget_current_amount"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_budget_current_amount"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_phase_budget_consumption"("p_phase_id" "text", "p_amount" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."update_phase_budget_consumption"("p_phase_id" "text", "p_amount" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_phase_budget_consumption"("p_phase_id" "text", "p_amount" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_phase_budget_consumption"("p_phase_id" "uuid", "p_amount" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."update_phase_budget_consumption"("p_phase_id" "uuid", "p_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_phase_budget_consumption"("p_phase_id" "uuid", "p_amount" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_project_budget_allocation"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_project_budget_allocation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_project_budget_allocation"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_project_budget_consumption"("p_project_id" "text", "p_amount" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."update_project_budget_consumption"("p_project_id" "text", "p_amount" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_project_budget_consumption"("p_project_id" "text", "p_amount" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_project_budget_consumption"("p_project_id" "uuid", "p_amount" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."update_project_budget_consumption"("p_project_id" "uuid", "p_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_project_budget_consumption"("p_project_id" "uuid", "p_amount" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."user_has_permission"("p_user_id" "uuid", "p_permission_name" "text", "p_team_id" "uuid", "p_project_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."user_has_permission"("p_user_id" "uuid", "p_permission_name" "text", "p_team_id" "uuid", "p_project_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_has_permission"("p_user_id" "uuid", "p_permission_name" "text", "p_team_id" "uuid", "p_project_id" "uuid") TO "service_role";


















GRANT ALL ON TABLE "public"."attachments" TO "anon";
GRANT ALL ON TABLE "public"."attachments" TO "authenticated";
GRANT ALL ON TABLE "public"."attachments" TO "service_role";



GRANT ALL ON TABLE "public"."budget_allocations" TO "anon";
GRANT ALL ON TABLE "public"."budget_allocations" TO "authenticated";
GRANT ALL ON TABLE "public"."budget_allocations" TO "service_role";



GRANT ALL ON TABLE "public"."budget_transactions" TO "anon";
GRANT ALL ON TABLE "public"."budget_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."budget_transactions" TO "service_role";



GRANT ALL ON TABLE "public"."budgets" TO "anon";
GRANT ALL ON TABLE "public"."budgets" TO "authenticated";
GRANT ALL ON TABLE "public"."budgets" TO "service_role";



GRANT ALL ON TABLE "public"."invitations" TO "anon";
GRANT ALL ON TABLE "public"."invitations" TO "authenticated";
GRANT ALL ON TABLE "public"."invitations" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."permissions" TO "anon";
GRANT ALL ON TABLE "public"."permissions" TO "authenticated";
GRANT ALL ON TABLE "public"."permissions" TO "service_role";



GRANT ALL ON TABLE "public"."phases" TO "anon";
GRANT ALL ON TABLE "public"."phases" TO "authenticated";
GRANT ALL ON TABLE "public"."phases" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."projects" TO "anon";
GRANT ALL ON TABLE "public"."projects" TO "authenticated";
GRANT ALL ON TABLE "public"."projects" TO "service_role";



GRANT ALL ON TABLE "public"."rbac_logs" TO "anon";
GRANT ALL ON TABLE "public"."rbac_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."rbac_logs" TO "service_role";



GRANT ALL ON TABLE "public"."role_permissions" TO "anon";
GRANT ALL ON TABLE "public"."role_permissions" TO "authenticated";
GRANT ALL ON TABLE "public"."role_permissions" TO "service_role";



GRANT ALL ON TABLE "public"."roles" TO "anon";
GRANT ALL ON TABLE "public"."roles" TO "authenticated";
GRANT ALL ON TABLE "public"."roles" TO "service_role";



GRANT ALL ON TABLE "public"."task_comments" TO "anon";
GRANT ALL ON TABLE "public"."task_comments" TO "authenticated";
GRANT ALL ON TABLE "public"."task_comments" TO "service_role";



GRANT ALL ON TABLE "public"."task_history" TO "anon";
GRANT ALL ON TABLE "public"."task_history" TO "authenticated";
GRANT ALL ON TABLE "public"."task_history" TO "service_role";



GRANT ALL ON TABLE "public"."tasks" TO "anon";
GRANT ALL ON TABLE "public"."tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."tasks" TO "service_role";



GRANT ALL ON TABLE "public"."team_members" TO "anon";
GRANT ALL ON TABLE "public"."team_members" TO "authenticated";
GRANT ALL ON TABLE "public"."team_members" TO "service_role";



GRANT ALL ON TABLE "public"."team_projects" TO "anon";
GRANT ALL ON TABLE "public"."team_projects" TO "authenticated";
GRANT ALL ON TABLE "public"."team_projects" TO "service_role";



GRANT ALL ON TABLE "public"."team_tasks" TO "anon";
GRANT ALL ON TABLE "public"."team_tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."team_tasks" TO "service_role";



GRANT ALL ON TABLE "public"."teams" TO "anon";
GRANT ALL ON TABLE "public"."teams" TO "authenticated";
GRANT ALL ON TABLE "public"."teams" TO "service_role";



GRANT ALL ON TABLE "public"."transaction_categories" TO "anon";
GRANT ALL ON TABLE "public"."transaction_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."transaction_categories" TO "service_role";



GRANT ALL ON TABLE "public"."transaction_subcategories" TO "anon";
GRANT ALL ON TABLE "public"."transaction_subcategories" TO "authenticated";
GRANT ALL ON TABLE "public"."transaction_subcategories" TO "service_role";



GRANT ALL ON TABLE "public"."user_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles" TO "service_role";



GRANT ALL ON TABLE "public"."user_permissions_view" TO "anon";
GRANT ALL ON TABLE "public"."user_permissions_view" TO "authenticated";
GRANT ALL ON TABLE "public"."user_permissions_view" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;
