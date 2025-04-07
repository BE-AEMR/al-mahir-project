-- Configuration des politiques RLS pour le bucket de stockage des pièces jointes
-- Supprimer les politiques existantes pour le bucket task-attachments
DROP POLICY IF EXISTS "Utilisateurs peuvent voir les pièces jointes des projets auxquels ils participent" ON storage.objects;
DROP POLICY IF EXISTS "Utilisateurs peuvent télécharger des pièces jointes pour les projets auxquels ils participent" ON storage.objects;
DROP POLICY IF EXISTS "Utilisateurs peuvent supprimer leurs propres pièces jointes" ON storage.objects;

-- Politique pour permettre aux utilisateurs de voir les pièces jointes
CREATE POLICY "Utilisateurs peuvent voir les pièces jointes des projets auxquels ils participent" 
ON storage.objects FOR SELECT
USING (
  -- L'utilisateur peut voir toutes les pièces jointes
  (bucket_id = 'task-attachments')
);

-- Politique pour permettre aux utilisateurs de télécharger des pièces jointes
CREATE POLICY "Utilisateurs peuvent télécharger des pièces jointes pour les projets auxquels ils participent" 
ON storage.objects FOR INSERT 
WITH CHECK (
  -- L'utilisateur peut télécharger dans le bucket task-attachments
  (bucket_id = 'task-attachments' AND auth.uid() = (storage.foldername(name))[3]::uuid)
);

-- Politique pour permettre aux utilisateurs de supprimer leurs propres pièces jointes
CREATE POLICY "Utilisateurs peuvent supprimer leurs propres pièces jointes" 
ON storage.objects FOR DELETE
USING (
  -- L'utilisateur peut supprimer ses propres pièces jointes
  (bucket_id = 'task-attachments' AND auth.uid() = (storage.foldername(name))[3]::uuid)
);
