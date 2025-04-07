-- Supprimer toutes les politiques existantes pour le bucket task-attachments
DROP POLICY IF EXISTS "Utilisateurs peuvent voir les pièces jointes des projets auxquels ils participent" ON storage.objects;
DROP POLICY IF EXISTS "Utilisateurs peuvent télécharger des pièces jointes pour les projets auxquels ils participent" ON storage.objects;
DROP POLICY IF EXISTS "Utilisateurs peuvent supprimer leurs propres pièces jointes" ON storage.objects;

-- Permettre à tous les utilisateurs authentifiés d'accéder au bucket en lecture
CREATE POLICY "Lecture publique task-attachments" 
ON storage.objects FOR SELECT 
USING (
  bucket_id = 'task-attachments'
);

-- Permettre à tous les utilisateurs authentifiés d'insérer dans le bucket
CREATE POLICY "Écriture bucket task-attachments par utilisateurs authentifiés" 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'task-attachments' AND auth.role() = 'authenticated'
);

-- Permettre à tous les utilisateurs authentifiés de mettre à jour le bucket
CREATE POLICY "Mise à jour bucket task-attachments par utilisateurs authentifiés" 
ON storage.objects FOR UPDATE 
USING (
  bucket_id = 'task-attachments' AND auth.role() = 'authenticated'
);

-- Permettre à tous les utilisateurs authentifiés de supprimer du bucket
-- Dans une véritable application de production, vous voudriez probablement restreindre cette politique
CREATE POLICY "Suppression bucket task-attachments par utilisateurs authentifiés" 
ON storage.objects FOR DELETE
USING (
  bucket_id = 'task-attachments' AND auth.role() = 'authenticated'
);
