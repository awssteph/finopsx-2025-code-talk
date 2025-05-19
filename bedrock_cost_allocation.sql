WITH bedrock_usage AS (
	SELECT line_item_usage_type,
		product_product_name,
		CASE
			WHEN line_item_usage_type LIKE '%input-tokens%' THEN 'Input'
			WHEN line_item_usage_type LIKE '%output-tokens%' THEN 'Output' ELSE 'Other'
		END AS token_type,
		line_item_usage_amount,
		line_item_unblended_cost,
		line_item_resource_id,
		resource_tags_user_dept,
		month,
		SPLIT_PART(line_item_usage_type, '-', 3) AS model_name
	FROM cur
	WHERE line_item_product_code like 'AmazonBedrock'
),
sums as (
	SELECT model_name,
		line_item_resource_id,
		resource_tags_user_dept,
		month,
		SUM(
			CASE
				WHEN token_type = 'Input' THEN line_item_usage_amount ELSE 0
			END
		) AS input_tokens,
		SUM(
			CASE
				WHEN token_type = 'Output' THEN line_item_usage_amount ELSE 0
			END
		) AS output_tokens,
		SUM(line_item_unblended_cost) AS total_cost,
		COUNT(*) AS request_count,
		SUM(line_item_unblended_cost) / NULLIF(COUNT(*), 0) AS cost_per_request
	FROM bedrock_usage
	GROUP BY model_name,
		line_item_resource_id,
		resource_tags_user_dept,
		month
	ORDER BY request_count DESC
)
SELECT line_item_resource_id,
	month,
	SUM(total_cost) AS total_cost
FROM sums
GROUP BY line_item_resource_id,
	month
ORDER BY line_item_resource_id,
	month