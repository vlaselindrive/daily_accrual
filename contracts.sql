-- Создаем loan
drop table if exists loan cascade;
CREATE TABLE loan (
    id SERIAL PRIMARY KEY,
    amount NUMERIC(14, 2) NOT NULL,
    interest_rate NUMERIC(5, 2) NOT NULL, -- ставка на каждый отдельный платежный период
    term_months INT NOT NULL,
    start_date DATE NOT NULL,
    status TEXT DEFAULT 'active'
);

-- Наполняем loan
INSERT INTO loan ( amount, interest_rate, term_months, start_date)
VALUES
    (2000.00, 10.0, 4, '2025-01-01'),
    (2000.00, 16.0, 4, '2025-01-01'),
    (2000.00, 10.0, 8, '2025-01-01');

select * from loan;

-- Создаем repayment_schedule
drop table if exists repayment_schedule cascade;
CREATE TABLE repayment_schedule (
    id SERIAL PRIMARY KEY,
    loan_id INT REFERENCES loan(id),
    version INT NOT NULL, -- номер версии графика
    payment_number INT NOT NULL, -- № платежа
    payment_date DATE NOT NULL,
    total_payment NUMERIC(14, 2) NOT NULL,
    principal_part NUMERIC(14, 2) NOT NULL,
    interest_part NUMERIC(14, 2) NOT NULL,
    open_principal NUMERIC(14, 2) NOT NULL,
    status TEXT DEFAULT 'scheduled' -- scheduled, paid, overdue и т.д.
);


/*
INSERT INTO repayment_schedule (
    loan_id, version, payment_number, payment_date,
    total_payment, principal_part, interest_part, open_principal
)
VALUES
-- Январь
(1, 1, 1, '2025-02-01', 630.88, 430.88, 200.00, 1569.12),
-- Февраль
(1, 1, 2, '2025-03-01', 630.88, 473.97, 156.91, 1095.15),
-- Март
(1, 1, 3, '2025-04-01', 630.88, 521.36, 109.52, 573.79),
-- и так далее...
(1, 1, 4, '2025-05-01', 630.88, 573.50, 57.38, 0.29);
*/

-- Проверяем, что получилось
SELECT *
FROM repayment_schedule
WHERE 1=1
    AND loan_id = 1
    AND version = (SELECT MAX(version) FROM repayment_schedule WHERE loan_id = 1)
ORDER BY payment_number;

select * from loan;


-- Процедура для генерации графика платежей по займу
CREATE OR REPLACE PROCEDURE make_forecasted_schedule(loan_id int)
LANGUAGE plpgsql
AS $$
DECLARE
    l_id INT;
    l_amount NUMERIC(14,2);
    l_rate NUMERIC(14,4);
    l_term INT;
    l_start DATE;

    r NUMERIC(14,8); -- ставка в долях
    annuity NUMERIC(14,2);

    i INT;
    interest NUMERIC(14,2);
    principal NUMERIC(14,2);
    open_principal NUMERIC(14,2);
    payment_date DATE;
BEGIN
    -- Получаем параметры займа
    SELECT id, amount, interest_rate, term_months, start_date
    INTO l_id, l_amount, l_rate, l_term, l_start
    FROM loan
    WHERE id = loan_id
    LIMIT 1;

    -- Преобразуем ставку в доли
    r := l_rate / 100.0;

    -- Расчёт аннуитетного платежа
    annuity := ROUND(l_amount * (r * POWER(1 + r, l_term)) / (POWER(1 + r, l_term) - 1), 2);
    RAISE NOTICE 'Аннуитетный платёж: %', annuity;

    open_principal := l_amount;

    FOR i IN 1..l_term LOOP
        payment_date := (l_start + (i || ' months')::interval)::date;

        -- Проценты = остаток * ставка
        interest := ROUND(open_principal * r, 2);

        -- Основной долг = платёж - проценты
        principal := ROUND(annuity - interest, 2);

        -- Корректируем последний платёж
        IF i = l_term THEN
            principal := open_principal;
            annuity := principal + interest;
        END IF;

        -- Вставка строки в график
        INSERT INTO repayment_schedule (
            loan_id, version, payment_number, payment_date,
            total_payment, principal_part, interest_part, open_principal
        )
        VALUES (
            l_id, 1, i, payment_date,
            annuity, principal, interest, ROUND(open_principal - principal, 2)
        );

        open_principal := ROUND(open_principal - principal, 2);

        RAISE NOTICE 'Итерация закончена: %', i;

    END LOOP;
END $$;

delete from repayment_schedule;


select * from loan;

select * from repayment_schedule
where loan_id = 1;

call make_forecasted_schedule(1);


-- Упаковываем график в JSON для контракта
SELECT
    loan_id,
    version,
    json_agg(
        json_build_object(
            'payment_number', payment_number,
            'payment_date', payment_date,
            'total_payment', total_payment,
            'principal_part', principal_part,
            'interest_part', interest_part,
            'open_principal', open_principal,
            'status', status
        )
    ) AS repayment_schedule
FROM
    repayment_schedule
GROUP BY
    loan_id,
    version;


----------------------------------------------------
-- Создаем таблицу loan_payments и заполняем ее тестовыми данными
DROP table if exists loan_payments CASCADE ;
CREATE TABLE loan_payments (
    id SERIAL PRIMARY KEY,
    loan_id INT REFERENCES loan(id),
    payment_date DATE NOT NULL,
    payment_amount NUMERIC(14, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Идеально по графику
INSERT INTO loan_payments (loan_id, payment_date, payment_amount)
VALUES
    -- Январь (1 транзакция)
    (1, '2025-01-15', 630.94),
    -- Февраль (3 транзакции)
    (1, '2025-02-05', 200.00),
    (1, '2025-02-18', 300.94),
    (1, '2025-02-25', 130.00),
    -- Март (2 транзакции)
    (1, '2025-03-10', 400.00),
    (1, '2025-03-22', 230.94),
    -- Апрель (4 транзакции)
    (1, '2025-04-03', 150.00),
    (1, '2025-04-12', 180.00),
    (1, '2025-04-20', 200.95),
    (1, '2025-04-29', 100.00);

SELECT
    loan_id,
    DATE_TRUNC('month', payment_date + INTERVAL '1 month')::date AS month,
    SUM(payment_amount) AS total_payment_amount
FROM
    loan_payments
WHERE
    loan_id = 1 -- Фильтруем по loan_id, если нужно
GROUP BY
    loan_id,
    month
ORDER BY
    loan_id,
    month;
----------------------------------------------------
select * from loan;

call make_forecasted_schedule(3);
call recalculate_schedule_by_payment(3);

select * from repayment_schedule
where loan_id = 3
and version = 1;

delete from repayment_schedule;

select * from loan_payments
where loan_id = 1;

delete from loan_payments where loan_id = 1;
INSERT INTO loan_payments (loan_id, payment_date, payment_amount)
VALUES
    -- Январь (1 транзакция)
    (1, '2025-01-15', 630.94),
    -- Февраль (3 транзакции)
    (1, '2025-02-05', 930.94);

INSERT INTO loan_payments (loan_id, payment_date, payment_amount)
VALUES
    -- Январь (1 транзакция)
    (3, '2025-01-12', 374.89),
    -- Февраль (3 транзакции)
    (3, '2025-02-05', 1200.00);
----------------------------------------------------

------------------------------------------------------------------
-- Процедура для пересчета графика платежей
----------------------------------------------------------------

---------------------------------------------
-- Вспомогательная функция для рассчета аннуитета
CREATE OR REPLACE FUNCTION calculate_annuity(
    p_principal NUMERIC,      -- Сумма долга
    p_rate_per_period NUMERIC,-- Ставка за период (в долях, например, 0.01 для 1%)
    p_periods INT            -- Количество периодов
) RETURNS NUMERIC AS $$
DECLARE
    annuity_amount NUMERIC;
BEGIN
    -- Проверка на корректность входа
    IF p_periods <= 0 OR p_principal <= 0 THEN
        RETURN 0.00;
    END IF;

    -- Если ставка 0%, платеж - просто часть долга
    IF p_rate_per_period = 0 THEN
        annuity_amount := p_principal / p_periods;
    ELSE
        -- Классическая формула аннуитета: A = P * (r * (1+r)^n) / ((1+r)^n - 1)
        DECLARE
            rate_plus_one NUMERIC;
            power_term NUMERIC;
        BEGIN
            rate_plus_one := 1 + p_rate_per_period;
            power_term := POWER(rate_plus_one, p_periods);
            -- Проверка деления на ноль (маловероятно при r > 0, но все же)
            IF power_term = 1 THEN
                 -- Это произойдет если rate_plus_one=1 (т.е. rate=0), уже обработано выше,
                 -- или если p_periods=0, тоже обработано.
                 -- Но для полноты, можно вернуть просто P/n или 0.
                 RETURN ROUND(p_principal / p_periods, 2); -- или RAISE EXCEPTION
            END IF;
            annuity_amount := p_principal * (p_rate_per_period * power_term) / (power_term - 1);
        END;
    END IF;

    RETURN ROUND(annuity_amount, 2); -- Округляем до копеек
END;
$$ LANGUAGE plpgsql IMMUTABLE;
---------------------------------------------
-- Процедура пересчета графика с использованием функции аннуитета
-- Убедитесь, что функция calculate_annuity существует
-- CREATE OR REPLACE FUNCTION calculate_annuity(...) ...

CREATE OR REPLACE PROCEDURE recalculate_schedule_by_payment( -- Новое имя процедуры
    IN p_loan_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    l_record RECORD; -- Данные займа
    new_version INT;
    current_principal NUMERIC(14, 2);
    calc_interest_part NUMERIC(14, 2); -- Проценты, начисленные за период
    total_paid_in_period NUMERIC(14, 2); -- Фактически оплачено
    payment_count_in_period INT;       -- Количество фактических платежей в периоде
    interest_paid_actual NUMERIC(14, 2); -- Фактически погашено процентов
    principal_paid_actual NUMERIC(14, 2);-- Фактически погашено ОД
    current_payment_date DATE;
    period_start_date DATE;
    period_end_date DATE;
    i INT;
    schedule_status TEXT;
    rate_per_period NUMERIC(14, 8);
    calculating_projection BOOLEAN := false; -- Флаг: текущий период прогнозный?
    current_annuity_payment NUMERIC(14, 2) := 0.00; -- Аннуитет для текущего блока прогноза

    -- Переменные для записи в график
    payment_to_insert NUMERIC(14, 2);
    principal_to_insert NUMERIC(14, 2);
    interest_to_insert NUMERIC(14, 2);

BEGIN
    -- 1. Получаем данные займа
    SELECT id, amount, interest_rate, term_months, start_date, status
    INTO l_record
    FROM loan
    WHERE id = p_loan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Займ с ID % не найден', p_loan_id;
    END IF;

    -- 2. Определяем номер новой версии графика
    SELECT COALESCE(MAX(version), 0) + 1
    INTO new_version
    FROM repayment_schedule
    WHERE loan_id = p_loan_id;

--     RAISE NOTICE 'Пересчет по наличию платежей для займа ID: %, Новая версия: %', p_loan_id, new_version;

    -- 3. Инициализация
    current_principal := l_record.amount;
    period_end_date := l_record.start_date;
    rate_per_period := l_record.interest_rate / 100.0;
    calculating_projection := false; -- Начинаем не с прогноза

    -- 4. Цикл по всем периодам
    FOR i IN 1..l_record.term_months LOOP
        -- Даты периода
        current_payment_date := (l_record.start_date + (i || ' months')::interval)::date;
        period_start_date := period_end_date + interval '1 day';
        period_end_date := current_payment_date;

--         RAISE NOTICE '---- Период % (Даты: % - %) ----', i, period_start_date, period_end_date;
--         RAISE NOTICE 'Период %: Начальный ОД = %', i, current_principal;

        -- Начисляем проценты на начало периода
        calc_interest_part := ROUND(GREATEST(0, current_principal) * rate_per_period, 2);
--         RAISE NOTICE 'Период %: Начислено процентов = %', i, calc_interest_part;

        -- Ищем фактические платежи в этом периоде
        SELECT COALESCE(SUM(payment_amount), 0.00), COUNT(*)
        INTO total_paid_in_period, payment_count_in_period
        FROM loan_payments
        WHERE loan_id = p_loan_id
          AND payment_date BETWEEN period_start_date AND period_end_date;

        -- Логика в зависимости от наличия платежей
        IF payment_count_in_period > 0 THEN
            -- === ЕСТЬ ПЛАТЕЖИ В ЭТОМ ПЕРИОДЕ ===
--             RAISE NOTICE 'Период %: Найдены платежи (Count=%, Sum=%). Расчет по факту.', i, payment_count_in_period, total_paid_in_period;
            calculating_projection := false; -- Прерываем режим прогноза, если он был

            -- Распределяем фактический платеж
            interest_paid_actual := LEAST(total_paid_in_period, calc_interest_part);
            principal_paid_actual := total_paid_in_period - interest_paid_actual;

            -- Корректировка ОД
            IF principal_paid_actual > current_principal THEN
                 principal_paid_actual := current_principal;
            END IF;

            -- Готовим данные для вставки
            payment_to_insert := total_paid_in_period;
            principal_to_insert := principal_paid_actual;
            interest_to_insert := interest_paid_actual;
            schedule_status := 'actual'; -- Статус: основано на фактических данных

            -- Обновляем основной долг
            current_principal := ROUND(current_principal - principal_paid_actual, 2);

        ELSE
            -- === НЕТ ПЛАТЕЖЕЙ В ЭТОМ ПЕРИОДЕ ===
--             RAISE NOTICE 'Период %: Платежи не найдены. Расчет ПРОГНОЗНЫЙ.', i;

            -- Если мы еще не в режиме прогноза, нужно рассчитать аннуитет
            IF NOT calculating_projection THEN
                calculating_projection := true; -- Включаем режим прогноза
                DECLARE
                    remaining_term INT;
                BEGIN
                    remaining_term := l_record.term_months - i + 1;
--                     RAISE NOTICE 'Период %: Начало блока без платежей. Расчет аннуитета. ОД=%, Срок=%',
--                                  i, current_principal, remaining_term;
                    -- Рассчитываем аннуитет на остаток срока с текущего ОД
                    current_annuity_payment := calculate_annuity(current_principal, rate_per_period, remaining_term);
--                     RAISE NOTICE 'Период %: Рассчитан аннуитет для прогноза = %', i, current_annuity_payment;
                END;
            ELSE
--                  RAISE NOTICE 'Период %: Продолжаем использовать аннуитет = %', i, current_annuity_payment;
            END IF;

             -- Если долг уже погашен, будущие платежи нулевые
            IF current_principal <= 0 THEN
                interest_to_insert := 0.00;
                principal_to_insert := 0.00;
                payment_to_insert := 0.00;
            ELSE
                -- Используем рассчитанный аннуитет
                interest_to_insert := calc_interest_part;
                principal_to_insert := current_annuity_payment - interest_to_insert;
                payment_to_insert := current_annuity_payment;

                -- Корректировка последнего платежа
                IF i = l_record.term_months THEN
--                     RAISE NOTICE 'Период %: Корректировка ПОСЛЕДНЕГО прогнозного платежа.', i;
                    principal_to_insert := current_principal;
                    payment_to_insert := principal_to_insert + interest_to_insert;
                ELSE
                    -- Защита от отрицательного ОД
                    IF principal_to_insert > current_principal THEN
                        principal_to_insert := current_principal;
                        payment_to_insert := principal_to_insert + interest_to_insert;
                    END IF;
                END IF;

                -- Обновляем основной долг
                current_principal := ROUND(current_principal - principal_to_insert, 2);
            END IF; -- current_principal > 0

            schedule_status := 'projected'; -- Статус: спрогнозировано

        END IF; -- Конец IF по наличию платежей

--         RAISE NOTICE 'Период %: ОД на конец = %', i, current_principal;
--         RAISE NOTICE 'Период %: Запись в график: Платеж=%, ОД=%, %=%, Ост ОД=%, Статус=%',
--                      i, payment_to_insert, principal_to_insert, interest_to_insert, current_principal, schedule_status;

        -- 5. Вставляем строку в НОВУЮ версию графика
        INSERT INTO repayment_schedule (
            loan_id, version, payment_number, payment_date,
            total_payment, principal_part, interest_part, open_principal, status
        ) VALUES (
            p_loan_id, new_version, i, current_payment_date,
            payment_to_insert, principal_to_insert, interest_to_insert, current_principal, schedule_status
        );

    END LOOP; -- Конец цикла по периодам

    -- 6. Обновляем статус займа (без изменений, использует только финальный ОД)
    IF current_principal <= 0 THEN
        UPDATE loan SET status = 'closed' WHERE id = p_loan_id;
--         RAISE NOTICE 'Займ ID % полностью погашен и закрыт.', p_loan_id;
    ELSE
        -- Используем последнюю дату платежа из графика для проверки просрочки
        IF period_end_date < CURRENT_DATE AND current_principal > 0 THEN -- Используем CURRENT_DATE здесь для статуса займа
             UPDATE loan SET status = 'overdue' WHERE id = p_loan_id AND status != 'closed';
--              RAISE NOTICE 'Займ ID % не погашен и имеет просрочку. Остаток: %', p_loan_id, current_principal;
        ELSE
             UPDATE loan SET status = 'active' WHERE id = p_loan_id AND status NOT IN ('closed', 'overdue');
--              RAISE NOTICE 'Займ ID % еще не погашен (статус active). Остаток: %', p_loan_id, current_principal;
        END IF;
    END IF;

END $$;




