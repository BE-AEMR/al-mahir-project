# Exécuter les migrations SQL sur Supabase
# Assurez-vous d'avoir installé et configuré Supabase CLI

# Vérifier si le projet est lié à Supabase
Write-Host "Vérification de la configuration Supabase..."
$configExists = Test-Path "supabase\config.toml"
if (-not $configExists) {
    Write-Error "Erreur: Fichier de configuration Supabase non trouvé. Exécutez 'supabase init' et 'supabase link --project-ref votre-ref-projet' d'abord."
    exit 1
}

# Exécuter la migration
Write-Host "Exécution des migrations..."
supabase db push

Write-Host "Migration terminée avec succès."
