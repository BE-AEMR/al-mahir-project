-- Script pour remplir les tables de catégories et sous-catégories pour un projet de centre éducatif islamique

-----------------------------------------
-- CATÉGORIES DE REVENUS (INCOME)
-----------------------------------------

-- Dons (principale source de revenus)
INSERT INTO transaction_categories (name, transaction_type, description, icon, color, created_at, updated_at)
VALUES 
('Dons', 'income', 'Contributions financières des donateurs', 'e578', '#4CAF50', NOW(), NOW());

-- Récupérer l'ID de la catégorie Dons pour les sous-catégories
DO $$
DECLARE 
    dons_id UUID;
BEGIN
    SELECT id INTO dons_id FROM transaction_categories WHERE name = 'Dons' AND transaction_type = 'income';
    
    -- Sous-catégories pour les dons
    INSERT INTO transaction_subcategories (category_id, name, description, created_at, updated_at) VALUES
    (dons_id, 'Dons individuels', 'Dons des particuliers', NOW(), NOW()),
    (dons_id, 'Dons d''entreprises', 'Contributions financières d''entreprises', NOW(), NOW()),
    (dons_id, 'Dons en ligne', 'Contributions via plateformes digitales', NOW(), NOW()),
    (dons_id, 'Campagnes de collecte', 'Événements spécifiques de collecte de fonds', NOW(), NOW()),
    (dons_id, 'Dons matériels', 'Dons de matériaux de construction ou équipements', NOW(), NOW()),
    (dons_id, 'Zakât', 'Aumône obligatoire dans l''Islam', NOW(), NOW()),
    (dons_id, 'Sadaqa', 'Aumône volontaire dans l''Islam', NOW(), NOW());
END $$;

-- Subventions
INSERT INTO transaction_categories (name, transaction_type, description, icon, color, created_at, updated_at)
VALUES 
('Subventions', 'income', 'Aides financières d''organismes gouvernementaux ou privés', 'e84f', '#2196F3', NOW(), NOW());

-- Récupérer l'ID de la catégorie Subventions pour les sous-catégories
DO $$
DECLARE 
    subventions_id UUID;
BEGIN
    SELECT id INTO subventions_id FROM transaction_categories WHERE name = 'Subventions' AND transaction_type = 'income';
    
    -- Sous-catégories pour les subventions
    INSERT INTO transaction_subcategories (category_id, name, description, created_at, updated_at) VALUES
    (subventions_id, 'Subventions publiques', 'Financements d''organismes publics', NOW(), NOW()),
    (subventions_id, 'Fondations', 'Aides de fondations privées', NOW(), NOW()),
    (subventions_id, 'Subventions internationales', 'Fonds provenant d''organisations internationales', NOW(), NOW());
END $$;

-- Événements de collecte
INSERT INTO transaction_categories (name, transaction_type, description, icon, color, created_at, updated_at)
VALUES 
('Événements', 'income', 'Recettes générées par des événements', 'e8f9', '#FF9800', NOW(), NOW());

-- Récupérer l'ID de la catégorie Événements pour les sous-catégories
DO $$
DECLARE 
    evenements_id UUID;
BEGIN
    SELECT id INTO evenements_id FROM transaction_categories WHERE name = 'Événements' AND transaction_type = 'income';
    
    -- Sous-catégories pour les événements
    INSERT INTO transaction_subcategories (category_id, name, description, created_at, updated_at) VALUES
    (evenements_id, 'Dîners de charité', 'Recettes des dîners caritatifs', NOW(), NOW()),
    (evenements_id, 'Ventes aux enchères', 'Revenus des enchères caritatives', NOW(), NOW()),
    (evenements_id, 'Festivals', 'Revenus des festivals communautaires', NOW(), NOW()),
    (evenements_id, 'Conférences', 'Recettes des colloques et présentations', NOW(), NOW());
END $$;

-- Autres revenus
INSERT INTO transaction_categories (name, transaction_type, description, icon, color, created_at, updated_at)
VALUES 
('Autres revenus', 'income', 'Sources de revenus diverses', 'e0b0', '#9C27B0', NOW(), NOW());

-- Récupérer l'ID de la catégorie Autres revenus pour les sous-catégories
DO $$
DECLARE 
    autres_revenus_id UUID;
BEGIN
    SELECT id INTO autres_revenus_id FROM transaction_categories WHERE name = 'Autres revenus' AND transaction_type = 'income';
    
    -- Sous-catégories pour les autres revenus
    INSERT INTO transaction_subcategories (category_id, name, description, created_at, updated_at) VALUES
    (autres_revenus_id, 'Intérêts bancaires', 'Intérêts générés sur les comptes bancaires', NOW(), NOW()),
    (autres_revenus_id, 'Vente de publications', 'Revenus de la vente de livres et brochures', NOW(), NOW()),
    (autres_revenus_id, 'Locations d''espaces', 'Revenus de la location temporaire de salles', NOW(), NOW());
END $$;

-----------------------------------------
-- CATÉGORIES DE DÉPENSES (EXPENSE)
-----------------------------------------

-- Construction
INSERT INTO transaction_categories (name, transaction_type, description, icon, color, created_at, updated_at)
VALUES 
('Construction', 'expense', 'Dépenses liées à la construction du bâtiment', 'e3c9', '#F44336', NOW(), NOW());

-- Récupérer l'ID de la catégorie Construction pour les sous-catégories
DO $$
DECLARE 
    construction_id UUID;
BEGIN
    SELECT id INTO construction_id FROM transaction_categories WHERE name = 'Construction' AND transaction_type = 'expense';
    
    -- Sous-catégories pour la construction
    INSERT INTO transaction_subcategories (category_id, name, description, created_at, updated_at) VALUES
    (construction_id, 'Matériaux', 'Achat de matériaux de construction', NOW(), NOW()),
    (construction_id, 'Main d''œuvre', 'Paiement des travaux de construction', NOW(), NOW()),
    (construction_id, 'Plans et permis', 'Frais d''architecture et autorisations', NOW(), NOW()),
    (construction_id, 'Gros œuvre', 'Travaux de structure et fondations', NOW(), NOW()),
    (construction_id, 'Second œuvre', 'Travaux d''aménagement intérieur', NOW(), NOW()),
    (construction_id, 'Toiture', 'Travaux de couverture et charpente', NOW(), NOW()),
    (construction_id, 'Façade', 'Travaux extérieurs et finitions', NOW(), NOW()),
    (construction_id, 'Électricité', 'Installation électrique', NOW(), NOW()),
    (construction_id, 'Plomberie', 'Installation sanitaire et hydraulique', NOW(), NOW()),
    (construction_id, 'Chauffage/Climatisation', 'Systèmes CVC', NOW(), NOW());
END $$;

-- Services professionnels
INSERT INTO transaction_categories (name, transaction_type, description, icon, color, created_at, updated_at)
VALUES 
('Services professionnels', 'expense', 'Honoraires de prestataires', 'e7ef', '#795548', NOW(), NOW());

-- Récupérer l'ID de la catégorie Services professionnels pour les sous-catégories
DO $$
DECLARE 
    services_id UUID;
BEGIN
    SELECT id INTO services_id FROM transaction_categories WHERE name = 'Services professionnels' AND transaction_type = 'expense';
    
    -- Sous-catégories pour les services professionnels
    INSERT INTO transaction_subcategories (category_id, name, description, created_at, updated_at) VALUES
    (services_id, 'Architectes', 'Honoraires d''architectes', NOW(), NOW()),
    (services_id, 'Ingénieurs', 'Honoraires d''ingénieurs', NOW(), NOW()),
    (services_id, 'Avocats', 'Conseils juridiques', NOW(), NOW()),
    (services_id, 'Comptables', 'Services comptables et fiscaux', NOW(), NOW()),
    (services_id, 'Consultants', 'Services de conseil', NOW(), NOW());
END $$;

-- Équipement
INSERT INTO transaction_categories (name, transaction_type, description, icon, color, created_at, updated_at)
VALUES 
('Équipement', 'expense', 'Achat d''équipements et mobilier', 'ea56', '#FF5722', NOW(), NOW());

-- Récupérer l'ID de la catégorie Équipement pour les sous-catégories
DO $$
DECLARE 
    equipement_id UUID;
BEGIN
    SELECT id INTO equipement_id FROM transaction_categories WHERE name = 'Équipement' AND transaction_type = 'expense';
    
    -- Sous-catégories pour l'équipement
    INSERT INTO transaction_subcategories (category_id, name, description, created_at, updated_at) VALUES
    (equipement_id, 'Mobilier', 'Tables, chaises, armoires, etc.', NOW(), NOW()),
    (equipement_id, 'Équipement informatique', 'Ordinateurs, imprimantes, etc.', NOW(), NOW()),
    (equipement_id, 'Équipement audio/vidéo', 'Systèmes de son, vidéoprojecteurs, etc.', NOW(), NOW()),
    (equipement_id, 'Équipement de cuisine', 'Pour la cuisine communautaire', NOW(), NOW()),
    (equipement_id, 'Livres et ressources', 'Matériel éducatif et bibliothèque', NOW(), NOW()),
    (equipement_id, 'Décoration', 'Éléments décoratifs et artistiques', NOW(), NOW());
END $$;

-- Terrain
INSERT INTO transaction_categories (name, transaction_type, description, icon, color, created_at, updated_at)
VALUES 
('Terrain', 'expense', 'Acquisition et aménagement du terrain', 'e1b6', '#8BC34A', NOW(), NOW());

-- Récupérer l'ID de la catégorie Terrain pour les sous-catégories
DO $$
DECLARE 
    terrain_id UUID;
BEGIN
    SELECT id INTO terrain_id FROM transaction_categories WHERE name = 'Terrain' AND transaction_type = 'expense';
    
    -- Sous-catégories pour le terrain
    INSERT INTO transaction_subcategories (category_id, name, description, created_at, updated_at) VALUES
    (terrain_id, 'Achat de terrain', 'Acquisition foncière', NOW(), NOW()),
    (terrain_id, 'Frais notariés', 'Frais juridiques liés à l''achat', NOW(), NOW()),
    (terrain_id, 'Études de sol', 'Analyses géotechniques', NOW(), NOW()),
    (terrain_id, 'Terrassement', 'Préparation du terrain', NOW(), NOW()),
    (terrain_id, 'Aménagements extérieurs', 'Jardins, parking, etc.', NOW(), NOW());
END $$;

-- Administratif
INSERT INTO transaction_categories (name, transaction_type, description, icon, color, created_at, updated_at)
VALUES 
('Administratif', 'expense', 'Frais de fonctionnement et gestion', 'e4c2', '#3F51B5', NOW(), NOW());

-- Récupérer l'ID de la catégorie Administratif pour les sous-catégories
DO $$
DECLARE 
    administratif_id UUID;
BEGIN
    SELECT id INTO administratif_id FROM transaction_categories WHERE name = 'Administratif' AND transaction_type = 'expense';
    
    -- Sous-catégories pour l'administratif
    INSERT INTO transaction_subcategories (category_id, name, description, created_at, updated_at) VALUES
    (administratif_id, 'Assurances', 'Assurance construction et responsabilité civile', NOW(), NOW()),
    (administratif_id, 'Taxes', 'Impôts et taxes diverses', NOW(), NOW()),
    (administratif_id, 'Fournitures de bureau', 'Matériel administratif', NOW(), NOW()),
    (administratif_id, 'Communications', 'Téléphone, internet, site web', NOW(), NOW()),
    (administratif_id, 'Marketing', 'Promotion du projet', NOW(), NOW());
END $$;

-- Frais financiers
INSERT INTO transaction_categories (name, transaction_type, description, icon, color, created_at, updated_at)
VALUES 
('Frais financiers', 'expense', 'Frais bancaires et de financement', 'e337', '#607D8B', NOW(), NOW());

-- Récupérer l'ID de la catégorie Frais financiers pour les sous-catégories
DO $$
DECLARE 
    frais_id UUID;
BEGIN
    SELECT id INTO frais_id FROM transaction_categories WHERE name = 'Frais financiers' AND transaction_type = 'expense';
    
    -- Sous-catégories pour les frais financiers
    INSERT INTO transaction_subcategories (category_id, name, description, created_at, updated_at) VALUES
    (frais_id, 'Frais bancaires', 'Frais de gestion des comptes', NOW(), NOW()),
    (frais_id, 'Intérêts d''emprunt', 'Intérêts sur financement', NOW(), NOW()),
    (frais_id, 'Frais de transfert', 'Commissions sur mouvements internationaux', NOW(), NOW());
END $$;

-- Autres dépenses
INSERT INTO transaction_categories (name, transaction_type, description, icon, color, created_at, updated_at)
VALUES 
('Autres dépenses', 'expense', 'Dépenses diverses', 'e002', '#9E9E9E', NOW(), NOW());

-- Récupérer l'ID de la catégorie Autres dépenses pour les sous-catégories
DO $$
DECLARE 
    autres_depenses_id UUID;
BEGIN
    SELECT id INTO autres_depenses_id FROM transaction_categories WHERE name = 'Autres dépenses' AND transaction_type = 'expense';
    
    -- Sous-catégories pour les autres dépenses
    INSERT INTO transaction_subcategories (category_id, name, description, created_at, updated_at) VALUES
    (autres_depenses_id, 'Imprévus', 'Dépenses non planifiées', NOW(), NOW()),
    (autres_depenses_id, 'Cérémonies', 'Événements spéciaux (pose première pierre, etc.)', NOW(), NOW()),
    (autres_depenses_id, 'Déplacements', 'Frais de transport liés au projet', NOW(), NOW());
END $$;
