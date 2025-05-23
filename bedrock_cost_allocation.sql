SELECT line_item_usage_type,
	line_item_product_code,
	product [ 'product_name' ] as product_name,
	line_item_operation,
	line_item_usage_amount,
	line_item_unblended_cost,
	line_item_resource_id,
	resource_tags [ 'user_dept' ] as user_dept,
	SPLIT(billing_period, '-') [ 2 ] as month
FROM "cid_data_export"."cur2"
Where (
		line_item_product_code like '%Bedrock%'
		or product [ 'product_name' ] like '%Bedrock%'
	)
--------------------------------
with token_data as (
	SELECT line_item_resource_id,
		line_item_usage_type,
		line_item_product_code,
		product [ 'product_name' ] as product_name,
		line_item_operation,
		line_item_usage_amount,
		line_item_unblended_cost,
		CASE
			WHEN line_item_usage_type LIKE '%input-token%' THEN 'Input'
			WHEN line_item_usage_type LIKE '%output-token%' THEN 'Output' ELSE 'Other'
		END AS token_type,
		resource_tags [ 'user_dept' ] as user_dept,
		SPLIT(billing_period, '-') [ 2 ] as month
	FROM "cid_data_export"."cur2"
	Where (
			line_item_product_code like '%Bedrock%'
			or product [ 'product_name' ] like '%Bedrock%'
		)
		AND (line_item_usage_type like '%tokens%')
)
SELECT DISTINCT CASE
		when user_dept is not null then user_dept Else 'untagged'
	end as tag,
	month,
	SUM(line_item_unblended_cost) OVER (PARTITION BY user_dept, month) AS total_cost
FROM token_data
where month = '05'