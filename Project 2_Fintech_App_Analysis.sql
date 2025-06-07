#Data Quality & Edge Cases
#1. Are there any customers with 0 transactions but non-zero LTV?
SELECT customer_id, total_transactions, LTV 
FROM ltv_data ld 
WHERE total_transactions = 0;

#2. List users where Max_Transaction_Value is less than Min_Transaction_Value (data error check).
SELECT customer_id, max_transaction_value, min_transaction_value
FROM ltv_data ld
WHERE max_transaction_value < min_transaction_value;

#3. Identify outlier customers whose Avg_Transaction_Value is more than twice their Max_Transaction_Value.
SELECT customer_id, max_transaction_value, avg_transaction_value
FROM ltv_data ld
WHERE avg_transaction_value > 2 * ld.Max_Transaction_Value;

#4. Find users whose Total_Spent doesn’t equal Total_Transactions * Avg_Transaction_Value (sanity check).
SELECT customer_id, ROUND(total_spent, 1), ROUND(total_transactions*ld.Avg_Transaction_Value, 1) AS calculated_spent
FROM ltv_data ld
WHERE ROUND(total_spent, 1) !=ROUND(total_transactions*ld.Avg_Transaction_Value, 1); 

#5. Check if any customers have missing or NULL values in critical fields (e.g. Customer_ID, LTV).
SELECT *
FROM ltv_data
WHERE customer_id IS NULL
   OR LTV IS NULL;


SELECT * FROM ltv_data LIMIT 10;
#Customer Segmentation & Behavior
#6. What is the average LTV across different income levels?

SELECT income_level, avg(LTV)
FROM ltv_data ld
GROUP BY income_level 

#7. Which age group has the highest average transaction value?
SELECT age_range, AVG(total_spent) AS avg_total_transaction_value 
FROM (
SELECT total_spent,
  CASE
    WHEN age BETWEEN 16 AND 20 THEN '16–20'
    WHEN age BETWEEN 21 AND 40 THEN '21–40'
    WHEN age BETWEEN 41 AND 60 THEN '41–60'
    WHEN age BETWEEN 61 AND 80 THEN '61–80'
    ELSE 'Other'
  END AS age_range
FROM ltv_data ld
WHERE total_spent IS NOT NULL) AS subsquery
GROUP BY age_range
ORDER BY avg_total_transaction_value DESC;

#8. Find the top 10 customers by LTV.
SELECT customer_ID, age, location, income_level, LTV
FROM ltv_data ld 
ORDER BY LTV DESC
LIMIT 10;

#9. Which locations have the highest concentration of high-spending customers (Total_Spent > 1M)?
SELECT location, COUNT(DISTINCT customer_id) AS high_spender_count
FROM ltv_data ld 
WHERE total_spent > 1000000
GROUP BY location
ORDER BY high_spender_count DESC;

#10. Calculate the average issue resolution time grouped by preferred payment method.
SELECT preferred_payment_method, AVG(issue_resolution_time) AS avg_issue_resolution_time
FROM ltv_data ld 
GROUP BY preferred_payment_method;

#Usage Patterns & Retention
#11. What is the average number of active days per customer by app usage frequency (e.g. Monthly, Weekly)?
SELECT app_usage_frequency, AVG(active_days) AS avg_active_days
FROM ltv_data ld 
GROUP BY app_usage_frequency;

#12. How many users haven’t transacted in the last 90 days (Last_Transaction_Days_Ago > 90)?
SELECT COUNT(DISTINCT customer_id) AS infrequent_users
FROM ltv_data ld 
WHERE last_transaction_days_ago >90;

SELECT COUNT(customer_id) AS all_users
FROM ltv_data ld;
## 76% of all users have not transacted in the last 90 days


#13. Segment users into 'High', 'Medium', and 'Low' engagement based on total transactions.
SELECT user_engagement_level, sum(total_transactions) AS sum_total_transactions
FROM (
SELECT total_transactions,
  CASE
    WHEN total_transactions BETWEEN 0 AND 300 THEN 'Low'
    WHEN total_transactions BETWEEN 301 AND 600 THEN 'Medium'
    WHEN total_transactions BETWEEN 601 AND 1000 THEN 'High'
    ELSE 'Other'
  END AS user_engagement_level
FROM ltv_data ld
WHERE total_transactions IS NOT NULL) AS subquery
GROUP BY user_engagement_level
ORDER BY sum_total_transactions DESC;

#14. What percentage of users raised support tickets and how does that correlate with satisfaction scores
# Users who raised tickets and their satisfaction score
SELECT COUNT(DISTINCT customer_id), AVG(customer_satisfaction_score) as avg_customer_satisfaction_score
FROM ltv_data ld 
WHERE ld.Support_Tickets_Raised > 0

# Users who did not raise tickets and their satisfaction score
SELECT COUNT(DISTINCT customer_id), AVG(customer_satisfaction_score) as avg_customer_satisfaction_score
FROM ltv_data ld 
WHERE ld.Support_Tickets_Raised = 0

#Little distinction in terms of avg customer_satisfaction_score between customers who raised support tickets vs those who did not. only a 0.1 difference out of scale of 10.

#Growth & Referral Insights
#15. How many customers came through referrals (Referral_Count > 0) and what is their average LTV?
SELECT COUNT(DISTINCT customer_id) AS customers_through_referrals, AVG(LTV)
FROM ltv_data
WHERE referral_count > 0

#16. Compare LTV between users who received cashback vs. those who did not.
SELECT 
  cashback_status,
  COUNT(DISTINCT customer_id) AS user_count,
  AVG(LTV) AS avg_ltv
FROM (
  SELECT 
    customer_id,
    LTV,
    CASE 
      WHEN cashback_received > 0 THEN 'Received Cashback'
      ELSE 'No Cashback'
    END AS cashback_status
  FROM ltv_data
) AS subquery
GROUP BY cashback_status;

#17. Find the average number of support tickets raised by income level.
SELECT AVG(support_tickets_raised) AS avg_support_tickets_raised, income_level
FROM ltv_data ld 
GROUP BY income_level;

#18. Is there any correlation between transaction volume and app usage frequency?
SELECT AVG(total_transactions) as avg_total_transactions, app_usage_frequency 
FROM ltv_data ld 
GROUP BY app_usage_frequency;


#19. Identify the top 3 preferred payment methods by total spending.
SELECT SUM(total_spent), preferred_payment_method 
FROM ltv_data ld 
GROUP BY preferred_payment_method 
ORDER BY SUM(total_spent) DESC;


