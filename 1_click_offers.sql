
-- Источники
drop table if exists sources CASCADE;
CREATE TABLE sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_name VARCHAR NOT NULL UNIQUE,
    priority INTEGER NOT NULL,
    acceptable_attributes JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица attribute_meta
drop table if exists attribute_meta CASCADE;
CREATE TABLE attribute_meta (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attr_name VARCHAR NOT NULL UNIQUE,
    update_policy VARCHAR NOT NULL,
    history_policy JSONB NOT NULL,
    expiration_policy INTEGER NOT NULL, -- в днях
    put_storages JSONB NOT NULL,
    read_storages JSONB NOT NULL,
    data_type VARCHAR NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица attribute_data
drop table if exists attribute_data CASCADE;
CREATE TABLE attribute_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES sources(id),
    user_id UUID NOT NULL,
    attr_name VARCHAR NOT NULL,
    attr_meta_id UUID NOT NULL REFERENCES attribute_meta(id),
    data BYTEA NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Вставим источники
INSERT INTO sources (source_name, priority, acceptable_attributes)
VALUES
('service_db', 1, '["email", "phone", "first_name", "address"]'),
('partner_API', 2, '["CURP", "RFC", "Occupation"]');

-- Вставим мета-описания атрибутов
INSERT INTO attribute_meta (
    attr_name, update_policy, history_policy, expiration_policy,
    put_storages, read_storages, data_type
)
VALUES
('email', 'append', '{"keep_history": false}', 365,
 '["s3", "DWH"]', '["Bi reporting", "Bloomreach"]', 'string'),

('phone', 'append', '{"keep_history": false}', 180,
 '["s3", "DWH"]', '["support"]', 'string'),

('birthday', 'overwrite', '{"keep_history": true}', 730,
 '["s3", "DWH"]', '["Bi reporting"]', 'date');

-- Получим ID вставленных сущностей для связи
-- (В реальной жизни можно использовать RETURNING или заранее зафиксировать UUIDs)
-- Пример ниже с фиксированными UUID для наглядности

-- Пример с UUID (замените на реальные ID, если нужно)
INSERT INTO attribute_data (
    source_id, user_id, attr_name, attr_meta_id, data
)
SELECT
    s.id,
    '00000000-0000-0000-0000-000000000001'::UUID,
    am.attr_name,
    am.id,
    convert_to('pablo_escobar@gmail.com', 'UTF8')
FROM sources s, attribute_meta am
WHERE 1=1
    and s.source_name = 'service_db'
    AND am.attr_name = 'email'
LIMIT 1;

-- Добавим телефон
INSERT INTO attribute_data (
    source_id, user_id, attr_name, attr_meta_id, data
)
SELECT
    s.id,
    '00000000-0000-0000-0000-000000000001'::UUID,
    am.attr_name,
    am.id,
    convert_to('+525594357630', 'UTF8')
FROM sources s, attribute_meta am
WHERE 1=1
    and s.source_name = 'service_db'
    AND am.attr_name = 'phone'
LIMIT 1;


--------------------
select * from sources;
select * from attribute_meta;
select * from attribute_data;
--------------------
select
    t1.*, t2.expiration_policy
from attribute_data t1
join attribute_meta t2
    on t1.attr_meta_id = t2.id


/Users/vladislavseliutin/Library/Application Support/JetBrains/DataGrip2024.3/consoles/db/b4446a05-6878-47a4-a2f0-0dcf7c6dfb85/console_1.sql