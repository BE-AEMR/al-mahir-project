-- Table principale des catégories de transaction
CREATE TABLE transaction_categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  transaction_type TEXT NOT NULL, -- 'income' ou 'expense'
  description TEXT,
  icon TEXT, -- Optionnel: stockage du nom d'icône
  color TEXT, -- Optionnel: stockage de la couleur en format HEX
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table des sous-catégories
CREATE TABLE transaction_subcategories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id UUID NOT NULL REFERENCES transaction_categories(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Modification de la table budget_transactions existante pour ajouter les références
ALTER TABLE budget_transactions 
ADD COLUMN category_id UUID REFERENCES transaction_categories(id) ON DELETE SET NULL,
ADD COLUMN subcategory_id UUID REFERENCES transaction_subcategories(id) ON DELETE SET NULL;

-- Indexes pour améliorer les performances
CREATE INDEX idx_transaction_categories_type ON transaction_categories(transaction_type);
CREATE INDEX idx_transaction_subcategories_category ON transaction_subcategories(category_id);
CREATE INDEX idx_budget_transactions_category_id ON budget_transactions(category_id);
CREATE INDEX idx_budget_transactions_subcategory_id ON budget_transactions(subcategory_id);

-- Trigger pour mettre à jour la date de modification
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_transaction_categories_timestamp
BEFORE UPDATE ON transaction_categories
FOR EACH ROW
EXECUTE PROCEDURE update_updated_at();

CREATE TRIGGER update_transaction_subcategories_timestamp
BEFORE UPDATE ON transaction_subcategories
FOR EACH ROW
EXECUTE PROCEDURE update_updated_at();

-- Politiques RLS pour transaction_categories
ALTER TABLE transaction_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Tout le monde peut voir les catégories" 
ON transaction_categories FOR SELECT USING (true);

CREATE POLICY "Seuls les utilisateurs authentifiés peuvent ajouter des catégories" 
ON transaction_categories FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Seuls les utilisateurs authentifiés peuvent modifier des catégories" 
ON transaction_categories FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Seuls les utilisateurs authentifiés peuvent supprimer des catégories" 
ON transaction_categories FOR DELETE USING (auth.role() = 'authenticated');

-- Politiques RLS pour transaction_subcategories
ALTER TABLE transaction_subcategories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Tout le monde peut voir les sous-catégories" 
ON transaction_subcategories FOR SELECT USING (true);

CREATE POLICY "Seuls les utilisateurs authentifiés peuvent ajouter des sous-catégories" 
ON transaction_subcategories FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Seuls les utilisateurs authentifiés peuvent modifier des sous-catégories" 
ON transaction_subcategories FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Seuls les utilisateurs authentifiés peuvent supprimer des sous-catégories" 
ON transaction_subcategories FOR DELETE USING (auth.role() = 'authenticated');
