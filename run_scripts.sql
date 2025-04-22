-- 2) Новые loans
drop table if exists new_loans;
create temporary table new_loans (
    id INTEGER PRIMARY KEY,
--     client_id INT NOT NULL,
    product_id INT NOT NULL,
    offer_id INT NOT NULL,
    status VARCHAR(100) NOT NULL,
    open_dttm  timestamp NOT NULL,
    due_dttm timestamp NOT NULL,
    close_dttm  timestamp,
    created_dttm TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO new_loans (id, product_id, offer_id, status, open_dttm , due_dttm , close_dttm)
VALUES
    (3001, 2001, 7001,'ACTIVE', '2025-03-17 10:00:00', '2025-07-20 10:00:00', NULL);
--     (3002, 1002, 2001, 'ACTIVE', '2025-03-17 12:00:00', '2025-07-20 12:00:00', NULL),
--     (3003, 1003, 2002, 'ACTIVE', '2025-03-17 14:00:00', '2025-07-20 14:00:00', NULL);

select * from new_loans;

-- 2) Новые payments
DROP table if exists new_payments CASCADE ;
CREATE TEMPORARY TABLE new_payments (
    id INTEGER PRIMARY KEY,
    /*external_id UUID DEFAULT gen_random_uuid(),*/
    loan_id INT NOT NULL,
    source VARCHAR(100) NOT NULL,
    payment_dttm timestamp NOT NULL,
    payment_amount INT
);

INSERT INTO new_payments (id, loan_id, source, payment_dttm, payment_amount)
VALUES
    (4100, 3001, 'ride_payment', '2025-03-18 11:00:00', 100),
    (4101, 3001, 'ride_payment', '2025-03-18 11:30:00', 100),
    (4102, 3001, 'ride_payment', '2025-03-18 14:00:00', 100),
    (4106,  3001, 'ride_payment', '2025-03-19 22:30:00', 1800),
    (4107,  3001, 'ride_payment', '2025-03-20 12:20:00', 1150),
    (4108,  3001, 'direct_payment', '2025-03-20 18:10:00', 2000),
    (4111,  3001, 'ride_payment', '2025-03-21 18:10:00', 2300),
    (4109,  3001, 'direct_payment', '2025-03-22 18:10:00', 8450),
    (4110,  3001, 'ride_payment', '2025-03-23 18:10:00', 1386);

select * from new_payments;

-- Добавляем платежи для DPD
DROP table if exists new_payments CASCADE ;
CREATE TEMPORARY TABLE new_payments (
    id INTEGER PRIMARY KEY,
    /*external_id UUID DEFAULT gen_random_uuid(),*/
    loan_id INT NOT NULL,
    source VARCHAR(100) NOT NULL,
    payment_dttm timestamp NOT NULL,
    payment_amount INT
);

INSERT INTO new_payments (id, loan_id, source, payment_dttm, payment_amount)
VALUES
    (4100, 3001, 'ride_payment', '2025-03-18 11:00:00', 700),
--     (4101, 3001, 'ride_payment', '2025-03-18 11:30:00', 800),
--     (4102, 3001, 'ride_payment', '2025-03-18 14:00:00', 500),
    (4106,  3001, 'ride_payment', '2025-03-19 22:30:00', 300),
    (4107,  3001, 'ride_payment', '2025-03-20 12:20:00', 400),
    (4108,  3001, 'direct_payment', '2025-03-20 18:10:00', 550),
--     (4110,  3001, 'ride_payment', '2025-03-21 18:10:00', 1170),
    (4109,  3001, 'direct_payment', '2025-03-22 18:10:00', 200),
    (4111,  3001, 'ride_payment', '2025-03-23 22:30:00', 300),
--     (4126,  3001, 'direct_payment', '2025-03-24 19:20:00', 20000),
    (4112,  3001, 'ride_payment', '2025-03-24 12:20:00', 400),
    (4113,  3001, 'ride_payment', '2025-03-25 22:30:00', 220),
    (4114,  3001, 'ride_payment', '2025-03-26 12:20:00', 150),
    (4115,  3001, 'ride_payment', '2025-03-25 22:30:00', 180),
    (4116,  3001, 'ride_payment', '2025-03-26 12:20:00', 100),
    (4117,  3001, 'ride_payment', '2025-03-28 12:20:00', 380),
    (4118,  3001, 'ride_payment', '2025-03-29 22:30:00', 700),
    (4119,  3001, 'ride_payment', '2025-03-30 12:20:00', 550);

select * from new_payments;
----------------------------------
-- Смотрим займы и продукты
select * from loans order by id;

select * from offers where status = 'ACTIVE';
select * from products_upd order by id;
select * from product_terms;
-- select * from product_policies;

-- Добавляем новые займы
-- call new_loans_add('new_loans');
call new_loans_add_upd('new_loans');



-- Добавляем транзакции
call new_payment_add('2025-03-22');
call update_balance();

select * from daily_accrual
where 1=1
    and loan_id = 3001
    and report_dt <= '2025-03-23';
--     and report_dt <= '2025-03-30';

select * from payments where payment_dttm = '2025-03-18';

-- Смотрим баланс
select * from balance_history
where loan_id = 3001
order by loan_id, balance_date desc;

-- Зачищаем баланс
delete from balance_history
where 1=1
--     and loan_id = 3001
    and balance_date >= '2025-03-18';

-- Смотрим транзакции
select * from payments
where loan_id = 3001
and payment_dttm >= '2025-03-18'
order by loan_id, payment_dttm desc;

select * from payment_agg;

-- Зачищаем транзакции
delete from payments
where loan_id = 3001
and payment_dttm >= '2025-03-18';


select * from payments_agg
order by loan_id, payment_dttm desc;

call update_balance_history('2025-03-18');

call update_payments_history('2025-03-18');

-- Меняем календарь выплат на продукте
select * from products_upd
order by id;

select * from product_terms;


update products_upd
set policy_id = 6003
where product_name = 'general_loan';


select * from balance_history
where loan_id = 3001
order by balance_date desc;


SELECT schema_name FROM information_schema.schemata;


--


