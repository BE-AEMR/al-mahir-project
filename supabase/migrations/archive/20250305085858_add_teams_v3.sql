
-- Vérification de l'existence des tables avant création
DO $$
DECLARE
    team_members_exists BOOLEAN;
BEGIN
    -- Vérifier si la table team_members existe déjà
    SELECT EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'team_members'
    ) INTO team_members_exists;

    -- Vérifier si la table teams existe déjà
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'teams') THEN
        -- Création de la table des équipes
        CREATE TABLE teams (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          name TEXT NOT NULL,
          description TEXT,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
          updated_at TIMESTAMPTZ
        );

        -- Politiques RLS pour la table teams
        ALTER TABLE teams ENABLE ROW LEVEL SECURITY;

        -- Créer les politiques seulement si team_members existe déjà
        IF team_members_exists THEN
            CREATE POLICY "teams_select_policy" 
            ON teams FOR SELECT 
            USING (
              id IN (
                SELECT team_id FROM team_members WHERE user_id = auth.uid() AND status = 'active'
              )
            );

            CREATE POLICY "teams_update_policy" 
            ON teams FOR UPDATE 
            USING (
              id IN (
                SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
              )
            );

            CREATE POLICY "teams_delete_policy" 
            ON teams FOR DELETE 
            USING (
              id IN (
                SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
              )
            );
        END IF;

        -- Cette politique ne dépend pas de team_members
        CREATE POLICY "teams_insert_policy" 
        ON teams FOR INSERT 
        WITH CHECK (created_by = auth.uid());
    END IF;

    -- Vérifier si la table team_members existe déjà
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'team_members') THEN
        -- Création de la table des membres d'équipe
        CREATE TABLE team_members (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
          user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
          role TEXT NOT NULL CHECK (role IN ('admin', 'member', 'guest')),
          joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          invited_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
          status TEXT NOT NULL CHECK (status IN ('invited', 'active', 'inactive')) DEFAULT 'invited',
          UNIQUE(team_id, user_id)
        );

        -- Politiques RLS pour la table team_members
        ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;

        CREATE POLICY "team_members_select_policy" 
        ON team_members FOR SELECT 
        USING (
          team_id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND status = 'active'
          )
        );

        CREATE POLICY "team_members_insert_policy" 
        ON team_members FOR INSERT 
        WITH CHECK (
          team_id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
          )
        );

        CREATE POLICY "team_members_update_policy" 
        ON team_members FOR UPDATE 
        USING (
          team_id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
          )
        );

        CREATE POLICY "team_members_update_own_policy" 
        ON team_members FOR UPDATE 
        USING (user_id = auth.uid());

        CREATE POLICY "team_members_delete_policy" 
        ON team_members FOR DELETE 
        USING (
          team_id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
          )
        );
    END IF;

    -- Ajouter les politiques manquantes pour teams si team_members existe maintenant
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'teams') 
       AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'team_members')
       AND NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'teams' AND policyname = 'teams_select_policy') THEN
        
        CREATE POLICY "teams_select_policy" 
        ON teams FOR SELECT 
        USING (
          id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND status = 'active'
          )
        );

        CREATE POLICY "teams_update_policy" 
        ON teams FOR UPDATE 
        USING (
          id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
          )
        );

        CREATE POLICY "teams_delete_policy" 
        ON teams FOR DELETE 
        USING (
          id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
          )
        );
    END IF;

    -- Vérifier si la table team_projects existe déjà
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'team_projects') THEN
        -- Création de la table des projets d'équipe
        CREATE TABLE team_projects (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
          project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          UNIQUE(team_id, project_id)
        );

        -- Politiques RLS pour la table team_projects
        ALTER TABLE team_projects ENABLE ROW LEVEL SECURITY;

        CREATE POLICY "team_projects_select_policy" 
        ON team_projects FOR SELECT 
        USING (
          team_id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND status = 'active'
          )
        );

        CREATE POLICY "team_projects_insert_policy" 
        ON team_projects FOR INSERT 
        WITH CHECK (
          team_id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
          )
        );

        CREATE POLICY "team_projects_delete_policy" 
        ON team_projects FOR DELETE 
        USING (
          team_id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
          )
        );
    END IF;

    -- Vérifier si la table invitations existe déjà
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'invitations') THEN
        -- Création de la table des invitations
        CREATE TABLE invitations (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          email TEXT NOT NULL,
          team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
          invited_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
          token TEXT NOT NULL UNIQUE,
          status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')) DEFAULT 'pending'
        );

        -- Politiques RLS pour la table invitations
        ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;

        CREATE POLICY "invitations_select_sent_policy" 
        ON invitations FOR SELECT 
        USING (invited_by = auth.uid());

        CREATE POLICY "invitations_select_received_policy" 
        ON invitations FOR SELECT 
        USING (email = (SELECT email FROM auth.users WHERE id = auth.uid()));

        CREATE POLICY "invitations_insert_policy" 
        ON invitations FOR INSERT 
        WITH CHECK (
          team_id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
          )
        );

        CREATE POLICY "invitations_update_received_policy" 
        ON invitations FOR UPDATE 
        USING (email = (SELECT email FROM auth.users WHERE id = auth.uid()));

        CREATE POLICY "invitations_update_sent_policy" 
        ON invitations FOR UPDATE 
        USING (
          invited_by = auth.uid() AND 
          team_id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
          )
        );

        CREATE POLICY "invitations_delete_policy" 
        ON invitations FOR DELETE 
        USING (
          team_id IN (
            SELECT team_id FROM team_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
          )
        );
    END IF;

    -- Vérifier si la colonne team_id existe dans la table tasks
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'tasks' 
        AND column_name = 'team_id'
    ) THEN
        -- Ajout de la colonne team_id à la table des tâches
        ALTER TABLE tasks ADD COLUMN team_id UUID REFERENCES teams(id) ON DELETE SET NULL;
    END IF;
END
$$;