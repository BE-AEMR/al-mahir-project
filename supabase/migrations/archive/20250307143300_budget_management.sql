-- Migration pour ajouter la gestion de budget - 2025-03-07

-- 1. Ajout de colonnes aux tables existantes
-- Ajout des colonnes de budget aux projets
ALTER TABLE public.projects 
ADD COLUMN IF NOT EXISTS budget_allocated DECIMAL(15, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS budget_consumed DECIMAL(15, 2) DEFAULT 0;

-- Ajout des colonnes de budget aux phases
ALTER TABLE public.phases 
ADD COLUMN IF NOT EXISTS budget_allocated DECIMAL(15, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS budget_consumed DECIMAL(15, 2) DEFAULT 0;

-- Ajout des colonnes de budget aux tâches
ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS budget_allocated DECIMAL(15, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS budget_consumed DECIMAL(15, 2) DEFAULT 0;

-- 2. Création de nouvelles tables pour la gestion de budget global

-- Table des budgets
CREATE TABLE IF NOT EXISTS public.budgets (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    initial_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    current_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by UUID NOT NULL REFERENCES auth.users(id)
);

-- Table des transactions budgétaires
CREATE TABLE IF NOT EXISTS public.budget_transactions (
    id UUID PRIMARY KEY,
    budget_id UUID REFERENCES public.budgets(id) ON DELETE CASCADE,
    project_id UUID REFERENCES public.projects(id) ON DELETE SET NULL,
    phase_id UUID REFERENCES public.phases(id) ON DELETE SET NULL,
    task_id UUID REFERENCES public.tasks(id) ON DELETE SET NULL,
    amount DECIMAL(15, 2) NOT NULL,
    description TEXT NOT NULL,
    transaction_date TIMESTAMP WITH TIME ZONE NOT NULL,
    category TEXT NOT NULL,
    subcategory TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by UUID NOT NULL REFERENCES auth.users(id),
    CONSTRAINT budget_transactions_category_check CHECK (category IN ('income', 'expense'))
);

-- Table des allocations budgétaires aux projets
CREATE TABLE IF NOT EXISTS public.budget_allocations (
    id UUID PRIMARY KEY,
    budget_id UUID NOT NULL REFERENCES public.budgets(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    amount DECIMAL(15, 2) NOT NULL,
    allocation_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE,
    created_by UUID NOT NULL REFERENCES auth.users(id),
    UNIQUE(budget_id, project_id)
);

-- 3. Création des index pour l'optimisation des requêtes
CREATE INDEX IF NOT EXISTS budget_transactions_budget_id_idx ON public.budget_transactions(budget_id);
CREATE INDEX IF NOT EXISTS budget_transactions_project_id_idx ON public.budget_transactions(project_id);
CREATE INDEX IF NOT EXISTS budget_transactions_category_idx ON public.budget_transactions(category);
CREATE INDEX IF NOT EXISTS budget_transactions_date_idx ON public.budget_transactions(transaction_date);
CREATE INDEX IF NOT EXISTS budget_allocations_budget_id_idx ON public.budget_allocations(budget_id);
CREATE INDEX IF NOT EXISTS budget_allocations_project_id_idx ON public.budget_allocations(project_id);

-- 4. Configuration de la sécurité RLS (Row Level Security)
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budget_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budget_allocations ENABLE ROW LEVEL SECURITY;

-- Politiques pour budgets
CREATE POLICY "Utilisateurs peuvent voir leurs budgets" ON public.budgets
    FOR SELECT
    USING (created_by = auth.uid());

CREATE POLICY "Utilisateurs peuvent créer leurs budgets" ON public.budgets
    FOR INSERT
    WITH CHECK (created_by = auth.uid());

CREATE POLICY "Utilisateurs peuvent mettre à jour leurs budgets" ON public.budgets
    FOR UPDATE
    USING (created_by = auth.uid());

CREATE POLICY "Utilisateurs peuvent supprimer leurs budgets" ON public.budgets
    FOR DELETE
    USING (created_by = auth.uid());

-- Politiques pour transactions budgétaires
CREATE POLICY "Utilisateurs peuvent voir leurs transactions" ON public.budget_transactions
    FOR SELECT
    USING (
        created_by = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.budgets
            WHERE budgets.id = budget_transactions.budget_id
            AND budgets.created_by = auth.uid()
        )
    );

CREATE POLICY "Utilisateurs peuvent créer des transactions" ON public.budget_transactions
    FOR INSERT
    WITH CHECK (
        created_by = auth.uid() AND
        (
            budget_id IS NULL OR
            EXISTS (
                SELECT 1 FROM public.budgets
                WHERE budgets.id = budget_transactions.budget_id
                AND budgets.created_by = auth.uid()
            )
        )
    );

CREATE POLICY "Utilisateurs peuvent mettre à jour leurs transactions" ON public.budget_transactions
    FOR UPDATE
    USING (created_by = auth.uid());

CREATE POLICY "Utilisateurs peuvent supprimer leurs transactions" ON public.budget_transactions
    FOR DELETE
    USING (created_by = auth.uid());

-- Politiques pour allocations budgétaires
CREATE POLICY "Utilisateurs peuvent voir leurs allocations" ON public.budget_allocations
    FOR SELECT
    USING (
        created_by = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.budgets
            WHERE budgets.id = budget_allocations.budget_id
            AND budgets.created_by = auth.uid()
        )
    );

CREATE POLICY "Utilisateurs peuvent créer des allocations" ON public.budget_allocations
    FOR INSERT
    WITH CHECK (
        created_by = auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.budgets
            WHERE budgets.id = budget_allocations.budget_id
            AND budgets.created_by = auth.uid()
        )
    );

CREATE POLICY "Utilisateurs peuvent mettre à jour leurs allocations" ON public.budget_allocations
    FOR UPDATE
    USING (created_by = auth.uid());

CREATE POLICY "Utilisateurs peuvent supprimer leurs allocations" ON public.budget_allocations
    FOR DELETE
    USING (created_by = auth.uid());

-- 5. Création de fonctions pour la gestion automatique des montants
-- Fonction pour mettre à jour le montant actuel du budget lors d'ajout/modification/suppression de transaction
CREATE OR REPLACE FUNCTION public.update_budget_current_amount()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

-- Déclencheurs pour les transactions budgétaires
CREATE TRIGGER after_budget_transaction_changes
AFTER INSERT OR UPDATE OR DELETE ON public.budget_transactions
FOR EACH ROW EXECUTE FUNCTION public.update_budget_current_amount();

-- Fonction pour mettre à jour le budget alloué du projet lors d'ajout/modification/suppression d'allocation
CREATE OR REPLACE FUNCTION public.update_project_budget_allocation()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

-- Déclencheurs pour les allocations budgétaires
CREATE TRIGGER after_budget_allocation_changes
AFTER INSERT OR UPDATE OR DELETE ON public.budget_allocations
FOR EACH ROW EXECUTE FUNCTION public.update_project_budget_allocation();
