

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
    "category" "text" NOT NULL,
    "subcategory" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone,
    "created_by" "uuid" NOT NULL,
    CONSTRAINT "budget_transactions_category_check" CHECK (("category" = ANY (ARRAY['income'::"text", 'expense'::"text"])))
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
    CONSTRAINT "invitations_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'accepted'::"text", 'rejected'::"text", 'expired'::"text"])))
);


ALTER TABLE "public"."invitations" OWNER TO "postgres";


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
    "budget_consumed" numeric(15,2) DEFAULT 0
);


ALTER TABLE "public"."projects" OWNER TO "postgres";


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



ALTER TABLE ONLY "public"."phases"
    ADD CONSTRAINT "phases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projects"
    ADD CONSTRAINT "projects_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_history"
    ADD CONSTRAINT "task_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_team_id_user_id_key" UNIQUE ("team_id", "user_id");



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



CREATE INDEX "attachments_task_id_idx" ON "public"."attachments" USING "btree" ("task_id");



CREATE INDEX "budget_allocations_budget_id_idx" ON "public"."budget_allocations" USING "btree" ("budget_id");



CREATE INDEX "budget_allocations_project_id_idx" ON "public"."budget_allocations" USING "btree" ("project_id");



CREATE INDEX "budget_transactions_budget_id_idx" ON "public"."budget_transactions" USING "btree" ("budget_id");



CREATE INDEX "budget_transactions_category_idx" ON "public"."budget_transactions" USING "btree" ("category");



CREATE INDEX "budget_transactions_date_idx" ON "public"."budget_transactions" USING "btree" ("transaction_date");



CREATE INDEX "budget_transactions_project_id_idx" ON "public"."budget_transactions" USING "btree" ("project_id");



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



CREATE OR REPLACE TRIGGER "task_budget_trigger" AFTER UPDATE ON "public"."tasks" FOR EACH ROW WHEN (("old"."budget_consumed" IS DISTINCT FROM "new"."budget_consumed")) EXECUTE FUNCTION "public"."task_budget_trigger_function"();



CREATE OR REPLACE TRIGGER "task_validation_trigger" BEFORE INSERT OR UPDATE ON "public"."tasks" FOR EACH ROW EXECUTE FUNCTION "public"."handle_task_changes"();



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
    ADD CONSTRAINT "budget_transactions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."budget_transactions"
    ADD CONSTRAINT "budget_transactions_phase_id_fkey" FOREIGN KEY ("phase_id") REFERENCES "public"."phases"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."budget_transactions"
    ADD CONSTRAINT "budget_transactions_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE SET NULL;



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



CREATE POLICY "Users can delete tasks in their projects" ON "public"."tasks" FOR DELETE USING ((("auth"."uid"() = "created_by") OR ("auth"."uid"() IN ( SELECT "projects"."created_by"
   FROM "public"."projects"
  WHERE ("projects"."id" = "tasks"."project_id")))));



CREATE POLICY "Users can delete their own projects or team projects" ON "public"."projects" FOR DELETE USING ((("auth"."uid"() = "created_by") OR (EXISTS ( SELECT 1
   FROM ("public"."team_projects" "tp"
     JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
  WHERE (("tp"."project_id" = "projects"."id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text"))))));



CREATE POLICY "Users can delete their own tasks or team tasks" ON "public"."tasks" FOR DELETE USING ((("created_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."team_tasks" "tt"
     JOIN "public"."team_members" "tm" ON (("tt"."team_id" = "tm"."team_id")))
  WHERE (("tt"."task_id" = "tasks"."id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text"))))));



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



CREATE POLICY "Users can update tasks in their projects" ON "public"."tasks" FOR UPDATE USING ((("auth"."uid"() = "created_by") OR ("auth"."uid"() IN ( SELECT "projects"."created_by"
   FROM "public"."projects"
  WHERE ("projects"."id" = "tasks"."project_id")))));



CREATE POLICY "Users can update their assigned tasks or team tasks" ON "public"."tasks" FOR UPDATE USING ((("assigned_to" = ("auth"."uid"())::"text") OR ("created_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."team_tasks" "tt"
     JOIN "public"."team_members" "tm" ON (("tt"."team_id" = "tm"."team_id")))
  WHERE (("tt"."task_id" = "tasks"."id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text"))))));



CREATE POLICY "Users can update their own projects or team projects" ON "public"."projects" FOR UPDATE USING ((("auth"."uid"() = "created_by") OR (EXISTS ( SELECT 1
   FROM ("public"."team_projects" "tp"
     JOIN "public"."team_members" "tm" ON (("tp"."team_id" = "tm"."team_id")))
  WHERE (("tp"."project_id" = "projects"."id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."role" = 'admin'::"text") AND ("tm"."status" = 'active'::"text"))))));



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



CREATE POLICY "Users can view their team tasks" ON "public"."team_tasks" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."team_members" "tm"
  WHERE (("tm"."team_id" = "team_tasks"."team_id") AND ("tm"."user_id" = "auth"."uid"()) AND ("tm"."status" = 'active'::"text")))));



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


ALTER TABLE "public"."phases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_select_policy" ON "public"."profiles" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "profiles_update_policy" ON "public"."profiles" FOR UPDATE USING (("id" = "auth"."uid"()));



ALTER TABLE "public"."projects" ENABLE ROW LEVEL SECURITY;


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



CREATE POLICY "team_projects_insert_policy" ON "public"."team_projects" FOR INSERT WITH CHECK (("team_id" IN ( SELECT "teams"."id"
   FROM "public"."teams"
  WHERE ("teams"."created_by" = "auth"."uid"()))));



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





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";




















































































































































































GRANT ALL ON FUNCTION "public"."allocate_budget_to_project"("p_budget_id" "text", "p_project_id" "text", "p_amount" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."allocate_budget_to_project"("p_budget_id" "text", "p_project_id" "text", "p_amount" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."allocate_budget_to_project"("p_budget_id" "text", "p_project_id" "text", "p_amount" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_task_changes"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_task_changes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_task_changes"() TO "service_role";



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



GRANT ALL ON TABLE "public"."phases" TO "anon";
GRANT ALL ON TABLE "public"."phases" TO "authenticated";
GRANT ALL ON TABLE "public"."phases" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."projects" TO "anon";
GRANT ALL ON TABLE "public"."projects" TO "authenticated";
GRANT ALL ON TABLE "public"."projects" TO "service_role";



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
