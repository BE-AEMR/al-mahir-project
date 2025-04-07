-- Fonction pour exécuter du SQL dynamique (à utiliser avec précaution)
CREATE OR REPLACE FUNCTION public.execute_sql(sql text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  EXECUTE sql;
END;
$$;

-- Fonction pour vérifier si un utilisateur existe
CREATE OR REPLACE FUNCTION public.check_user_exists(email text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_exists boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM auth.users WHERE email = check_user_exists.email
  ) INTO user_exists;
  
  RETURN user_exists;
END;
$$;
