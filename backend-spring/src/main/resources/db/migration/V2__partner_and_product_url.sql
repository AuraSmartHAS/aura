-- O Aura deixa de encenar a entrega e passa a entregar a demanda a um parceiro.
-- Dois campos no catálogo bastam: quem vende e para onde a família vai depois de aprovar.
--
-- Nulo é um valor legítimo nos dois: item sem parceiro cadastrado não pode ter a interface
-- prometendo um link que não existe. Por isso nenhuma das colunas é NOT NULL.

ALTER TABLE products ADD COLUMN partner varchar(255);
ALTER TABLE products ADD COLUMN product_url varchar(500);

CREATE INDEX idx_products_partner ON products (partner);
