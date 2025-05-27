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
		line_item_product_code like '%Bedrock%'or product [ 'product_name' ] like '%Bedrock%')  -- example p_n = 'Claude 3 Haiku (Amazon Bedrock Edition)'
	 
	 AND (line_item_usage_type like '%token%' or line_item_usage_type LIKE '%Token%') --not with the S because  Marketplace 'USW2-MP:USW2_InputTokenCount-Units' 
--------------------------------

with token_data as (
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
		) -- example p_n = 'Claude 3 Haiku (Amazon Bedrock Edition)'
		AND (
			line_item_usage_type like '%token%'
			or line_item_usage_type LIKE '%Token%'
		) --not with the S because  Marketplace 'USW2-MP:USW2_InputTokenCount-Units' 
		)
	select distinct CASE
			when user_dept is not null then user_dept else 'untagged'
		END as tag,
		month,
		sum(line_item_unblended_cost) over (partition by user_dept, month) as total_cost, 
			sum(line_item_usage_amount) over (partition by user_dept, month) as total_usage
	from token_data
	where month = '05'