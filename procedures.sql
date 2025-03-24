/*В файле объявляются процедуры, которые потом вызываются в файле exec*/
/* 1) Процедура по добавлению новых займов*/
CREATE OR REPLACE PROCEDURE new_loans_add(table_name text)
LANGUAGE plpgsql
AS $$
DECLARE
    command1 text;
    command2 text;
    command3 text;
BEGIN
    /*Очищаем таблицу с балансами от записей по новым займам*/
    command3 := format('delete from balance_history where loan_id in (select id from %I)', table_name);
    EXECUTE command3;

    /*Удаляем из целевой таблицы с займами все займы с idшниками из временной таблицы*/
    command1 := format('delete from loans where id in (select id from %I)', table_name);
    EXECUTE command1;

    /*Вставляем в целевую таблицу займы из временной таблицы*/
    command2 := format('insert into loans select id, client_id, product_id, status, open_dttm , due_dttm , close_dttm from %I', table_name);
    EXECUTE command2;

    /*Открываем балансы по новым займам*/
    insert into balance_history (loan_id, balance_date, loan_balance)
    select
        t1.id,
        t1.open_dttm,
        t2.loan_limit
    from loans t1
    inner join products t2
        on t1.product_id = t2.id
        and t1.status = 'ACTIVE';

    COMMIT;
END;
$$;
----------------------------------------------------------------------
/* 2) Процедура добавления новых транзакций*/
CREATE OR REPLACE PROCEDURE new_payment_add(dt text)
LANGUAGE plpgsql
AS $$
DECLARE
    command1 text;
    command2 text;
BEGIN

    /*Удаляем из целевой таблицы с займами все займы с idшниками, как во временной таблице*/
    command1 := format('delete from payments where id in (select id from new_payments where DATE(payment_dttm) = ''%I'')', dt);
    EXECUTE command1;

    /*Вставляем в целевую таблицу займы из временной таблицы*/
    command2 := format('insert into payments
                       select id, loan_id, source, payment_dttm, payment_amount from new_payments where DATE(payment_dttm) = ''%I''', dt);
    EXECUTE command2;

    COMMIT;
END;
$$;
----------------------------------------------------------------------
/* 3) Процедура обновления balance_history в конце отчетного дня*/
/*Берем баланс за вчерашний день, добавляем к нему сегодняшние транзакции и получаем сегодняшний баланс*/
CREATE OR REPLACE PROCEDURE  update_balance()
LANGUAGE plpgsql
AS $$
BEGIN
    insert into balance_history (loan_id, balance_date, loan_balance)
    with fresh_balance as (
        select
            loan_id,
            max(balance_date) as balance_date
        from balance_history
        group by loan_id
    )
    select
        t1.loan_id,
        date(t1.balance_date  + INTERVAL '1 day') as balance_date,
        case
            when t3.daily_total_amount is NULL then t1.loan_balance
            else (t1.loan_balance - t3.daily_total_amount)
        end as updated_loan_balance
    from balance_history t1
    inner join fresh_balance t2
        on t1.loan_id = t2.loan_id
        and t1.balance_date = t2.balance_date
        and t1.loan_balance != 0 /*Чтобы не плодить записи с нулевым балансом*/
    left join payments_agg t3
        on t1.loan_id = t3.loan_id
        and (t1.balance_date + INTERVAL '1 day')  = t3.payment_dttm;

    COMMIT;
END;
$$;
----------------------------------------------------------------------
/* 4) Процедура для циклического обновления balance_history за какую-то глубину*/
CREATE OR REPLACE PROCEDURE  update_balance_history(dt date)
LANGUAGE plpgsql
AS $$
DECLARE
    command1 text;
BEGIN
    command1 := format('delete from balance_history where balance_date >=  ''%I''', dt);
    EXECUTE command1;

    while dt < current_date loop
        RAISE NOTICE 'Date is: %', dt;
        call update_balance();

        dt := dt + INTERVAL '1 day';
        end loop;

    COMMIT;
END;
$$;
----------------------------------------------------------------------

