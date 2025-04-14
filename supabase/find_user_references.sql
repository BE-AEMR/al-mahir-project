-- Script pour rechercher toutes les références à l'utilisateur dans la base de données
-- ID utilisateur à rechercher
\set user_id '27c2ee2b-1811-4860-a940-0f1d4fc85c23'

-- Table profiles
SELECT 'profiles' as table_name, id FROM profiles WHERE id = :'user_id';

-- Table user_roles (RBAC)
SELECT 'user_roles' as table_name, id FROM user_roles WHERE user_id = :'user_id';

-- Table team_members
SELECT 'team_members' as table_name, id FROM team_members WHERE user_id = :'user_id';

-- Table tasks (assignation)
SELECT 'tasks' as table_name, id FROM tasks WHERE assigned_to = :'user_id';

-- Table projects (création)
SELECT 'projects' as table_name, id FROM projects WHERE created_by = :'user_id';

-- Table comments
SELECT 'comments' as table_name, id FROM comments WHERE user_id = :'user_id';

-- Table notifications
SELECT 'notifications' as table_name, id FROM notifications WHERE user_id = :'user_id';

-- Table transactions
SELECT 'transactions' as table_name, id FROM transactions WHERE created_by = :'user_id';

-- Table invitations
SELECT 'invitations' as table_name, id FROM invitations WHERE user_id = :'user_id' OR invited_by = :'user_id';

-- Table attachments
SELECT 'attachments' as table_name, id FROM attachments WHERE user_id = :'user_id';

-- Table sessions
SELECT 'auth.sessions' as table_name, id FROM auth.sessions WHERE user_id = :'user_id';

-- Table users (authentification)
SELECT 'auth.users' as table_name, id FROM auth.users WHERE id = :'user_id';
