-- Marketing funnel drop-off / new user acquisition
-- GA4 sample ecommerce dataset (Google's public BigQuery dataset,
-- real data from the Google Merchandise Store, Nov 2020 - Jan 2021)
--
-- no real "signup" event in this data, so using first_visit instead -
-- checked that in query 1 first, not just assuming it
--
-- keeping the SQL to simple counts, doing rates and % changes in excel


-- 1. what events do we actually have here
-- no signup event, so need to see what's available before picking a substitute
SELECT
  event_name,
  COUNT(*) AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS unique_users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20201107'
GROUP BY event_name
ORDER BY event_count DESC;


-- 2. new users per day, full Nov-Jan range
-- this is where I found the drop, trend line + 7 day avg done in excel
SELECT
  event_date,
  COUNT(DISTINCT IF(event_name = 'first_visit', user_pseudo_id, NULL)) AS new_users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY event_date
ORDER BY event_date;


-- 3. peak period (dec 1-14) vs after the drop (dec 18-31)
-- fewer visitors, or same visitors just not converting?
SELECT
  'Dec 1-14 (peak)' AS period,
  COUNT(DISTINCT IF(event_name = 'session_start', user_pseudo_id, NULL)) AS visitors,
  COUNT(DISTINCT IF(event_name = 'first_visit', user_pseudo_id, NULL)) AS new_users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20201214'

UNION ALL

SELECT
  'Dec 18-31 (after drop)' AS period,
  COUNT(DISTINCT IF(event_name = 'session_start', user_pseudo_id, NULL)) AS visitors,
  COUNT(DISTINCT IF(event_name = 'first_visit', user_pseudo_id, NULL)) AS new_users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201218' AND '20201231';
-- left the 15th-17th out of both on purpose, checked the daily numbers
-- and those days were still at peak level, not part of the drop yet


-- 4. same before/after but by traffic source
-- one channel or all of them?
SELECT
  'Dec 1-14 (peak)' AS period,
  traffic_source.source AS source,
  COUNT(DISTINCT IF(event_name = 'first_visit', user_pseudo_id, NULL)) AS new_users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20201214'
GROUP BY source

UNION ALL

SELECT
  'Dec 18-31 (after drop)' AS period,
  traffic_source.source AS source,
  COUNT(DISTINCT IF(event_name = 'first_visit', user_pseudo_id, NULL)) AS new_users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201218' AND '20201231'
GROUP BY source
ORDER BY source, period;


-- 5. daily funnel - viewed, added to cart, checked out, purchased
SELECT
  event_date,
  traffic_source.source AS source,
  COUNT(DISTINCT IF(event_name = 'view_item', user_pseudo_id, NULL)) AS viewed,
  COUNT(DISTINCT IF(event_name = 'add_to_cart', user_pseudo_id, NULL)) AS added_to_cart,
  COUNT(DISTINCT IF(event_name = 'begin_checkout', user_pseudo_id, NULL)) AS checked_out,
  COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)) AS purchased
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20201231'
GROUP BY event_date, source
ORDER BY source, event_date;


-- 6. checkout to purchase, weekly
-- checking if the problem goes beyond just traffic
SELECT
  DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK) AS week_start,
  COUNT(DISTINCT IF(event_name = 'begin_checkout', user_pseudo_id, NULL)) AS checkout_users,
  COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)) AS purchase_users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY week_start
ORDER BY week_start;


-- excel notes:
-- q2 - line chart + 7 day avg, peak was ~dec 13-14
-- q3 - summary table, visitor % change vs new user % change
-- q4 - pivoted by source, added % change per channel
-- q5 - stage rates (view/cart/checkout/purchase) by date
-- q6 - added checkout-to-purchase % + week over week change


-- ------------------------------------------------------------
-- facebook ad campaign data - separate from the GA4 stuff above.
-- no real key to join FB campaign ids to GA4 traffic_source, so
-- these stay as two separate pieces of analysis, not forcing a
-- join that isn't really there (same logic as section 4.1 in the doc)
--
-- funnel here: impressions -> clicks -> conversions -> approved conversions
--
-- setup: download the csv from kaggle (Facebook Ad Campaign dataset),
-- upload as a table locally to match the file name used below
--
-- columns I'm using: campaign_id (916/936/1178), impressions, clicks,
-- spent, total_conversion (enquiries), approved_conversion (actual sales)
--
-- heads up - checked the raw file before trusting it and found 382 of
-- 1,143 rows (33%) missing campaign_id and fb_campaign_id completely.
-- both fields are just blank in the source, which shifts everything
-- after them left by two columns for those rows. excluded below with
-- a WHERE instead of letting a GROUP BY quietly drop them
-- ------------------------------------------------------------


-- 7. campaign performance - impressions, clicks, conversions, spend
SELECT
  campaign_id,
  SUM(impressions) AS impressions,
  SUM(clicks) AS clicks,
  SUM(total_conversion) AS conversions,
  SUM(approved_conversion) AS approved_conversions,
  SUM(spent) AS spend
FROM `your_project.your_dataset.facebook_ad_campaign`
WHERE campaign_id IN ('916', '936', '1178')
GROUP BY campaign_id
ORDER BY campaign_id;
-- ctr, conversion rate, approval rate, cpc, cost per conversion -
-- all calculated in excel from these totals


-- 8. same funnel by age and gender
-- which audience segment actually converts best, not just which campaign
SELECT
  age,
  gender,
  SUM(impressions) AS impressions,
  SUM(clicks) AS clicks,
  SUM(total_conversion) AS conversions,
  SUM(approved_conversion) AS approved_conversions,
  SUM(spent) AS spend
FROM `your_project.your_dataset.facebook_ad_campaign`
WHERE campaign_id IN ('916', '936', '1178')
GROUP BY age, gender
ORDER BY age, gender;


-- excel notes:
-- q7 - ctr, conversion rate, approval rate, cpc, cost/conversion,
--      cost/approved conversion - bar chart comparing the 3 campaigns
--      on cost per approved conversion since that's the number that
--      actually matters to the business
-- q8 - same rates by age/gender, which segment is most cost efficient