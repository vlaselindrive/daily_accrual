/*В файле тестируется функционал работы витрины daily_accrual*/

/* 1) Предположим, что в сервис прилетела новая пачка займов (для удобства положим их в отдельную временную таблицу)*/
drop table if exists new_loans;
create temporary table new_loans (
    id INTEGER PRIMARY KEY,
    client_id INT NOT NULL,
    product_id INT NOT NULL,
    status VARCHAR(100) NOT NULL,
    open_dttm  timestamp NOT NULL,
    due_dttm timestamp NOT NULL,
    close_dttm  timestamp
);

INSERT INTO new_loans (id, client_id, product_id, status, open_dttm , due_dttm , close_dttm)
VALUES
    (3001,1001, 2001, 'ACTIVE', '2025-03-17 10:00:00', '2025-07-20 10:00:00', NULL),
    (3002, 1002, 2001, 'ACTIVE', '2025-03-17 12:00:00', '2025-07-20 12:00:00', NULL),
    (3003, 1003, 2002, 'ACTIVE', '2025-03-17 14:00:00', '2025-07-20 14:00:00', NULL);

select * from new_loans;

/* 2) Добавляем новые займы и создаем по ним записи в таблице с балансами на основе продуктовых лимитов*/
call new_loans_add('new_loans');

/* a) Проверяем что новые займы появились*/
select * from loans
order by id;

/* b) Проверяем что по новым займам открылись балансы*/
select * from balance_history
order by loan_id, balance_date desc;

/* c) При необходимости вспоминаем продукты и лимиты*/
select * from products;

/*Далее тестируем на примере займа с id=3001*/
/*Предположим, что в сервис прилетела новая пачка транзакций (для удобства положим их в отдельную временную таблицу)*/
DROP table if exists new_payments CASCADE ;
CREATE TEMPORARY TABLE new_payments (
    id INTEGER PRIMARY KEY,
    loan_id INT NOT NULL,
    source VARCHAR(100) NOT NULL,
    payment_dttm timestamp NOT NULL,
    payment_amount INT
);

INSERT INTO new_payments (id, loan_id, source, payment_dttm, payment_amount)
VALUES
    (4100, 3001, 'ride_payment', '2025-03-18 11:00:00', 700),
    (4101, 3001, 'ride_payment', '2025-03-18 11:30:00', 800),
    (4102, 3001, 'ride_payment', '2025-03-18 14:00:00', 1100),
    (4106,  3001, 'ride_payment', '2025-03-19 22:30:00', 1800),
    (4107,  3001, 'ride_payment', '2025-03-20 12:20:00', 1150),
    (4108,  3001, 'direct_payment', '2025-03-20 18:10:00', 2000),
    (4109,  3001, 'direct_payment', '2025-03-22 18:10:00', 8450);

select * from new_payments;

/* 3) Добавляем новые транзакции за дату, которая передается в процедуре*/
call new_payment_add('2025-03-18');

 /* a) Проверяем появление транзакций*/
select * from payments_agg
order by loan_id, payment_dttm desc;

/* b) Проверяем появление новых транзакций в daily_accrual*/
select * from daily_accrual
where 1=1
    and loan_id = 3001
    and report_dt <= '2025-03-22';

/* 4) Закрываем отчетный день: обновляем балансы и daily_accrual */
call update_balance();

/* a) Проверяем, что изменения долетели до balance_history*/
select * from balance_history
where 1=1
    and loan_id = 3001
order by loan_id, balance_date desc;

/* b) Проверяем появление изменение баланса и статуса коллекшена в daily_accrual*/
select * from daily_accrual
where 1=1
    and loan_id = 3001
    and report_dt <= '2025-03-22';

/* 5) Добавляем новые транзакции за дату, которая передается в процедуре*/
call new_payment_add('2025-03-19');

 /* a) Проверяем появление транзакций*/
select * from payments_agg
order by loan_id, payment_dttm desc;

/* b) Проверяем появление новых транзакций в daily_accrual*/
select * from daily_accrual
where 1=1
    and loan_id = 3001
    and report_dt <= '2025-03-22';

/* 6) Закрываем отчетный день: обновляем балансы и daily_accrual */
call update_balance();

/* a) Проверяем, что изменения долетели до balance_history*/
select * from balance_history
where 1=1
    and loan_id = 3001
order by loan_id, balance_date desc;

/* b) Проверяем появление изменение баланса и статуса коллекшена в daily_accrual*/
select * from daily_accrual
where 1=1
    and loan_id = 3001
    and report_dt <= '2025-03-22';

/* 7) Добавляем новые транзакции и обновляем баланс*/
call new_payment_add('2025-03-20');
call update_balance();

/* 8) Добавляем новые транзакции и обновляем баланс*/
call new_payment_add('2025-03-21');
call update_balance();

/* 9) Добавляем новые транзакции и обновляем баланс*/
call new_payment_add('2025-03-22');
call update_balance();

/* 10) Проверяем*/
/* a)  Изменение балансов и статусов в daily_accrual*/
select * from daily_accrual
where 1=1
    and loan_id = 3001
    AND report_dt <= '2025-03-22'; /*Проверяем daily_accrual на примере займа 3001*/

/* b)  Изменение балансов в balance_history*/
select * from balance_history
where 1=1
    and loan_id = 3001
order by loan_id, balance_date desc; /*Проверяем balance_history на примере займа 3001*/

/* c)  Появление транзакций в payments_agg*/
select * from payments_agg
order by loan_id, payment_dttm desc;

/* 11) Предположим, что мы установили, что новые транзакции, начиная с 2025-03-20 оказались кривыми*/
/* a) Удаляем кривые транзакции, начиная с 2025-03-20*/
delete from payments
where loan_id = 3001
and payment_dttm >= '2025-03-20';

/* Проверяем daily_accrual*/
select * from daily_accrual
where 1=1
    and loan_id = 3001
    and report_dt <= '2025-03-22';

/* b) Обновляем исторические данные по балансу, начиная с 2025-03-20*/
call update_balance_history('2025-03-20');

/* Проверяем daily_accrual*/
select * from daily_accrual
where 1=1
    and loan_id = 3001
    and report_dt <= '2025-03-22';

