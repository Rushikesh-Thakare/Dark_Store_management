-- Three manager reports. Read-only; run each query on its own.

-- Report 1: low-stock items (at or below reorder threshold), most urgent first.
SELECT store_name, product_name, category_name, current_stock, reorder_threshold,
       alert_id IS NOT NULL AS has_open_alert
FROM v_low_stock_inventory
ORDER BY current_stock - reorder_threshold, product_name;

-- Report 2: top 5 best-selling products by units sold (cancelled orders ignored).
-- Revenue uses price_at_purchase, so later price changes do not distort history.
SELECT p.product_name,
       c.category_name,
       SUM(oi.quantity)                          AS units_sold,
       SUM(oi.quantity * oi.price_at_purchase)   AS revenue
FROM order_items oi
JOIN orders o     ON o.order_id    = oi.order_id
JOIN products p   ON p.product_id  = oi.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE o.status <> 'cancelled'
GROUP BY p.product_id, p.product_name, c.category_name
ORDER BY units_sold DESC, revenue DESC
LIMIT 5;

-- Report 3: delivered orders per rider and average minutes from placing to delivery.
-- LEFT JOIN keeps riders who have not delivered anything yet (count 0, average empty).
SELECT r.rider_id,
       r.full_name,
       COUNT(o.order_id) AS delivered_orders,
       ROUND(AVG(EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at)) / 60), 1) AS avg_delivery_minutes
FROM riders r
LEFT JOIN orders o ON o.rider_id = r.rider_id AND o.status = 'delivered'
GROUP BY r.rider_id, r.full_name
ORDER BY delivered_orders DESC, r.full_name;
