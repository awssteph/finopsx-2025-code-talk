SELECT 
  product_instance_type,
  regexp_extract(product_instance_type, '^([a-z]+|u\-[0-9]+tb)([0-9]+)([a-z0-9\-]*)(\.)(.+)', 1) as regex_instance_series,
  regexp_extract(product_instance_type, '^([a-z]+|u\-[0-9]+tb)([0-9]+)([a-z0-9\-]*)(\.)(.+)', 2) as regex_instance_generation,
  regexp_extract(product_instance_type, '^([a-z]+|u\-[0-9]+tb)([0-9]+)([a-z0-9\-]*)(\.)(.+)', 3) as regex_instance_options,
  regexp_extract(product_instance_type, '^([a-z]+|u\-[0-9]+tb)([0-9]+)([a-z0-9\-]*)(\.)(.+)', 5) as regex_instance_size,
  SUM(line_item_unblended_cost) AS sum_line_item_unblended_cost
FROM 
  cur2_proxy
WHERE 
  billing_period = '2025-05'
  AND line_item_product_code = 'AmazonEC2'
  AND line_item_operation LIKE '%RunInstances%'
  AND line_item_line_item_type IN ('Usage','SavingsPlanCoveredUsage','DiscountedUsage')
  AND regexp_extract(product_instance_type, '^([a-z]+|u\-[0-9]+tb)([0-9]+)([a-z0-9\-]*)(\.)(.+)', 3) like '%d%'
GROUP BY
  1,2,3,4,5