WITH base_items AS(
	SELECT
		oi.order_item_id,
		oi.order_id,
		oi.product_id,
		DATE(oi.created_at) AS order_date,
		oi.price_usd AS item_revenue,
		oi.cogs_usd AS item_cost
	FROM order_items oi
),

refunds AS (
	SELECT
		order_item_id,
		SUM(refund_amount_usd) AS refund_amount
	FROM order_item_refunds
	GROUP BY order_item_id
),

final_items AS (
    SELECT
        b.order_item_id,
        b.order_id,
        b.product_id,
        b.order_date,
        b.item_revenue,
        COALESCE(r.refund_amount, 0) AS refund_amount,
        b.item_cost,
        (b.item_revenue - COALESCE(r.refund_amount, 0)) AS net_revenue,
        (b.item_revenue - COALESCE(r.refund_amount, 0) - b.item_cost) AS profit
    FROM base_items b
    LEFT JOIN refunds r
        ON b.order_item_id = r.order_item_id
),

monthly_summary AS(
	SELECT
		p.product_name,
		DATE(DATE_TRUNC('month', f.order_date)) AS month,
		SUM(f.net_revenue) AS net_revenue,
		SUM(f.profit) AS total_profit,
		ROUND(SUM(f.profit)/NULLIF(SUM(f.net_revenue),0),3) AS monthly_profit_margin
	FROM final_items f
	JOIN products p
		ON f.product_id = p.product_id
	GROUP BY p.product_name, DATE_TRUNC('month',f.order_date)
)

SELECT
	month,
	product_name,
	net_revenue,
	total_profit,
	monthly_profit_margin,
	RANK() OVER (PARTITION BY month ORDER BY total_profit DESC) AS rank_by_profit
FROM monthly_summary
ORDER BY month, rank_by_profit;