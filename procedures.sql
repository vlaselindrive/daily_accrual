/*В файле объявляются процедуры, которые потом вызываются в файле exec*/

/* 1.1) Процедура по добавлению новых займов*/
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
    command2 := format('insert into loans select id, product_id, offer_id, status, open_dttm , due_dttm , close_dttm from %I', table_name);
    EXECUTE command2;

    /*Открываем балансы по новым займам*/
    insert into balance_history (loan_id, balance_date, open_principal, open_interest, open_VAT, loan_balance)
    select
        t1.id,
        t1.open_dttm,
        t3.approved_amount as open_principal,
        (t3.approved_amount * t2.interest_rate / 100) * t2.period_days/365 as open_interest,
        ROUND(0.16 * (t3.approved_amount * t2.interest_rate / 100) * t2.period_days/365, 2) as open_VAT,
        ROUND(t3.approved_amount +
        (t3.approved_amount * t2.interest_rate / 100) * t2.period_days/365 +
        0.16 * (t3.approved_amount * t2.interest_rate / 100) * t2.period_days/365, 2) as loan_balance
    from loans t1
    inner join products t2
        on t1.product_id = t2.id
        and t1.status = 'ACTIVE'
    left join offers t3
    on t1.offer_id = t3.id;
    COMMIT;
END;
$$;
----------------------------------------------------------------------
/* 1.2) Процедура по добавлению новых займов NEW*/
CREATE OR REPLACE PROCEDURE new_loans_add_upd(table_name text)
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
    command2 := format('insert into loans select id, product_id, offer_id, status, open_dttm , due_dttm , close_dttm from %I', table_name);
    EXECUTE command2;

    /*Открываем балансы по новым займам*/
    insert into balance_history (loan_id, balance_date, open_principal, open_interest, open_VAT, loan_balance)
    select
        t1.id,
        t1.open_dttm,
        t3.approved_amount as open_principal,

--         (t3.approved_amount * t2.interest_rate / 100) * t2.period_days/365 as open_interest,
--         ROUND(0.16 * (t3.approved_amount * t2.interest_rate / 100) * t2.period_days/365, 2) as open_VAT,
--         ROUND(t3.approved_amount +
--         (t3.approved_amount * t2.interest_rate / 100) * t2.period_days/365 +
--         0.16 * (t3.approved_amount * t2.interest_rate / 100) * t2.period_days/365, 2) as loan_balance,

        (t3.approved_amount * (t4.policy_config->>'total_interest_rate')::int / 100) *
        ((t4.policy_config->>'period_length')::int * (t4.policy_config->>'periods')::int)/365 as open_interest,

        ROUND(0.16 * (t3.approved_amount * (t4.policy_config->>'total_interest_rate')::int / 100) *
        ((t4.policy_config->>'period_length')::int * (t4.policy_config->>'periods')::int)/365, 2) as open_VAT,

        (t3.approved_amount * (t4.policy_config->>'total_interest_rate')::int / 100) *
        ((t4.policy_config->>'period_length')::int * (t4.policy_config->>'periods')::int)/365
        +
        ROUND(0.16 * (t3.approved_amount * (t4.policy_config->>'total_interest_rate')::int / 100) *
        ((t4.policy_config->>'period_length')::int * (t4.policy_config->>'periods')::int)/365, 2)
        +
        t3.approved_amount as loan_balance

    from loans t1
    inner join products_upd t2
        on t1.product_id = t2.id
        and t1.status = 'ACTIVE'
    left join offers t3
        on t1.offer_id = t3.id
    left join product_terms t4
        on t2.policy_id = t4.id;
    COMMIT;
END;
$$;
----------------------------------------------------------------------
/* 2) Процедура добавления новых транзакций*/
CREATE OR REPLACE PROCEDURE new_payment_add(dt date)
LANGUAGE plpgsql
AS $$
DECLARE
    command1 text;
    command2 text;
--     dt_formated text;
BEGIN

    /*Удаляем из целевой таблицы с займами все займы с idшниками, как во временной таблице*/
    command1 := format('delete from payments where id in (select id from new_payments where DATE(payment_dttm) = %L)', dt::date);
    EXECUTE command1;


    /*Вставляем в целевую таблицу займы из временной таблицы*/
    command2 := format('insert into payments (id, /*external_id,*/ loan_id, source, payment_dttm, payment_amount)
                       select id, /*external_id::UUID,*/ loan_id, source, payment_dttm, payment_amount
                       from new_payments where DATE(payment_dttm) = %L', dt::date);

    EXECUTE command2;

    COMMIT;
END;
$$;
----------------------------------------------------------------------
/* 3.1) Процедура обновления balance_history в конце отчетного дня*/
/*Берем баланс за вчерашний день, добавляем к нему сегодняшние транзакции и получаем сегодняшний баланс*/
CREATE OR REPLACE PROCEDURE update_balance()
LANGUAGE plpgsql
AS $$
BEGIN
    insert into balance_history (loan_id, balance_date, open_principal, open_interest, open_vat, loan_balance)
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
        /*PRINCIPAL*/
        case
            when t3.daily_total_amount is NULL then t1.open_principal
            else case
                    when t1.open_interest + (t1.open_vat - t3.daily_total_amount) <= 0 then t1.open_principal + (t1.open_interest + (t1.open_vat - t3.daily_total_amount))
                    else t1.open_principal
                 end
        end as updated_open_principal,
        /*INTEREST*/
        case
            when t3.daily_total_amount is NULL then t1.open_interest
            else case
                    when (t1.open_vat - t3.daily_total_amount) <= 0 then
                        case when t1.open_interest + (t1.open_vat - t3.daily_total_amount) <= 0 then 0
                             else (t1.open_interest + (t1.open_vat - t3.daily_total_amount)) end
                    else t1.open_interest
                 end
        end as updated_open_interest,
        /*VAT*/
        case
            when t3.daily_total_amount is NULL then t1.open_vat
            else case
                    when (t1.open_vat - t3.daily_total_amount) <= 0 then 0
                    else (t1.open_vat - t3.daily_total_amount)
                 end
        end as updated_open_vat,
        /*TOTAL_BALANCE*/
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
        and (t1.balance_date + INTERVAL '1 day')  = t3.payment_dttm
    left join loans t4
        on t1.loan_id = t4.id
    left join products t5
        on t4.product_id = t5.id;

    COMMIT;
END;
$$;

select * from balance_history;
----------------------------------------------------------------------
/* 3.2) Процедура обновления balance_history в конце отчетного дня*/
/*Берем баланс за вчерашний день, добавляем к нему сегодняшние транзакции и получаем сегодняшний баланс*/
CREATE OR REPLACE PROCEDURE update_balance_upd()
LANGUAGE plpgsql
AS $$
BEGIN
    insert into balance_history (loan_id, balance_date, open_principal, open_interest, open_vat, loan_balance)
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
        /*PRINCIPAL*/
        case
            when t3.daily_total_amount is NULL then t1.open_principal
            else case
                    when t1.open_interest + (t1.open_vat - t3.daily_total_amount) <= 0 then t1.open_principal + (t1.open_interest + (t1.open_vat - t3.daily_total_amount))
                    else t1.open_principal
                 end
        end as updated_open_principal,
        /*INTEREST*/
        case
            when t3.daily_total_amount is NULL then t1.open_interest
            else case
                    when (t1.open_vat - t3.daily_total_amount) <= 0 then
                        case when t1.open_interest + (t1.open_vat - t3.daily_total_amount) <= 0 then 0
                             else (t1.open_interest + (t1.open_vat - t3.daily_total_amount)) end
                    else t1.open_interest
                 end
        end as updated_open_interest,
        /*VAT*/
        case
            when t3.daily_total_amount is NULL then t1.open_vat
            else case
                    when (t1.open_vat - t3.daily_total_amount) <= 0 then 0
                    else (t1.open_vat - t3.daily_total_amount)
                 end
        end as updated_open_vat,
        /*TOTAL_BALANCE*/
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
        and (t1.balance_date + INTERVAL '1 day')  = t3.payment_dttm
    left join loans t4
        on t1.loan_id = t4.id
    left join products t5
        on t4.product_id = t5.id;

    COMMIT;
END;
$$;

select * from balance_history;
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
/* 5) Процедура для циклического обновления payments за какую-то глубину*/
CREATE OR REPLACE PROCEDURE update_payments_history(dt date)
LANGUAGE plpgsql
AS $$
DECLARE
    command1 text;
BEGIN

    /*Удаляем из целевой таблицы с займами все займы с idшниками, как во временной таблице*/
    command1 := format('delete from payments where payment_dttm >= ''%I''', dt);
    EXECUTE command1;

    while dt < current_date loop
        RAISE NOTICE 'Date is: %', dt;
        call new_payment_add(dt::date);

        dt := dt + INTERVAL '1 day';
        end loop;

    COMMIT;
END;
$$;
----------------------------------------------------------------------


