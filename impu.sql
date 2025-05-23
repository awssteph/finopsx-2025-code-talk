WITH initiate_uploads as (
	SELECT bill_payer_account_id,
		line_item_usage_account_id,
		DATE_FORMAT((line_item_usage_start_date), '%Y-%m-01') AS month_line_item_usage_start_date,
		line_item_resource_id,
		SUM(CAST(line_item_usage_amount AS double)) AS sum_line_item_usage_amount
	FROM 
    ${table_name}
	WHERE 
    ${date_filter} 
		AND line_item_product_code = 'AmazonS3'
		AND line_item_line_item_type in (
			'DiscountedUsage',
			'Usage',
			'SavingsPlanCoveredUsage'
		)
		AND product_product_family != 'Data Transfer'
		AND line_item_operation = 'InitiateMultipartUpload'
	GROUP BY bill_payer_account_id,
		line_item_usage_account_id,
		DATE_FORMAT((line_item_usage_start_date), '%Y-%m-01'),
		line_item_resource_id
),
complete_uploads as (
	SELECT bill_payer_account_id,
		line_item_usage_account_id,
		DATE_FORMAT((line_item_usage_start_date), '%Y-%m-01') AS month_line_item_usage_start_date,
		line_item_resource_id,
		SUM(CAST(line_item_usage_amount AS double)) AS sum_line_item_usage_amount
	FROM 
    ${table_name}
	WHERE 
    ${date_filter} 
		AND line_item_product_code = 'AmazonS3'
		AND line_item_line_item_type in (
			'DiscountedUsage',
			'Usage',
			'SavingsPlanCoveredUsage'
		)
		AND product_product_family != 'Data Transfer'
		AND line_item_operation = 'CompleteMultipartUpload'
	GROUP BY bill_payer_account_id,
		line_item_usage_account_id,
		DATE_FORMAT((line_item_usage_start_date), '%Y-%m-01'),
		line_item_resource_id
)
SELECT initiate_uploads.bill_payer_account_id,
	initiate_uploads.line_item_usage_account_id,
	initiate_uploads.month_line_item_usage_start_date,
	initiate_uploads.line_item_resource_id,
	(
		initiate_uploads.sum_line_item_usage_amount - complete_uploads.sum_line_item_usage_amount
	) AS mpu_requests_delta
FROM initiate_uploads
	JOIN complete_uploads ON (
		initiate_uploads.bill_payer_account_id = complete_uploads.bill_payer_account_id
		AND initiate_uploads.line_item_usage_account_id = complete_uploads.line_item_usage_account_id
		AND initiate_uploads.month_line_item_usage_start_date = complete_uploads.month_line_item_usage_start_date
		AND initiate_uploads.line_item_resource_id = complete_uploads.line_item_resource_id
	)
WHERE (initiate_uploads.sum_line_item_usage_amount - complete_uploads.sum_line_item_usage_amount) > 0
ORDER BY mpu_requests_delta DESC;