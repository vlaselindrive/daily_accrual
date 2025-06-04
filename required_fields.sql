-- Удаление таблиц, если они существуют (для удобства повторного выполнения скрипта)

-- 1. Таблица Продуктов (products)
drop table if exists products cascade;
create table products
(
    product_id SERIAL PRIMARY KEY,
    product_name   varchar(100)                        not null,
    status        varchar(100)                        not null,
    terms jsonb                               not null,
    created_at    timestamp default CURRENT_TIMESTAMP not null
);

INSERT INTO products (product_name, status, terms) VALUES
('general_loan', 'ACTIVE', '{"term": 124, "periods": 1, "interest_on": "open_principal", "period_length": 31, "cost_of_use": 35.7, "payment_scheme": "comission_based", "сountry_code": "MX", "currency_code": "MXN"}'),
('repeated_loan', 'ACTIVE', '{"term": 124, "periods": 1, "interest_on": "open_principal", "period_length": 31, "cost_of_use": 35.7, "payment_scheme": "comission_based", "сountry_code": "MX", "currency_code": "MXN"}'),
('newbies_loan', 'ACTIVE', '{"term": 124, "periods": 1, "interest_on": "open_principal", "period_length": 31, "cost_of_use": 35.7, "payment_scheme": "comission_based", "сountry_code": "MX", "currency_code": "MXN"}');

-- 2. Таблица Окон/Шагов (windows)
DROP TABLE IF EXISTS windows cascade;
CREATE TABLE windows (
    window_id SERIAL PRIMARY KEY,
    window_name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Окна (ids: 1, 2, 3)
INSERT INTO windows (window_name, description) VALUES
('curp_and_rfc',  'Окно с документами, удостоверяющими личность: CURP и RFC'),
('address_info',  'Окно с адресом фактического проживания'),
('bank_details',  'Информация о банковских реквизитах пользователя');

select * from windows;

-- 3. Таблица Полей (fields)
DROP TABLE IF EXISTS fields cascade;
CREATE TABLE fields (
    field_id SERIAL PRIMARY KEY,
    field_name VARCHAR(100) NOT NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO fields (field_name) VALUES
('CURP'),
('RFC'),
('address_country'),
('address_city'),
('address_zipcode'),
('bank_code'),
('bank_account');

select * from fields;


-- 4. Связующая таблица Продукт-Окно (product_window_mapping)
-- Определяет, какие окна и в каком порядке используются для какого продукта
DROP TABLE IF EXISTS product_window_mapping;
CREATE TABLE product_window_mapping (
    mapping_id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE, -- Ссылка на продукт
    window_id INT NOT NULL REFERENCES windows(window_id) ON DELETE CASCADE,   -- Ссылка на окно
    display_order INT NOT NULL, -- Порядок отображения окна для продукта
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (product_id, window_id),    -- Окно может быть привязано к продукту только один раз
    UNIQUE (product_id, display_order) -- Порядок должен быть уникальным в рамках продукта
);

-- Связи Продукт-Окно (определяем порядок окон для продуктов)
-- Продукт 1: Окно 1 -> Окно 2
INSERT INTO product_window_mapping (product_id, window_id, display_order) VALUES
(1, 1, 1),
(1, 2, 2),
(1, 3, 3),
(2, 1, 1),
(2, 2, 2),
(2, 3, 3);

select * from product_window_mapping;

-- 5. Связующая таблица Окно-Поле (window_field_mapping)
DROP TABLE IF EXISTS window_field_mapping;
CREATE TABLE window_field_mapping (
    mapping_id SERIAL PRIMARY KEY,
    window_id INT NOT NULL REFERENCES windows(window_id) ON DELETE CASCADE,     -- Ссылка на окно
    field_id INT NOT NULL REFERENCES fields(field_id) ON DELETE CASCADE,       -- Ссылка на поле
    display_order INT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (window_id, field_id),        -- Поле может быть привязано к окну только один раз
    UNIQUE (window_id, display_order)   -- Порядок должен быть уникальным в рамках окна
);

INSERT INTO window_field_mapping (window_id, field_id, display_order) VALUES
-- Окно 1: 'curp_and_frc' (ID=1)
(1, 1, 1),
(1, 2, 2),

-- Окно 2: 'address_info' (ID=2)
(2, 3, 1),
(2, 4, 2),
(2, 5, 3),

-- Окно 3: 'bank details' (ID=3)
(3, 6, 1),
(3, 7, 2);

-- 6. Сущность заявки
DROP TABLE IF EXISTS applications CASCADE;
CREATE TABLE applications (
    application_id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(product_id),
    client_id VARCHAR(255) NOT NULL,
    current_window_id INT REFERENCES windows(window_id),
    status VARCHAR(50) NOT NULL DEFAULT 'IN_PROGRESS', -- ('IN_PROGRESS', 'COMPLETED', 'SUBMITTED', 'APPROVED', 'REJECTED')
    application_data JSONB DEFAULT '{}'::jsonb, -- Данные заявки в формате "field_id" : "значение"
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

create trigger set_timestamp_applications
    before update
    on applications
    for each row
execute procedure trigger_set_timestamp();


------ Тестирование функционала ---------
-- Смотрим сущности
select * from products;
select * from windows;
select * from fields;

select * from product_window_mapping;
select * from window_field_mapping;


-- 1) Собираем окна и поля для заявки по продукту
select
    t1.product_id,
    t1.product_name,
    t3.window_name,
    t2.display_order as window_order,
    t5.field_name,
    t4.display_order as field_order,
    row_number() over(partition by t1.product_id order by t2.display_order, t4.display_order) as overall_order
from products t1
inner join product_window_mapping t2
    on t1.product_id = t2.product_id
    and t1.product_id = 1
join windows t3
    on t2.window_id = t3.window_id
    and t3.is_active = true
join window_field_mapping t4
    on t3.window_id = t4.window_id
join fields t5
    on t4.field_id = t5.field_id
    and t5.is_active = true;

-- Включаем и отключаем окна и поля
update windows
set is_active = true -- true -- false
where window_name = 'bank_details';

update fields
set is_active = true -- true -- false
where field_name = 'address_zipcode';

select * from windows;


-- 2) Проходим application
delete from applications;

select * from applications
where application_id = 1;

-- Клиент начинает заполнять заявку
INSERT INTO applications (application_id, product_id, client_id, status)
VALUES (1,1, 'Pedro Pascal', 'IN_PROGRESS');

-- Попал на первый шаг
update applications
set current_window_id = 1
where application_id = 1;

-- Заполнил первый шаг и перешел на второй
update applications
set application_data = application_data || '{"CURP": "CAPJ630301HDFHRN05", "RFC": "CAPJ630301472"}'::jsonb,
    current_window_id = 2 -- переходим на следующее окно
where application_id = 1;

-- Заполнил второй шаг и перешел на третий
update applications
set application_data = application_data || '{"address_country": "México","address_city": "Ciudad de México","address_zipcode": "09700"}'::jsonb,
    current_window_id = 3 -- переходим на следующее окно
where application_id = 1;

-- Заполнил третий шаг и завершил заявку
update applications
set application_data = application_data || '{"bank_account": "127180013431460821","bank_code": "127"}'::jsonb,
    status = 'COMPLETED' -- переходим на следующее окно
where application_id = 1;









