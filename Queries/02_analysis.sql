-- =====================================================================
-- 02_ANALYSIS: Olist E-Commerce SQL Analysis
-- Database: olist_project | Tool: MySQL Workbench
-- Setup and data cleaning steps are in 01_setup_and_cleaning.sql
-- =====================================================================
USE olist_project;

-- ANALYSIS RULES (used in every query unless stated)
-- 1. Period: 2017-01-01 to 2018-08-31 (2016 and late 2018 data are sparse)
-- 2. Revenue = SUM(order_items.price) on delivered orders only (freight excluded)
-- 3. Real customers are identified by customer_unique_id, not customer_id
-- 4. Reviews: order_reviews_clean, averaged per order first
--    (some orders have more than one review)

-- =====================================
-- SECTION 1: DATA CHECKS
-- =====================================
-- Q1: Which orders have no items, if any? (orders + order_items)
-- APPROACH: every order should have at least one row in order_items. Use a LEFT JOIN from
-- orders to order_items (orders on the left, because orders is the table I am checking),
-- then keep only the rows where the order_items side came back empty (IS NULL).
-- Then group those orders by status to see what kind of orders they are.
-- This is a data check on the whole orders table, so there is no date or status filter.

-- Part 1: how many orders have no items?
SELECT COUNT(*) AS orders_without_items
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;

-- Part 2: what statuses do those orders have?
SELECT o.order_status,
       COUNT(*) AS orders_without_items,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY orders_without_items DESC;

-- EXPLANATION:
-- A LEFT JOIN keeps every row from the left table (orders), even when there is no match on
-- the right. When there is no match, every column from order_items comes back as NULL.
-- WHERE oi.order_id IS NULL then keeps only those unmatched orders. This is an anti-join,
-- the same pattern used in 01_setup_and_cleaning.sql to find the 611 missing products.
-- The table order matters: if order_items were on the left, I would be finding items with
-- no order instead, which is a different question.
-- Part 2 groups the unmatched orders by status, and SUM(COUNT(*)) OVER () turns each
-- count into a percentage of all the unmatched orders.

-- Cross-check: number of orders that do have items
SELECT COUNT(DISTINCT order_id) FROM order_items;

-- RESULT: 775 orders (0.8% of 99,441) have no items.
-- By status: unavailable 603 (77.8%) | canceled 164 (21.2%) | created 5 (0.6%) |
--            invoiced 2 (0.3%) | shipped 1 (0.1%)
-- Cross-check: 99,441 total orders - 98,666 orders with items = 775 ✓

-- INSIGHT: Only 0.8% of orders (775 of 99,441) have no items, and 99.0% of those are
-- unavailable or canceled orders that never turned into a sale. Almost every unavailable
-- order has no items (603 of 609, about 99%), which suggests that "unavailable" means the
-- item could not be supplied. Canceled orders are different: only 164 of 625 (26%) lack
-- items, so most canceled orders do have items. No delivered order is affected, so the
-- item-level revenue figures are not understated.
-- Data quality note: 1 shipped order and 2 invoiced orders have no items. A shipped order
-- with nothing in it looks like a recording error, but there are too few to change any result.
-- Recommendation: look into why items are unavailable when the order is placed, since those
-- orders are lost sales (possible causes are stock-outs or sellers listing items they cannot
-- supply).
-- Note: the total orders per status (609 unavailable, 625 canceled) are in Step 9 of
-- 01_setup_and_cleaning.sql.

-- =====================================
-- SECTION 2: SALES GROWTH
-- =====================================

-- Q2: Which orders have no items, if any? (orders + order_items)
-- APPROACH: every order should have at least one row in order_items. Use a LEFT JOIN from
-- orders to order_items (orders on the left, because orders is the table I am checking),
-- then keep only the rows where the order_items side came back empty (IS NULL).
-- Then group those orders by status to see what kind of orders they are.
-- This is a data check on the whole orders table, so there is no date or status filter.

-- Part 1: how many orders have no items?
SELECT COUNT(*) AS orders_without_items
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;

-- Part 2: what statuses do those orders have?
SELECT o.order_status,
       COUNT(*) AS orders_without_items,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY orders_without_items DESC;

-- EXPLANATION:
-- A LEFT JOIN keeps every row from the left table (orders), even when there is no match on
-- the right. When there is no match, every column from order_items comes back as NULL.
-- WHERE oi.order_id IS NULL then keeps only those unmatched orders. This is an anti-join,
-- the same pattern used in 01_setup_and_cleaning.sql to find the 611 missing products.
-- The table order matters: if order_items were on the left, I would be finding items with
-- no order instead, which is a different question.
-- Part 2 groups the unmatched orders by status, and SUM(COUNT(*)) OVER () turns each
-- count into a percentage of all the unmatched orders.

-- Cross-check: number of orders that do have items
SELECT COUNT(DISTINCT order_id) FROM order_items;

-- RESULT: 775 orders (0.8% of 99,441) have no items.
-- By status: unavailable 603 (77.8%) | canceled 164 (21.2%) | created 5 (0.6%) |
--            invoiced 2 (0.3%) | shipped 1 (0.1%)
-- Cross-check: 99,441 total orders - 98,666 orders with items = 775 ✓

-- INSIGHT: Only 0.8% of orders (775 of 99,441) have no items, and 99.0% of those are
-- unavailable or canceled orders that never turned into a sale. Almost every unavailable
-- order has no items (603 of 609, about 99%), which suggests that "unavailable" means the
-- item could not be supplied. Canceled orders are different: only 164 of 625 (26%) lack
-- items, so most canceled orders do have items. No delivered order is affected, so the
-- item-level revenue figures are not understated.
-- Data quality note: 1 shipped order and 2 invoiced orders have no items. A shipped order
-- with nothing in it looks like a recording error, but there are too few to change any result.
-- Recommendation: look into why items are unavailable when the order is placed, since those
-- orders are lost sales (possible causes are stock-outs or sellers listing items they cannot
-- supply).
-- Note: the total orders per status (609 unavailable, 625 canceled) are in Step 9 of
-- 01_setup_and_cleaning.sql.

-- Q3: What is the month-over-month revenue growth? (orders + order_items)
-- APPROACH: first calculate the revenue for each month in a CTE (delivered orders, Jan 2017
-- to Aug 2018). Then use LAG to bring the previous month's revenue onto each row and work out
-- the percentage change.

WITH monthly AS (
  SELECT
    DATE_FORMAT(o.purchase_ts, '%Y-%m') AS month,
    ROUND(SUM(oi.price), 2) AS revenue
  FROM orders o
  JOIN order_items oi ON o.order_id = oi.order_id
  WHERE o.order_status = 'delivered'
    AND o.purchase_ts >= '2017-01-01'
    AND o.purchase_ts <  '2018-09-01'
  GROUP BY DATE_FORMAT(o.purchase_ts, '%Y-%m')
)
SELECT
  month,
  revenue,
  LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
  ROUND((revenue - LAG(revenue) OVER (ORDER BY month))
        / LAG(revenue) OVER (ORDER BY month) * 100, 1) AS mom_growth_pct
FROM monthly
ORDER BY month;

-- EXPLANATION:
-- The CTE (WITH monthly AS) does the grouping first: one row per month with its total revenue,
-- using the same joins and filters as Q2. The final SELECT then works on that small table.
-- LAG(revenue) OVER (ORDER BY month) looks at the previous row in month order and returns its
-- revenue, so each month can be compared with the month before it. ORDER BY inside OVER tells
-- SQL what "previous" means.
-- The first month (2017-01) has no previous month, so LAG returns NULL and the growth is NULL.
-- Growth % = (this month - last month) / last month * 100.
-- A CTE is used because the window function LAG needs the grouped monthly table to exist first.
-- Early 2017 growth rates look very high because the business was starting from a small base.

-- RESULT (revenue, growth vs previous month):
-- 2017-01 111,798 (none) | 2017-02 234,223 (+109.5%) | 2017-03 359,199 (+53.4%) |
-- 2017-04 340,670 (-5.2%) | 2017-05 489,338 (+43.6%) | 2017-06 421,923 (-13.8%) |
-- 2017-07 481,605 (+14.1%) | 2017-08 554,700 (+15.2%) | 2017-09 607,400 (+9.5%) |
-- 2017-10 648,248 (+6.7%) | 2017-11 987,765 (+52.4%) | 2017-12 726,033 (-26.5%) |
-- 2018-01 924,645 (+27.4%) | 2018-02 826,437 (-10.6%) | 2018-03 953,356 (+15.4%) |
-- 2018-04 973,534 (+2.1%) | 2018-05 977,545 (+0.4%) | 2018-06 856,078 (-12.4%) |
-- 2018-07 867,953 (+1.4%) | 2018-08 838,577 (-3.4%)
-- 19 growth values: 13 months grew and 6 shrank.

-- INSIGHT: Revenue grew from 112K in January 2017 to 988K in November 2017, and the growth
-- slowed in stages. In early 2017 the percentages are huge (+109.5% in February, +53.4% in
-- March) because the business was starting from a small base. From July to October 2017,
-- growth settled at a steadier +7% to +15% a month.
-- November 2017 is the biggest jump in money terms (about +340K, or +52.4%) and the highest
-- revenue of the whole period, likely a Black Friday effect. It was followed by the sharpest
-- fall (-26.5% in December). January 2018 then rebounded +27.4%, to a level about 43% above
-- October 2017.
-- After that, growth flattens: from March to August 2018 monthly changes stay between -12.4% and
-- +15.4%, and in April, May and July they are near zero (+2.1%, +0.4%, +1.4%). Revenue peaked
-- at 977,545 in May 2018 and ended August at 838,577, 14.2% below that peak.
-- Monthly revenue in 2018 (about 830K to 980K) is a large step up from 2017, and the 8
-- months of 2018 (7.22M) already bring in more than all of 2017 (5.96M). The business grew
-- fast and then plateaued, so continued growth would likely need a new driver.
-- Note: early-2017 growth rates are inflated by the low starting base, and the data cannot
-- say why 2018 flattened. Delivered orders only, Jan 2017 to Aug 2018.