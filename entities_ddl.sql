/*В файле содержатся DDL основных сущностей сервиса daily_accrual*/
/* ВЫПИЛИВАЕМ 1) Создание таблицы client*/
/*
DROP SEQUENCE if exists sequence_1000 CASCADE;
CREATE SEQUENCE sequence_1000
    START WITH 1001;

DROP table if exists clients CASCADE;
CREATE TABLE clients (
    id INTEGER DEFAULT nextval('sequence_1000') PRIMARY KEY,
    name VARCHAR(100) NOT NULL,  -- Имя клиента
    age INT NOT NULL,  -- Возраст клиента
    nationality VARCHAR(100) NOT NULL  -- Национальность клиента
);

INSERT INTO clients (name, age, nationality)
VALUES
    ('Pablo Escobar', 33, 'Colombian'),
    ('Miguel Garcia', 25, 'Mexican'),
    ('Andrea Santos', 40, 'Mexican'),
    ('Pedro Pascal', 35, 'Mexican');

select * from clients;
*/
----------------------------------------------------------------------
/* 2.1) Таблица с продуктами*/
DROP SEQUENCE if exists sequence_2000 CASCADE;
CREATE SEQUENCE sequence_2000
    START WITH 2001;

DROP table if exists products CASCADE;
CREATE TABLE products (
    id INTEGER DEFAULT nextval('sequence_2000') PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    interest_rate INT NOT NULL,
    period_days INT NOT NULL,
    policy_id INT,
    risk_category VARCHAR(3),
--     loan_limit INT NOT NULL,
    FOREIGN KEY (policy_id) REFERENCES product_policies(id)
);

INSERT INTO products (product_name, interest_rate, period_days, policy_id, risk_category)
VALUES
    ('general_loan', 22, 124, 6002, 'A'),
    ('general_loan', 24, 124, 6002, 'B'),
    ('general_loan', 26, 124, 6002, 'C'),
    ('newbies_loan', 20, 124, 6002, null),
    ('platinum_loan', 21, 124, 6001, null);

select * from products;
----------------------------------------------------------------------
/* 2.1) Таблица с продуктами НОВАЯ*/
DROP SEQUENCE if exists sequence_2000 CASCADE;
CREATE SEQUENCE sequence_2000
    START WITH 2001;

DROP table if exists products_upd CASCADE;
CREATE TABLE products_upd (
    id INTEGER DEFAULT nextval('sequence_2000') PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    risk_category VARCHAR(100),
    policy_id INT,
    required_fields TEXT[],
--     loan_limit INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (policy_id) REFERENCES product_terms(id)
);

INSERT INTO products_upd (product_name, risk_category, policy_id, required_fields)
VALUES
    ('general_loan', 'A', 6001, ARRAY['CURP&RFC', 'Email', 'Address', '...']),
    ('general_loan',  'B',6001, ARRAY['CURP&RFC', 'Email', 'Address', '...']),
    ('general_loan', 'C', 6001, ARRAY['CURP&RFC', 'Email', 'Address', '...']),
    ('newbies_loan',  NULL,6002, ARRAY['CURP&RFC', 'Email', 'Address', '...']),
    ('platinum_loan', NULL, 6002, ARRAY['CURP&RFC', 'Email', 'Address', '...']);

select * from products_upd;

----------------------------------------------------------------------
/* 2.2) Таблица с графиком платежей по продуктам*/
DROP table if exists product_policies CASCADE;
CREATE TABLE product_policies (
    id INT PRIMARY KEY,
    policy_name VARCHAR(100) NOT NULL,
    first_period_days INT NOT NULL,
    first_period_share INT NOT NULL,
    second_period_days INT NOT NULL,
    second_period_share INT NOT NULL,
    third_period_days INT NOT NULL,
    third_period_share INT NOT NULL
);

INSERT INTO product_policies (id, policy_name, first_period_days, first_period_share, second_period_days, second_period_share, third_period_days, third_period_share)
VALUES
    (6001,'standard', 31, 25, 62, 50, 93, 75),
    (6002, 'test', 1, 50, 2, 70, 3, 90),
    (6003, 'test_dpd', 1, 50, 4, 70, 7, 90);

select * from product_policies;

----------------------------------------------------------------------
DROP TABLE IF EXISTS product_terms CASCADE;

CREATE TABLE product_terms (
    id INT PRIMARY KEY,
    policy_name VARCHAR(100) NOT NULL,
    status VARCHAR(100) NOT NULL,
    policy_config JSONB NOT NULL, -- Хранение условий в формате JSONB
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO product_terms (id, policy_name, status, policy_config)
VALUES
    (6001, 'standard', 'ACTIVE','{"periods": 4, "period_length": 31, "total_interest_rate": 40, "period_interest_rate": 10, "interest_on": "open_principal"}'),
    (6002, 'ultra-hard: 2d periods','ACTIVE', '{"periods": 62, "period_length": 2, "total_interest_rate": 40, "period_interest_rate": 0.645, "interest_on": "open_principal"}'),
    (6003, 'hard: 4d periods','ACTIVE', '{"periods": 31, "period_length": 4, "total_interest_rate": 40, "period_interest_rate": 1.290, "interest_on": "open_principal"}');

select * from product_terms;

----------------------------------------------------------------------

/* 2.3) Таблица с условиями выплат по продуктам*/
DROP table if exists payment_schemes CASCADE;
CREATE TABLE payment_schemes (
    id INT PRIMARY KEY,
    scheme_name VARCHAR(100) NOT NULL,
    VAT_share INT NOT NULL,
    principal_share INT NOT NULL,
    interest_share INT NOT NULL
);

INSERT INTO payment_schemes (id, scheme_name, VAT_share, principal_share, interest_share) VALUES
    (6001, 'fix', 16, 20, 40),
    (6002,'annuity', 16, 40, 40),
    (6003, 'differentiated', 16, 20, 40);

select * from payment_schemes;
----------------------------------------------------------------------
/* 3) Таблица с займами*/
DROP table if exists loans CASCADE;
CREATE TABLE loans (
    id INTEGER PRIMARY KEY,
--     client_id INT NOT NULL,
    product_id INT NOT NULL,
    offer_id INT NOT NULL,
    status VARCHAR(100) NOT NULL,
    open_dttm  timestamp NOT NULL,
    due_dttm timestamp NOT NULL,
    close_dttm  timestamp,
    created_dttm TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (offer_id) REFERENCES offers(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
--     FOREIGN KEY (client_id) REFERENCES clients(id)
);

INSERT INTO loans (id, product_id, offer_id, status, open_dttm , due_dttm , close_dttm)
VALUES
    (3004, 2001, 7002,'PAID', '2024-10-04 18:00:00', '2025-03-08 18:00:00', '2025-03-08 16:00:00');

select * from loans;
----------------------------------------------------------------------
/* 4.1) Таблица с транзакциями*/
-- CREATE EXTENSION IF NOT EXISTS pgcrypto; /*Для генерации UUID*/

DROP table if exists payments CASCADE ;
CREATE TABLE payments (
    id INTEGER PRIMARY KEY,
    /*external_id UUID DEFAULT gen_random_uuid(),*/
    loan_id INT,
    source VARCHAR(100) NOT NULL,
    payment_dttm timestamp NOT NULL,
    payment_amount INT,
    FOREIGN KEY (loan_id) REFERENCES loans(id)
);

INSERT INTO payments (id, loan_id, source, payment_dttm, payment_amount)
VALUES
--     (4001, 3002, 'ride_payment', '2025-02-27 12:30:00', 1400),
--     (4002,  3002, 'ride_payment', '2025-02-26 11:20:00', 950),
--     (4003,  3002, 'ride_payment', '2025-02-26 11:30:00', 700),
--     (4004,  3002, 'ride_payment', '2025-02-26 11:40:00', 880),
--     (4005, 3002, 'direct_payment', '2025-02-25 15:00:00', 3000),
--     (4006, 3003, 'ride_payment', '2025-02-27 19:00:00', 750),
--     (4007, 3003, 'ride_payment', '2025-02-26 19:00:00', 1000),
--     (4008,  3003, 'direct_payment', '2025-02-26 14:00:00', 4000),
--     (4009, 3003, 'ride_payment', '2025-02-25 19:00:00', 690),
--     (4010, 3004, 'ride_payment', '2025-02-25 10:30:00', 1200),
    (4009, 3004, 'ride_payment', '2025-03-06 19:00:00', 690),
    (4011,  3004, 'ride_payment', '2025-03-07 12:30:00', 900),
    (4012,  3004, 'ride_payment', '2025-03-07 12:00:00', 1300),
    (4013,  3004, 'direct_payment', '2025-03-08 16:30:00', 3300);

select * from payments
order by loan_id, payment_dttm desc;
----------------------------------------------------------------------
/* 4.2) Вьюха с транзакциями агрегированными по дням*/
DROP VIEW if exists payments_agg;
CREATE VIEW payments_agg AS
SELECT
    loan_id,
    date(payment_dttm) AS payment_dttm,
    sum(payment_amount) AS daily_total_amount,
    array_agg(id) AS transactions_ids
FROM payments
GROUP BY
    loan_id,
    date(payment_dttm);

select * from payments_agg
order by loan_id, payment_dttm desc;
----------------------------------------------------------------------
/* 5) Таблица с балансами*/
DROP SEQUENCE if exists sequence_5000 CASCADE;
CREATE SEQUENCE sequence_5000
    START WITH 5001;

DROP table if exists balance_history CASCADE;
CREATE TABLE balance_history (
    id INTEGER DEFAULT nextval('sequence_5000') PRIMARY KEY,
    loan_id INT NOT NULL,
    balance_date date NOT NULL,
    open_principal INT NOT NULL,
    open_interest INT NOT NULL,
    open_VAT INT NOT NULL,
    loan_balance INT NOT NULL,
    created_dttm TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (loan_id) REFERENCES loans(id)
);

INSERT INTO balance_history (loan_id, balance_date, open_principal, open_interest, open_VAT, loan_balance)
VALUES
    (3004, '2025-03-08 16:00:00.000000', 0, 0, 0, 0);

select * from balance_history;
----------------------------------------------------------------------
/* 6) Оффера*/
DROP table if exists offers CASCADE ;
CREATE TABLE offers (
    id INTEGER PRIMARY KEY,
    product_id INT,
    approved_amount INT NOT NULL,
    status VARCHAR(100) NOT NULL, -- enum: (in use | applied | canceled)
    created_dttm timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id)
);

INSERT INTO offers (id, product_id, approved_amount, status)
VALUES
    (7001, 2001, 16000, 'ACTIVE'),
    (7002, 2001, 12000, 'EXPIRED');

select * from offers
order by id desc;

----------------------------------------------------------------------
/* 7) Прототип витрины daily_accrual*/
DROP VIEW if exists daily_accrual;
CREATE VIEW daily_accrual AS
with date_list as ( /*Год размазанный по датам*/
    SELECT generate_series(
        '2025-01-01'::date,
        '2026-01-01'::date,
        '1 day'::interval
    ) AS date
order by date desc
)
select
    DATE(t2.date) as report_dt,
    t1.id as loan_id,
    t5.product_name,
    case
        when t4.loan_balance is null then 'NO BALANCE DATA'
        when t4.loan_balance <= 0 then 'PAID'
        else t1.status
    end as loan_status,
    case
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + ((t9.policy_config ->> 'periods')::int * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > 0 then 'WARNING:DPD'
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + (3 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > (t8.approved_amount * (100 - 75)) / 100 then 'WARNING:3'
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + (2 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > (t8.approved_amount * (100 - 50)) / 100 then 'WARNING:2'
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + (1 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > (t8.approved_amount * (100 - 25)) / 100 then 'WARNING:1'
        else 'OK'
    end as collection_status,
    case
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + ((t9.policy_config ->> 'periods')::int * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > 0 then 'Last: ' || (DATE(t2.date) - DATE(DATE(t1.open_dttm) + (3 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day')))::text
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + (3 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
            t4.loan_balance > (t8.approved_amount * (100 - 75)) / 100 then 'P3: ' || (DATE(t2.date) - DATE(DATE(t1.open_dttm) + (3 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day')))::text
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + (2 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > (t8.approved_amount * (100 - 50)) / 100 then 'P2: ' || (DATE(t2.date) - DATE(DATE(t1.open_dttm) + (2 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day')))::text
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + (1 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > (t8.approved_amount * (100 - 25)) / 100 then 'P1: ' || (DATE(t2.date) - DATE(DATE(t1.open_dttm) + (1 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day')))::text
        else 'OK'
    end as dpd_status,
    t4.loan_balance,
    t4.open_principal,
    t4.open_interest,
    t4.open_VAT,
    t3.daily_total_amount,
    t3.transactions_ids
from loans t1
cross join date_list t2
left join offers t8
    on t1.offer_id = t8.id
left join payments_agg t3
    on t1.id = t3.loan_id
    and DATE(t2.date) = t3.payment_dttm
left join balance_history t4
    on t1.id = t4.loan_id
    and DATE(t2.date) = t4.balance_date
left join products t5
on t1.product_id = t5.id
left join product_policies t7
    on t5.policy_id = t7.id
left join product_terms t9
    on t5.policy_id = t9.id
where 1=1
--     and t1.id = 3001
--     and DATE(t2.date) <= '2025-03-22'
    and DATE(t2.date) >= DATE(t1.open_dttm)
order by t2.date desc;

select * from daily_accrual;
----------------------------------------------------------------------
-- Доработка по статусам
DROP VIEW if exists daily_accrual;
CREATE VIEW daily_accrual AS
with date_list as ( /*Год размазанный по датам*/
    SELECT generate_series(
        '2025-01-01'::date,
        '2026-01-01'::date,
        '1 day'::interval
    ) AS date
order by date desc
)
select
    DATE(t2.date) as report_dt,
    t1.id as loan_id,
    t5.product_name,
    case
        when t4.loan_balance is null then 'NO BALANCE DATA'
        when t4.loan_balance <= 0 then 'PAID'
        else t1.status
    end as loan_status,
    case
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + ((t9.policy_config ->> 'periods')::int * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > 0 then 'WARNING:DPD'
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + (3 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > (t8.approved_amount * (100 - 3 * (100/(t9.policy_config ->> 'periods')::int)) ) / 100 then 'WARNING:3'
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + (2 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > (t8.approved_amount * (100 - 2 * (100/(t9.policy_config ->> 'periods')::int)) ) / 100 then 'WARNING:2'
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + (1 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > (t8.approved_amount * (100 - 1 * (100/(t9.policy_config ->> 'periods')::int)) ) / 100 then 'WARNING:1'
        else 'OK'
    end as collection_status,
    case
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + ((t9.policy_config ->> 'periods')::int * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > 0 then 'Last: ' || (DATE(t2.date) - DATE(DATE(t1.open_dttm) + (3 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day')))::text
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + (3 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
            t4.loan_balance > (t8.approved_amount * (100 - 3 * (100/(t9.policy_config ->> 'periods')::int))) / 100 then 'P3: ' || (DATE(t2.date) - DATE(DATE(t1.open_dttm) + (3 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day')))::text
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + (2 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > (t8.approved_amount * (100 - 2 * (100/(t9.policy_config ->> 'periods')::int))) / 100 then 'P2: ' || (DATE(t2.date) - DATE(DATE(t1.open_dttm) + (2 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day')))::text
        when DATE(t2.date) > DATE(DATE(t1.open_dttm) + (1 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day'))  AND
             t4.loan_balance > (t8.approved_amount * (100 - 1 * (100/(t9.policy_config ->> 'periods')::int))) / 100 then 'P1: ' || (DATE(t2.date) - DATE(DATE(t1.open_dttm) + (1 * (t9.policy_config ->> 'period_length')::int * INTERVAL '1 day')))::text
        else 'OK'
    end as dpd_status,
    t4.loan_balance,
    t4.open_principal,
    t4.open_interest,
    t4.open_VAT,
    t3.daily_total_amount,
    t3.transactions_ids
from loans t1
cross join date_list t2
left join offers t8
    on t1.offer_id = t8.id
left join payments_agg t3
    on t1.id = t3.loan_id
    and DATE(t2.date) = t3.payment_dttm
left join balance_history t4
    on t1.id = t4.loan_id
    and DATE(t2.date) = t4.balance_date
left join products_upd t5
on t1.product_id = t5.id
left join product_policies t7
    on t5.policy_id = t7.id
left join product_terms t9
    on t5.policy_id = t9.id
where 1=1
--     and t1.id = 3001
--     and DATE(t2.date) <= '2025-03-22'
    and DATE(t2.date) >= DATE(t1.open_dttm)
order by t2.date desc;

select * from daily_accrual;
----------------------------------------------------------------------
SELECT
    1 * (policy_config ->> 'period_length')::int as period_1,
    2 * (policy_config ->> 'period_length')::int as period_1,
    3 * (policy_config ->> 'period_length')::int as period_1,
    (policy_config->>'periods')::int AS periods,
    (policy_config->>'period_length')::int AS period_length,
    (policy_config->>'interest_rate')::int AS interest_rate
FROM terms;

select
    (policy_config ->> 'periods')::int * (policy_config ->> 'period_length')::int

from product_terms