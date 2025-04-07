-- Création de la table des notifications
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    is_read BOOLEAN DEFAULT false NOT NULL,
    type TEXT NOT NULL,
    related_id UUID,
    user_id UUID REFERENCES auth.users(id),
    CONSTRAINT notifications_type_check CHECK (
        type IN (
            'projectCreated', 'projectStatusChanged', 'projectBudgetAlert',
            'phaseCreated', 'phaseStatusChanged',
            'taskAssigned', 'taskDueSoon', 'taskOverdue', 'taskStatusChanged',
            'projectInvitation', 'newUser'
        )
    )
);

-- Création d'index pour améliorer les performances
CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS notifications_created_at_idx ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_is_read_idx ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS notifications_related_id_idx ON public.notifications(related_id);

-- Activer RLS (Row Level Security)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Politique pour permettre aux utilisateurs de voir uniquement leurs propres notifications
CREATE POLICY "Les utilisateurs peuvent voir leurs propres notifications" ON public.notifications
    FOR SELECT
    USING (user_id = auth.uid());

-- Politique pour permettre aux utilisateurs de marquer leurs propres notifications comme lues
CREATE POLICY "Les utilisateurs peuvent mettre à jour leurs propres notifications" ON public.notifications
    FOR UPDATE
    USING (user_id = auth.uid());

-- Politique pour permettre aux utilisateurs authentifiés d'insérer des notifications
CREATE POLICY "Les utilisateurs authentifiés peuvent créer des notifications" ON public.notifications
    FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');

-- Politique pour permettre aux administrateurs de supprimer des notifications
CREATE POLICY "Les administrateurs peuvent supprimer des notifications" ON public.notifications
    FOR DELETE
    USING (
        -- Vous pouvez définir ici une condition basée sur un rôle d'administrateur
        -- Par exemple: auth.uid() IN (SELECT user_id FROM public.admins)
        -- Pour l'instant, nous autorisons la suppression par le propriétaire
        user_id = auth.uid()
    );
