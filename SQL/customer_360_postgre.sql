WITH customer_statistics AS (
SELECT ct.customerid,
DATE '2022-09-01'-MAX(ct.purchase_date::date) AS recency,
ROUND(COUNT(ct.transaction_id)::numeric/NULLIF(TRUNC(EXTRACT(YEAR FROM AGE(DATE '2022-09-01',cr.created_date))),0),2) AS frequency,
ROUND(SUM(ct.gmv)/NULLIF(TRUNC(EXTRACT(YEAR FROM AGE(DATE '2022-09-01',cr.created_date))),0),2) AS monetary,
TRUNC(EXTRACT(YEAR FROM AGE(DATE '2022-09-01',cr.created_date))) AS contract_age_years
FROM customer_transaction ct
JOIN customer_registered cr ON ct.customerid=cr.id
WHERE ct.purchase_date IS NOT NULL AND cr.created_date IS NOT NULL
GROUP BY ct.customerid,cr.created_date),
customer_rn AS (
SELECT cs.*,ROW_NUMBER() OVER(ORDER BY cs.recency DESC) rn_recency,
ROW_NUMBER() OVER(ORDER BY cs.frequency ASC) rn_frequency,
ROW_NUMBER() OVER(ORDER BY cs.monetary ASC) rn_monetary
FROM customer_statistics cs),
customer_rfm AS (
SELECT customerid,recency,frequency,monetary,
CASE
WHEN recency>=MIN(recency) AND recency<(SELECT recency FROM customer_rn WHERE rn_recency=(SELECT ROUND(MAX(rn_recency)*0.25) FROM customer_rn)) THEN '4'
WHEN recency>=(SELECT recency FROM customer_rn WHERE rn_recency=(SELECT ROUND(MAX(rn_recency)*0.25) FROM customer_rn)) AND recency<(SELECT recency FROM customer_rn WHERE rn_recency=(SELECT ROUND(MAX(rn_recency)*0.5) FROM customer_rn)) THEN '3'
WHEN recency>=(SELECT recency FROM customer_rn WHERE rn_recency=(SELECT ROUND(MAX(rn_recency)*0.5) FROM customer_rn)) AND recency<(SELECT recency FROM customer_rn WHERE rn_recency=(SELECT ROUND(MAX(rn_recency)*0.75) FROM customer_rn)) THEN '2'
ELSE '1' END AS r,
CASE
WHEN frequency>=MIN(frequency) AND frequency<(SELECT frequency FROM customer_rn WHERE rn_frequency=(SELECT ROUND(MAX(rn_frequency)*0.25) FROM customer_rn)) THEN '1'
WHEN frequency>=(SELECT frequency FROM customer_rn WHERE rn_frequency=(SELECT ROUND(MAX(rn_frequency)*0.25) FROM customer_rn)) AND frequency<(SELECT frequency FROM customer_rn WHERE rn_frequency=(SELECT ROUND(MAX(rn_frequency)*0.5) FROM customer_rn)) THEN '2'
WHEN frequency>=(SELECT frequency FROM customer_rn WHERE rn_frequency=(SELECT ROUND(MAX(rn_frequency)*0.5) FROM customer_rn)) AND frequency<(SELECT frequency FROM customer_rn WHERE rn_frequency=(SELECT ROUND(MAX(rn_frequency)*0.75) FROM customer_rn)) THEN '3'
ELSE '4' END AS f,
CASE
WHEN monetary>=MIN(monetary) AND monetary<(SELECT monetary FROM customer_rn WHERE rn_monetary=(SELECT ROUND(MAX(rn_monetary)*0.25) FROM customer_rn)) THEN '1'
WHEN monetary>=(SELECT monetary FROM customer_rn WHERE rn_monetary=(SELECT ROUND(MAX(rn_monetary)*0.25) FROM customer_rn)) AND monetary<(SELECT monetary FROM customer_rn WHERE rn_monetary=(SELECT ROUND(MAX(rn_monetary)*0.5) FROM customer_rn)) THEN '2'
WHEN monetary>=(SELECT monetary FROM customer_rn WHERE rn_monetary=(SELECT ROUND(MAX(rn_monetary)*0.5) FROM customer_rn)) AND monetary<(SELECT monetary FROM customer_rn WHERE rn_monetary=(SELECT ROUND(MAX(rn_monetary)*0.75) FROM customer_rn)) THEN '3'
ELSE '4' END AS m
FROM customer_rn
GROUP BY customerid,recency,frequency,monetary)
SELECT * FROM customer_rfm