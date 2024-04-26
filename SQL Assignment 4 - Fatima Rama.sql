-- NOTE: FOR ALL DATE RELATED QUESTIONS, PLEASE MAKE SURE YOU HAVE UPDATED YOUR DATES TO THE RIGHT FORMAT
use assignment_2; -- using the previous schema from assignment 2
set sql_safe_updates = 0;

update customers 
set date_of_birth = str_to_date(date_of_birth, "%d/%m/%Y");

update orders
set order_date = str_to_date(order_date, "%d/%m/%Y");

update orders
set shipping_date = str_to_date(shipping_date, "%d/%m/%Y");

-- [Question 1]
-- Using window functions and CTE, find out which items are priced higher than their item_type's average price
-- For all such items, your results should show item_id, item_name, item_type, item_price and item_type_avg
-- Round item_type_avg to 2 decimal places

with avg_prices as(
	select item_type, round(avg(item_price) over(partition by (item_type)), 2) as item_type_avg
	from items
)

select i.item_id, i.item_name, i.item_type, i.item_price, ap.item_type_avg
from items i
join avg_prices ap
	on i.item_type = ap.item_type
where i.item_price > ap.item_type_avg;

-- [Question 2a]
-- Find out customer_ids that have a total purchase amount > 100 (a simple group by query should do)
-- Your results should show customer_id and total_amount

select o.customer_id, round(sum(i.item_price), 2) as total_amount
from orders o
join items i
	on o.item_id = i.item_id
group by o.customer_id
having total_amount > 100
order by o.customer_id;

-- [Question 2b]
-- Add a column called "customer_value" to the customers table. 15 characters should be enough.

alter table customers
add column customer_value varchar(15);

-- [Question 2c]
-- Write a correlated subquery to update each customer's value as follows:
-- if the total amount of their orders is greater than 150, assign them "high value" status
-- if the total amount of their orders is between 100 and 150, assign them "median value" status. Otherwise, assign them "low value" status.
-- hint: make a CTE for customers and their total amounts and use this in a correlated subquery to update. If you can't figure this out, google how to update with a correlated subquery.

with customer_totals as (
	select o.customer_id, round(sum(i.item_price), 2) as total_amount
	from orders o
	join items i
		on o.item_id = i.item_id
	group by o.customer_id
)

update customers c 
set customer_value = (select
case 
	when ct.total_amount>150 then "high value"
    when ct.total_amount>=100 and ct.total_amount<=150 then "median value"
    else "low value"
    end
from customer_totals ct
where c.customer_id = ct.customer_id);

-- [Question 2d]
-- Finally, show customers table ordered by customer_value in descending order and then customer_id in ascending order

select *
from customers
order by customer_value desc, customer_id;

-- [Question 3] 
-- Show customer_id, last_name, address, street, city and count of customers in each street in each city for all 100 records in customers

select customer_id, last_name, address, street, city, count(customer_id) over (partition by street, city) as customer_count
from customers
order by city, street, customer_id;

-- [Question 4] 
-- Rank each item according to price WITHIN EACH ITEM TYPE. Assign the highest rank to the highest priced item and so on...
-- Use dense rank for this
-- your results should show item_id, item_name, item_type, item_price and ranks

select item_id, item_name, item_type, item_price, dense_rank () over (partition by item_type order by item_price desc) as ranks
from items;

-- [Question 5] 
-- Rank each item TYPE based on its average price. Assign highest rank to the highest avg price and so on
-- Your results should show item_type, item_type_avg and ranks
-- round off average price to 3 decimal places

select item_type, round(avg(item_price), 2) as item_type_avg, rank() over(order by avg(item_price) desc) as ranks
from items
group by item_type;

-- [Question 6a] 
-- Rank each customer_id based on the most expensive item they purchased
-- In another column, also rank each customer_id based on their average purchase amount
-- Highest ranking goes to the highest amount for both columns
-- Your results should show customer_id, max_purchase, avg_purchase, max_purchase_rank, avg_purchase_rank

select o.customer_id, 
round(max(i.item_price),2) as max_purchase, 
round(avg(i.item_price),2) as avg_purchase,
rank () over(order by max(i.item_price) desc) as max_purchase_rank, 
rank () over(order by avg(i.item_price) desc) as avg_purchase_rank
from orders o
join items i
	on o.item_id = i.item_id
group by o.customer_id
order by max_purchase_rank, avg_purchase_rank;

-- [Question 6b]
-- Now, only show those customer_ids that have the same max_purchase_rank and avg_purhase_rank
-- The columns in the result should remain the same as in part(a) 

with customer_rankings as (
	select o.customer_id, 
	round(max(i.item_price),2) as max_purchase, 
	round(avg(i.item_price),2) as avg_purchase,
	rank () over(order by max(i.item_price) desc) as max_purchase_rank, 
	rank () over(order by avg(i.item_price) desc) as avg_purchase_rank
	from orders o
	join items i
		on o.item_id = i.item_id
	group by o.customer_id
    order by max_purchase_rank, avg_purchase_rank
)

select cr.customer_id, cr.max_purchase, cr.avg_purchase, cr.max_purchase_rank, cr.avg_purchase_rank
from customer_rankings cr
where cr.max_purchase_rank=cr.avg_purchase_rank;


-- [Question 7]
-- Sequentially from the earliest order to the latest, find out the difference (in days) between each order for each customer
-- Your results should show customer_id, order_id, current_row_date, next_row_date, and difference

select customer_id, order_id, 
order_date as current_row_date, 
lead(order_date) over(partition by customer_id order by order_date) as next_row_date, 
datediff (lead(order_date) over(partition by customer_id order by order_date), order_date) as difference
from orders;

-- [Question 8]
-- Find out which customers haven't placed an order for over 50 days
-- Since all the dates in the dataset are from 2022, use 2022-07-01 as date_today and calculate the differences from this date
-- Your query should show customer_id, first_name, last_name, phone_number, last_order_date, date_today and difference
-- Remember that date_today will be 2022-07-01 for every record. To add a static column, simply write its value and alias in the select clause. 

with latest_orders as(
	select customer_id, max(order_date) as last_order_date
    from orders
    group by customer_id
)

select c.customer_id, c.first_name, c.last_name, c.phone_number, lo.last_order_date, "2022-07-01" as date_today, 
datediff("2022-07-01", lo.last_order_date) as difference
from customers c
join latest_orders lo
	on c.customer_id=lo.customer_id
where datediff("2022-07-01", lo.last_order_date) > 50
order by difference desc;

-- BONUS QUESTIONS

-- [Question 9]
-- Find out the order_id, order_date, customer_id, first_name, last_name and phone_number of the smallest order amount that took the company's earnings over 5000
-- Assume that the company earns the money on the day the order is placed
-- Do this in a single query

with total_sales as (
	select o.order_id, o.order_date, c.customer_id, c.first_name, c.last_name, c.phone_number, 
    round(sum(i.item_price) over (order by o.order_date),2) as running_total
    from customers c
    join orders o on c.customer_id=o.customer_id
    join items i on o.item_id=i.item_id
)
select *
from total_sales ts
where ts.running_total>5000
limit 1;

-- [Question 10a]
-- Find out if any customers placed an order in their birth month
-- Your results should show customer_id, date_of_birth, order_date

select c.customer_id, c.date_of_birth, o.order_date
from customers c
join orders o on c.customer_id=o.customer_id
where month(c.date_of_birth)=month(o.order_date)
order by c.customer_id;

-- [Question 10b]
-- Find out if any customers placed an order on their birthday
-- Show the same columns as part (a)

select c.customer_id, c.date_of_birth, o.order_date
from customers c
join orders o on c.customer_id=o.customer_id
where month(c.date_of_birth)=month(o.order_date) and day(c.date_of_birth) = day(o.order_date) 
order by c.customer_id;
-- there are no such customers who placed an order on their birthday

