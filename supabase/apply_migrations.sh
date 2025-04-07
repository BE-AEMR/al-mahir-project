#!/bin/bash

# Exécuter les migrations SQL sur Supabase
# Assurez-vous d'avoir installé et configuré Supabase CLI

# Chemin vers le fichier de migration
MIGRATION_FILE="./migrations/20250305_add_phases.sql"

# Vérifier si le fichier existe
if [ ! -f "$MIGRATION_FILE" ]; then
    echo "Erreur: Le fichier de migration $MIGRATION_FILE n'existe pas."
    exit 1
fi

# Exécuter la migration
echo "Exécution de la migration: $MIGRATION_FILE"
supabase db execute --file "$MIGRATION_FILE"

echo "Migration terminée avec succès."
