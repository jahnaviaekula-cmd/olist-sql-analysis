-- =====================================================================
-- 01_SETUP_AND_CLEANING
-- Record of what was already executed. Do not rerun.
-- Database: olist_project | Tool: MySQL Workbench
-- =====================================================================


-- ---------------------------------------------------------------------
-- STEP 1: CREATE THE DATABASE
-- ---------------------------------------------------------------------
-- CREATE DATABASE olist_project;
-- USE olist_project;

-- Explanation:
-- CREATE DATABASE makes an empty container for all the tables.
-- USE tells MySQL that every query after it should run inside olist_project.
-- Without USE, MySQL would not know which database to read from.


-- ---------------------------------------------------------------------
-- STEP 2: IMPORT THE CSV FILES
-- ---------------------------------------------------------------------
-- (Done with Workbench's Table Data Import Wizard, so there is no SQL here.)

-- Explanation:
-- Each of the 9 CSV files became one table: customers, orders, order_items,
-- order_payments, order_reviews, products, sellers, geolocation and
-- product_category_name_translation.
-- The wizard guesses column types, and it guessed text for most columns,
-- including the dates. The next steps fix that.


-- ---------------------------------------------------------------------
-- STEP 3: CONVERT TEXT DATES TO REAL DATETIME COLUMNS
-- ---------------------------------------------------------------------
-- ALTER TABLE orders
--   ADD COLUMN purchase_ts DATETIME,
--   ADD COLUMN approved_ts DATETIME,
--   ADD COLUMN delivered_carrier_ts DATETIME,
--   ADD COLUMN delivered_customer_ts DATETIME,
--   ADD COLUMN estimated_delivery_ts DATETIME;

-- Explanation:
-- ALTER TABLE ... ADD COLUMN adds new empty columns to the orders table.
-- DATETIME is a proper date-and-time type. Text dates can't be compared,
-- subtracted or grouped by month, but DATETIME values can.

-- UPDATE orders SET
--   purchase_ts = STR_TO_DATE(order_purchase_timestamp, '%Y-%m-%d %H:%i:%s'),
--   approved_ts = STR_TO_DATE(NULLIF(order_approved_at, ''), '%Y-%m-%d %H:%i:%s'),
--   delivered_carrier_ts = STR_TO_DATE(NULLIF(order_delivered_carrier_date, ''), '%Y-%m-%d %H:%i:%s'),
--   delivered_customer_ts = STR_TO_DATE(NULLIF(order_delivered_customer_date, ''), '%Y-%m-%d %H:%i:%s'),
--   estimated_delivery_ts = STR_TO_DATE(NULLIF(order_estimated_delivery_date, ''), '%Y-%m-%d %H:%i:%s');

-- Explanation:
-- UPDATE fills the new columns using the old text columns.
-- STR_TO_DATE reads text like '2017-10-02 10:56:33' and turns it into a real
-- date. The pattern ('%Y-%m-%d %H:%i:%s') tells it where the year, month,
-- day, hour, minute and second sit in the text.
-- NULLIF(column, '') turns a blank value into NULL first. Undelivered orders
-- have blank delivery dates, and STR_TO_DATE would otherwise fail on them.
-- Check: MIN and MAX of purchase_ts gave 2016-09-04 to 2018-10-17, as expected.


-- ---------------------------------------------------------------------
-- STEP 4: PRIMARY KEYS
-- ---------------------------------------------------------------------
-- ALTER TABLE orders MODIFY order_id VARCHAR(32) NOT NULL;
-- ALTER TABLE orders ADD PRIMARY KEY (order_id);
-- ALTER TABLE customers MODIFY customer_id VARCHAR(32) NOT NULL;
-- ALTER TABLE customers ADD PRIMARY KEY (customer_id);
-- ALTER TABLE sellers MODIFY seller_id VARCHAR(32) NOT NULL;
-- ALTER TABLE sellers ADD PRIMARY KEY (seller_id);

-- Explanation:
-- A primary key is a column whose values are unique in every row (one order_id
-- per order, and so on). It prevents duplicates and makes lookups and joins faster.
-- MySQL can't use a TEXT column as a key, so each ID column was first changed
-- to VARCHAR(32), which fits because Olist IDs are 32 characters long.
-- NOT NULL means the column can never be empty.

-- ALTER TABLE order_items MODIFY order_id VARCHAR(32) NOT NULL;
-- ALTER TABLE order_items ADD PRIMARY KEY (order_id, order_item_id);
-- ALTER TABLE order_payments MODIFY order_id VARCHAR(32) NOT NULL;
-- ALTER TABLE order_payments ADD PRIMARY KEY (order_id, payment_sequential);

-- Explanation:
-- These two tables use a composite key (two columns together), because one
-- order can have several items and several payments.
-- order_item_id is just the item's position inside an order (1st, 2nd, 3rd),
-- so it is only unique when paired with order_id.
-- The same idea applies to payment_sequential in order_payments.


-- ---------------------------------------------------------------------
-- STEP 5: FIX THE BROKEN COLUMN NAME IN THE TRANSLATION TABLE
-- ---------------------------------------------------------------------
-- ALTER TABLE product_category_name_translation
--   RENAME COLUMN `ï»¿product_category_name` TO product_category_name;

-- Explanation:
-- The CSV file started with a hidden marker (a BOM), so the first column's
-- name came in as `ï»¿product_category_name`. Joins on product_category_name
-- found nothing because that column name didn't exist.
-- Backticks (`) let MySQL accept a name with special characters.
-- RENAME COLUMN gave it the clean name.


-- ---------------------------------------------------------------------
-- STEP 6: INDEXES (SPEED UP JOINS)
-- ---------------------------------------------------------------------
-- ALTER TABLE order_items MODIFY product_id VARCHAR(32) NOT NULL;
-- CREATE INDEX idx_oi_product ON order_items(product_id);
-- CREATE INDEX idx_prod_cat ON products(product_category_name(50));
-- CREATE INDEX idx_trans_cat ON product_category_name_translation(product_category_name(50));

-- Explanation:
-- An index works like the index at the back of a book: MySQL jumps straight
-- to the matching rows instead of scanning the whole table.
-- Before these existed, the category revenue query ran for 30 seconds and
-- failed with Error 2013 (lost connection).
-- The (50) means only the first 50 characters are indexed, which MySQL
-- requires for text columns.


-- ---------------------------------------------------------------------
-- STEP 7: DATA QUALITY ISSUE 1 - PRODUCTS TABLE WAS MISSING 611 ROWS
-- ---------------------------------------------------------------------
-- SELECT COUNT(DISTINCT oi.product_id) AS missing_products,
--        COUNT(*) AS affected_items
-- FROM order_items oi
-- LEFT JOIN products p ON oi.product_id = p.product_id
-- WHERE p.product_id IS NULL;

-- Explanation:
-- This is an anti-join: it finds rows in one table that have no match in another.
-- LEFT JOIN keeps every order item, even ones with no matching product.
-- WHERE p.product_id IS NULL then keeps only those unmatched items.
-- Result: 611 products (used by 1,604 order items) were missing. The products
-- table had 32,340 rows instead of 32,951.
-- Likely cause: the wizard skipped rows with blank numeric fields.

-- RENAME TABLE products TO products_old, products_v2 TO products;
-- ALTER TABLE products MODIFY product_id VARCHAR(32) NOT NULL;
-- ALTER TABLE products ADD PRIMARY KEY (product_id);
-- CREATE INDEX idx_prod_cat ON products(product_category_name(50));

-- Explanation:
-- The CSV was re-imported as products_v2 with every column set to TEXT, which
-- loaded all rows. RENAME TABLE then swapped it in as the live products table
-- and kept the broken one as products_old for safety.
-- Then the key and index were re-added to the new table.
-- Result: 32,951 products, and the anti-join now returns 0.
-- Finding: 610 products have a blank category, stored as empty text and not as
-- NULL. Use TRIM(product_category_name) = '' to find them.


-- ---------------------------------------------------------------------
-- STEP 8: DATA QUALITY ISSUE 2 - ORDER_REVIEWS LOADED ONLY 279 OF 99,224 ROWS
-- ---------------------------------------------------------------------
-- (Fix done outside SQL: in Excel, removed the comment and date columns, kept
--  review_id, order_id and review_score, saved as reviews_clean.csv in UTF-8,
--  then imported it as order_reviews_clean with TEXT columns.)

-- Explanation:
-- Review comments contain line breaks, quotation marks and Portuguese accents,
-- which confused the import wizard, so it stopped early.
-- The comment text isn't needed for the analysis, only the score, so removing
-- those columns was a safe fix.

-- ALTER TABLE order_reviews_clean MODIFY review_score INT;
-- ALTER TABLE order_reviews_clean MODIFY order_id VARCHAR(32);
-- CREATE INDEX idx_rev_order ON order_reviews_clean(order_id);

-- Explanation:
-- review_score was imported as text, so it was converted to INT. Otherwise
-- AVG() and comparisons wouldn't work correctly.
-- order_id was shortened to VARCHAR(32) so it could be indexed, which speeds
-- up joins to the orders table.
-- Result: 99,224 rows. Use order_reviews_clean for every review question.
-- Note: some orders have more than one review, so average the score per order
-- before joining, or the counts will be inflated.


-- ---------------------------------------------------------------------
-- STEP 9: OTHER OBSERVATIONS (NO FIX NEEDED, BUT THEY AFFECT THE ANALYSIS)
-- ---------------------------------------------------------------------
-- * 99,441 orders; 96,478 are delivered (97%).
--   Other statuses: shipped 1,107, canceled 625, unavailable 609,
--   invoiced 314, processing 301, created 5, approved 2.
-- * 8 delivered orders have no delivery date, so they are excluded from
--   delivery-time analysis.
-- * 2016 has very few orders and no November; Sep/Oct 2018 have only 16 and 4.
--   Analysis window: Jan 2017 to Aug 2018.
-- * November 2017 spikes to 7,544 orders, likely Black Friday.
-- * 13 products have a category with no English translation
--   (pc_gamer: 3, portateis_cozinha_e_preparadores_de_alimentos: 10).
--   An inner join to the translation table drops them. A LEFT JOIN with
--   COALESCE keeps them.


-- ---------------------------------------------------------------------
-- ANALYSIS RULES
-- ---------------------------------------------------------------------
-- 1. Period: 2017-01-01 to 2018-08-31
-- 2. Revenue = SUM(order_items.price) on delivered orders only (freight excluded)
-- 3. Repeat customers use customer_unique_id, not customer_id