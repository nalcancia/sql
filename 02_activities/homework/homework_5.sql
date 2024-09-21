-- Cross Join
/*1. Suppose every vendor in the `vendor_inventory` table had 5 of each of their products to sell to **every** 
customer on record. How much money would each vendor make per product? 
Show this by vendor_name and product name, rather than using the IDs.

HINT: Be sure you select only relevant columns and rows. 
Remember, CROSS JOIN will explode your table rows, so CROSS JOIN should likely be a subquery. 
Think a bit about the row counts: how many distinct vendors, product names are there (x)?
How many customers are there (y). 
Before your final group by you should have the product of those two queries (x*y).  */

SELECT 
	vp.vendor_name, vp.product_name, 
	SUM(vp.sales_per_5_items) AS max_possible_sales
FROM
	(SELECT DISTINCT 
		v.vendor_name, vi.vendor_id, p.product_name,
		vi.product_id, vi.original_price, 
		5 AS defined_qty, 
		5 * vi.original_price AS sales_per_5_items
	FROM 
		vendor_inventory vi, vendor v, product p
	WHERE
		vi.vendor_id = v.vendor_id AND vi.product_id = p.product_id
	) AS vp
CROSS JOIN 
	customer c
GROUP BY vp.vendor_id, vp.vendor_name, vp.product_id, vp.product_name;
-- included product_id and vendor_id in grouping to ensure consistency even if there are duplicate names
-- did not include in result due to my understanding of the requirements, but would personally prefer to.

-- INSERT
/*1.  Create a new table "product_units". 
This table will contain only products where the `product_qty_type = 'unit'`. 
It should use all of the columns from the product table, as well as a new column for the `CURRENT_TIMESTAMP`.  
Name the timestamp column `snapshot_timestamp`. */

DROP TABLE IF EXISTS product_units;

CREATE TABLE IF NOT EXISTS product_units AS
SELECT * FROM product WHERE product_qty_type = 'unit';

ALTER TABLE product_units
ADD COLUMN snapshot_timestamp TIMESTAMP;
UPDATE product_units SET snapshot_timestamp = CURRENT_TIMESTAMP;
-- UPDATE query in place of DEFAULT to initialze value of snapshot_timestamp

/*2. Using `INSERT`, add a new row to the product_units table (with an updated timestamp). 
This can be any product you desire (e.g. add another record for Apple Pie). */

INSERT INTO product_units (product_id, product_name, product_size, 
	product_category_id, product_qty_type, snapshot_timestamp)
VALUES (
	(SELECT MAX(product_id) + 1 FROM product_units),
	'Apple Pie - Slice',
	'1/8 slice',
	3,
	'unit',
	CURRENT_TIMESTAMP
);

-- DELETE
/* 1. Delete the older record for the whatever product you added. 

HINT: If you don't specify a WHERE clause, you are going to have a bad time.*/

-- Deleting an "older" record of the same product I added
-- assumes that I have two of the same product except with different timestamps, 
-- given that the product_id is a primary key we cannot have duplicates based on this column,
-- so I am using product_name to specify the duplicate entry,
-- unless on creation of the table, snapshot_timestamp is also added as a primary key.

-- The query below would delete the oldest record, or if it does not exist, 
-- the only record with the same product name, if multiple older records need to be deleted
-- I would be evaluating using timestamp <= MAX(timestamp)
DELETE FROM product_units 
WHERE 
	(product_name, snapshot_timestamp)
		IN (
			SELECT product_name, MIN(snapshot_timestamp) 
				FROM product_units
			WHERE 
				product_name = 'Apple Pie - Slice'
			GROUP BY product_name
		)
;

-- UPDATE
/* 1.We want to add the current_quantity to the product_units table. 
First, add a new column, current_quantity to the table using the following syntax.

ALTER TABLE product_units
ADD current_quantity INT

Then, using UPDATE, change the current_quantity equal to the last quantity value from the vendor_inventory details.

HINT: This one is pretty hard. 
First, determine how to get the "last" quantity per product. 
Second, coalesce null values to 0 (if you don't have null values, figure out how to rearrange your query so you do.) 
Third, SET current_quantity = (...your select statement...), remembering that WHERE can only accommodate one column. 
Finally, make sure you have a WHERE statement to update the right row, 
	you'll need to use product_units.product_id to refer to the correct row within the product_units table. 
When you have all of these components, you can run the update statement. */

ALTER TABLE product_units
ADD current_quantity INT;

UPDATE product_units 
SET current_quantity = (
		SELECT COALESCE(vpdr.quantity, 0) as quantity FROM product_units pu
		LEFT OUTER JOIN (
			SELECT 
				product_id, quantity, market_date, 
				RANK() OVER (PARTITION BY product_id ORDER BY market_date DESC) AS rank_by_date
			FROM vendor_inventory
		) vpdr -- vendor_product_date_rank
		ON vpdr.product_id = pu.product_id
		WHERE (vpdr.rank_by_date = 1 OR vpdr.product_id IS NULL)
		AND pu.product_id = product_units.product_id
);
