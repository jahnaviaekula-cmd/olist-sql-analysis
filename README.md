# Olist E-Commerce SQL Analysis

An analysis of about 100,000 Brazilian e-commerce orders (2016-2018) using **MySQL**. It answers 12 business questions on sales growth, products, geography, customers, delivery and sellers, and documents how data quality problems were found and fixed along the way.

**Author:** [Aekula Jahnavi] | [www.linkedin.com/in/aekula-jahnavi] | [https://github.com/jahnaviaekula-cmd]

---

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle). It has 9 related tables: orders, order items, customers, products, sellers, payments, reviews, geolocation and a category translation table. The data is not included in this repository because of its size, so download it from Kaggle.

## Tools

MySQL, MySQL Workbench, Excel (used once to clean the reviews file).

## SQL skills shown

- Multi-table joins (up to 5 tables) and anti-joins (`LEFT JOIN ... IS NULL`)
- CTEs and chained CTEs
- Window functions: `LAG`, `RANK`, `NTILE`, running and percentage-of-total calculations
- `CASE WHEN`, `GROUP BY` / `HAVING`, date functions
- Data quality checks and fixes

---

## Data cleaning and assumptions

The setup steps are recorded in [`queries/01_setup_and_cleaning.sql`](queries/01_setup_and_cleaning.sql). The main points:

- **Dates:** text timestamps were converted to `DATETIME`, and primary keys and indexes were added.
- **Hidden character:** the translation table's first column came in with an invisible marker in its name, which made category joins return nothing. It was renamed.
- **Missing products:** the import wizard dropped 611 rows from `products` (1,604 order items pointed to them). I found this with an anti-join, then re-imported the file with all columns as text. 610 products have a blank category.
- **Missing reviews:** only 279 of 99,224 rows of `order_reviews` loaded because the review comments contain line breaks. I removed the comment columns in Excel and re-imported the file as `order_reviews_clean`. Some orders have more than one review, so scores are averaged per order first.
- **Other observations:** 8 delivered orders have no delivery date, and 13 products have a category with no English translation.

**Analysis rules used in every query** (unless stated):

1. Period: **Jan 2017 to Aug 2018** (2016 and late 2018 are very sparse).
2. Revenue = `SUM(price)` on **delivered orders only**, freight excluded.
3. Real customers are identified by `customer_unique_id`, not `customer_id`.

## Database structure

![ER diagram](images/er_diagram.png)

How the tables connect:

- `orders.customer_id` → `customers.customer_id`
- `order_items.order_id` → `orders.order_id`
- `order_items.product_id` → `products.product_id`
- `order_items.seller_id` → `sellers.seller_id`
- `order_payments.order_id` → `orders.order_id`
- `order_reviews_clean.order_id` → `orders.order_id`
- `products.product_category_name` → `product_category_name_translation.product_category_name`

---

## Business questions and findings

All queries, with explanations and insights, are in [`queries/02_analysis.sql`](queries/02_analysis.sql).

| # | Question | Key finding |
|---|---|---|
| 1 | Which orders have no items? | 775 orders (0.8%), and 99% of them are unavailable or canceled. No delivered order is affected. |
| 2 | Revenue and orders per month | 96,211 orders and 13.18M revenue. November 2017 is the peak month (987,765, about +52% on October). Revenue per order stays at 124-149, so growth came from more orders. |
| 3 | Month-over-month growth | Growth flattened in 2018. Revenue peaked in May 2018 and ended August 14.2% below it. The first 8 months of 2018 (7.22M) already exceed all of 2017 (5.96M). |
| 4 | Top 10 categories by revenue | health_beauty (1.23M), watches_gifts (1.16M) and bed_bath_table (1.02M) lead. The top 10 bring in 62.5% of revenue. |
| 5 | Top 3 categories per year | The same three categories lead both years, but health_beauty moves from 3rd in 2017 to 1st in 2018. |
| 6 | Category share of revenue | No category dominates: the biggest holds 9.5%, and it takes 7 categories to pass 50%. |
| 7 | Revenue by customer state | SP brings in 38.4% of revenue. SP, RJ and MG together bring in 63.4%, and the top 6 states 77.8%. |
| 8 | Repeat customer rate | Only 3.0% of customers (2,789 of 93,104) ordered more than once. |
| 9 | Customer spend tiers | The top third of customers brings in 70.8% of revenue and the bottom third 8.2%. |
| 10 | Late deliveries | 8.1% of delivered orders (7,826 of 96,470) arrived after the estimated date. |
| 11 | Late delivery vs review score | Late orders score 2.57 on average against 4.30 for on-time orders. |
| 12 | Seller scorecard | The 20 biggest sellers bring in 21.3% of revenue and almost all perform well. One large seller is flagged: 22.3 days average delivery and a 3.50 score. |

## Recommendations

1. **Prepare for the November peak.** Plan stock and delivery capacity ahead of Black Friday, and look into the 2018 slowdown in orders.
2. **Invest in retention.** With only 3.0% of customers ordering again, even a small rise in repeat purchases would add orders.
3. **Reduce late deliveries.** Late orders score about 1.7 points lower than on-time ones, so delivery reliability looks like a clear way to raise satisfaction.
4. **Back the growing categories.** health_beauty and watches_gifts are gaining share, while bed_bath_table, the top seller by units, is losing it.
5. **Review the flagged seller** (973 orders, 22.3 days average delivery) to see whether the delay comes from handover or shipping.

**Limitations:** the analysis is descriptive. It shows which things go together (for example late delivery and low scores) but does not prove cause. Revenue uses item price only, and the 2018 figures cover January to August only.

---

## Repository structure

```
olist-sql-analysis/
├── README.md
├── queries/
│   ├── 01_setup_and_cleaning.sql   (setup steps and data quality fixes, as a record)
│   └── 02_analysis.sql             (the 12 analysis queries)
└── images/                         (ER diagram and screenshots)
```

## How to reproduce

1. Download the dataset from Kaggle and import the 9 CSV files into a MySQL database named `olist_project`.
2. Follow the steps in `01_setup_and_cleaning.sql` (date conversion, keys, indexes, and the fixes for the products and reviews tables). The SQL statements in that file are commented out because they were already run when the database was built, so remove the `--` in front of a statement when you want to run it.
3. Run the queries in `02_analysis.sql` against that database.
