-- Script pour rechercher manuellement toutes les références à l'utilisateur dans la base de données
-- ID utilisateur à rechercher
-- Remplacez directement la valeur dans chaque requête

-- Table profiles
SELECT 'profiles' as table_name, id FROM profiles WHERE id = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';

-- Table user_roles (RBAC)
SELECT 'user_roles' as table_name, id FROM user_roles WHERE user_id = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';

-- Table team_members
SELECT 'team_members' as table_name, id FROM team_members WHERE user_id = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';

-- Table tasks (assignation)
SELECT 'tasks' as table_name, id FROM tasks WHERE assigned_to = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';

-- Table projects (création)
SELECT 'projects' as table_name, id FROM projects WHERE created_by = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';

-- Table comments
SELECT 'comments' as table_name, id FROM comments WHERE user_id = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';

-- Table notifications
SELECT 'notifications' as table_name, id FROM notifications WHERE user_id = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';

-- Table transactions
SELECT 'transactions' as table_name, id FROM transactions WHERE created_by = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';

-- Table invitations
SELECT 'invitations' as table_name, id FROM invitations WHERE user_id = '27c2ee2b-1811-4860-a940-0f1d4fc85c23' OR invited_by = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';

-- Table attachments
SELECT 'attachments' as table_name, id FROM attachments WHERE user_id = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';

-- Table sessions
SELECT 'auth.sessions' as table_name, id FROM auth.sessions WHERE user_id = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';

-- Table users (authentification)
SELECT 'auth.users' as table_name, id FROM auth.users WHERE id = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';

-- Vous pouvez également créer des requêtes DELETE pour chaque table si des références sont trouvées:

-- EXEMPLES DE COMMANDES DELETE (à utiliser après avoir vérifié les références):
-- DELETE FROM profiles WHERE id = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';
-- DELETE FROM user_roles WHERE user_id = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';
-- DELETE FROM team_members WHERE user_id = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';
-- DELETE FROM tasks WHERE assigned_to = '27c2ee2b-1811-4860-a940-0f1d4fc85c23';
-- etc.
