SELECT DISTINCT brand FROM product_views
WHERE brand IS NOT NULL;

#USER BEHAVIOR AND FUNNEL ANALYSIS
#How many unique vistors visited the site each day?
SELECT 
  DATE(event_time) AS day,
  COUNT(DISTINCT user_id) AS unique_users
FROM product_views
GROUP BY DATE(event_time)
ORDER BY day;

#What’s the average number of sessions per user?
SELECT COUNT(DISTINCT user_session)/COUNT(DISTINCT user_id)
FROM product_views
WHERE user_id IS NOT NULL AND user_session IS NOT NULL;

#Which users viewed the most products but didn’t purchase?
SELECT user_id , COUNT(*) AS view_count
FROM product_views
WHERE event_type = 'view'
	AND user_id NOT IN  (
    SELECT DISTINCT user_id
    FROM product_views
    WHERE event_type = 'purchase'
  )
  GROUP BY product_views.user_id 
  ORDER BY view_count DESC;

#What is the average session length?
  SELECT AVG(session_duration_seconds)
  FROM (
  SELECT user_session,
    TIMESTAMPDIFF(SECOND, MIN(event_time), MAX(event_time)) AS session_duration_seconds
  FROM product_views
  WHERE user_session IS NOT NULL
  GROUP BY user_session
  ) AS session_durations;
  
#Which product categories have the highest average number of views per user?
SELECT 
  category_code,
  COUNT(user_id) / (SELECT COUNT(DISTINCT user_id) FROM product_views) AS views_per_user
FROM product_views
WHERE event_type = 'view'
  AND category_code IS NOT NULL
  AND category_code != ''
GROUP BY category_code
ORDER BY views_per_user DESC;

#PRODUCT PERFORMANCE
# Which product categories are trending based on view volume?
SELECT category_code, COUNT(event_type='view') AS view_volume
FROM product_views
WHERE category_code IS NOT NULL
  AND category_code != ''
GROUP BY category_code
ORDER BY view_volume DESC;

#Which brands have the highest average view count per product?
SELECT brand,
COUNT(CASE WHEN event_type='view'THEN 1 END) * 1.0/COUNT(DISTINCT product_id) AS average_view_volume_per_product
FROM product_views
WHERE brand IS NOT NULL
GROUP BY brand
  ORDER BY average_view_volume_per_product DESC;

#What is the average price of the top-viewed products?
SELECT 
  product_id,
  COUNT(*) AS view_count,
  AVG(price) AS avg_price
FROM product_views
WHERE event_type = 'view'
GROUP BY product_id
ORDER BY view_count DESC
LIMIT 10;

#Which products are frequently viewed but rarely converted (low conversion rate)?
SELECT 
  views_data.product_id,
  views_data.view_count,
  IFNULL(purchases_data.purchase_count, 0) AS purchase_count,
  IFNULL(purchases_data.purchase_count, 0) / views_data.view_count AS conversion_rate
  FROM (
  SELECT product_id, COUNT(*) AS view_count
  FROM product_views
  WHERE event_type = 'view'
GROUP BY product_id) AS views_data
LEFT JOIN (
SELECT product_id, COUNT(*) AS purchase_count
FROM product_views
WHERE event_type = 'purchase'
GROUP BY product_id)
AS purchases_data
ON views_data.product_id = purchases_data.product_id
ORDER BY conversion_rate ASC;

#Segmentation & Personalization

#Which users have browsed across more than 3 categories?
SELECT user_id , COUNT(DISTINCT category_id) AS unique_category_id
FROM product_views
GROUP BY user_id
HAVING COUNT(DISTINCT category_id) > 3 
ORDER BY unique_category_id DESC;

#Which brands are most popular among high-engagement users (5+ sessions)?
#High engagement users
SELECT user_id, COUNT(DISTINCT user_session) AS user_engagement
FROM product_views
GROUP BY user_id
HAVING  COUNT(DISTINCT user_session) >=5
ORDER BY user_engagement DESC;

#popular brands
WITH high_engagement_users AS (
SELECT user_id, COUNT(DISTINCT user_session) AS user_engagement
FROM product_views pv 
WHERE brand IS NOT NULL
GROUP BY user_id
HAVING COUNT(DISTINCT user_session) >=5
)

SELECT 
  brand, 
  COUNT(*) AS total_engagement
FROM product_views
WHERE user_id IN (SELECT user_id FROM high_engagement_users)
  AND brand IS NOT NULL
GROUP BY brand
ORDER BY total_engagement DESC
LIMIT 10;

#What percentage of users are repeat visitors (multiple sessions)?

# repeat visitors
WITH repeat_users AS (
SELECT user_id
FROM product_views
GROUP BY user_id
HAVING COUNT(DISTINCT user_session) > 1 
),
all_users AS (
SELECT COUNT(DISTINCT user_id) AS total_users
FROM product_views
)
SELECT 
  COUNT(*) * 100.0 / (SELECT total_users FROM all_users) AS repeat_user_percentage
FROM repeat_users;

#Which types of users (e.g., high spenders vs low spenders) prefer which product categories?

# Top performing categories
SELECT category_code, sum(price)/count(distinct user_id) as avg_total_spent_per_user
FROM product_views
WHERE event_type = 'purchase' 
GROUP BY category_code
ORDER BY avg_total_spent_per_user DESC

#What top 20 spenders are spending on
SELECT user_id, category_code, sum(price) as total_spent_per_user
FROM product_views
WHERE event_type = 'purchase' 
GROUP BY user_id, category_code
ORDER BY total_spent_per_user DESC
LIMIT 20;

#What bottom 20 spenders are spending on
SELECT user_id, category_code, sum(price) as total_spent_per_user
FROM product_views
WHERE event_type = 'purchase' AND TRIM(category_code)!= ''
GROUP BY user_id, category_code
ORDER BY total_spent_per_user ASC
LIMIT 20;

# Pricing & Revenue Signals
#Is there a correlation between product price and number of views?
SELECT product_id, AVG(price), COUNT(event_type) as no_of_views
FROM product_views pv 
WHERE event_type ='view'
GROUP BY product_id
ORDER BY no_of_views DESC;

#Pearson correlation- not strong
SELECT 
  (
    COUNT(*) * SUM(avg_price * view_count) - SUM(avg_price) * SUM(view_count)
  ) / (
    SQRT(COUNT(*) * SUM(POW(avg_price, 2)) - POW(SUM(avg_price), 2)) * 
    SQRT(COUNT(*) * SUM(POW(view_count, 2)) - POW(SUM(view_count), 2))
  ) AS correlation_coefficient
FROM (
  SELECT 
    product_id, 
    AVG(price) AS avg_price, 
    COUNT(*) AS view_count
  FROM product_views
  WHERE event_type = 'view'
  GROUP BY product_id
) AS product_stats;

# Which price range brackets (e.g., $0–$100, $100–$500) generate the most purchases?
SELECT
  CASE
    WHEN price BETWEEN 0 AND 100 THEN '$0–$100'
    WHEN price BETWEEN 101 AND 500 THEN '$101–$500'
    WHEN price BETWEEN 501 AND 1000 THEN '$501–$1000'
    WHEN price BETWEEN 1001 AND 5000 THEN '$1001–$5000'
    ELSE 'Over $5000'
  END AS price_range,
  COUNT(*) AS purchase_count
FROM product_views
WHERE event_type = 'purchase'
  AND price IS NOT NULL
GROUP BY price_range
ORDER BY purchase_count DESC;

#Which categories or brands are most commonly viewed together in the same session?
#a. Categories commonly viewed together in the same session
SELECT category_code, COUNT(DISTINCT user_session) AS same_session, COUNT(event_type) AS product_views
FROM product_views pv
WHERE event_type = 'view'
GROUP BY category_code

#Unique pairs of categories per session
SELECT
  pv1.category_code AS category_a,
  pv2.category_code AS category_b,
  pv1.user_session
FROM
  product_views pv1
JOIN
  product_views pv2
  ON pv1.user_session = pv2.user_session
WHERE
  pv1.event_type = 'view'
  AND pv2.event_type = 'view'
  AND pv1.category_code < pv2.category_code
  AND pv1.category_code IS NOT NULL
  AND pv2.category_code IS NOT NULL;

SELECT
  pv1.category_code AS category_a,
  pv2.category_code AS category_b,
  COUNT(DISTINCT pv1.user_session) AS co_view_count
FROM
  product_views pv1
JOIN
  product_views pv2
  ON pv1.user_session = pv2.user_session
WHERE
  pv1.event_type = 'view'
  AND pv2.event_type = 'view'
  AND pv1.category_code IS NOT NULL
  AND pv2.category_code IS NOT NULL
  AND TRIM(pv1.category_code) != ''
  AND TRIM(pv2.category_code) != ''
  AND pv1.category_code < pv2.category_code
GROUP BY
  pv1.category_code,
  pv2.category_code
ORDER BY
  co_view_count DESC
LIMIT 10;

#b. Products categories purchased together in the same session
SELECT category_code, COUNT(DISTINCT user_session) AS same_session, COUNT(event_type) AS product_purchase
FROM product_views pv
WHERE event_type = 'purchase'
GROUP BY category_code

SELECT
  pv1.category_code AS category_a,
  pv2.category_code AS category_b,
  COUNT(DISTINCT pv1.user_session) AS co_purchase_count
FROM
  product_views pv1
JOIN
  product_views pv2
  ON pv1.user_session = pv2.user_session
WHERE
  pv1.event_type = 'purchase'
  AND pv2.event_type = 'purchase'
  AND pv1.category_code IS NOT NULL
  AND pv2.category_code IS NOT NULL
  AND TRIM(pv1.category_code) != ''
  AND TRIM(pv2.category_code) != ''
  AND pv1.category_code < pv2.category_code
GROUP BY
  pv1.category_code,
  pv2.category_code
ORDER BY
  co_purchase_count DESC
LIMIT 20; 
