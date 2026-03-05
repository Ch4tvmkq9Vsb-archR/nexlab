-- NexLab Initial Schema

create extension if not exists pgcrypto;

-- Empresas
create table companies (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 created_at timestamptz default now()
);

-- Centro de custo / obra
create table cc (
 id uuid primary key default gen_random_uuid(),
 company_id uuid references companies(id),
 code varchar(3) not null,
 name text not null,
 created_at timestamptz default now()
);

-- Tipos de ensaio
create table test_types (
 code varchar(3) primary key,
 name text not null
);

insert into test_types values
('COM','Compactação'),
('CBR','CBR'),
('GRA','Granulometria');

-- Ordem de serviço
create table os (
 id uuid primary key default gen_random_uuid(),
 cc_id uuid references cc(id),
 os_number text,
 created_at timestamptz default now()
);

-- Ensaios executados
create table tests (
 id uuid primary key default gen_random_uuid(),
 cc_id uuid references cc(id),
 os_id uuid references os(id),
 test_type varchar(3) references test_types(code),
 protocol text,
 seq integer,
 created_at timestamptz default now()
);
-- Controle de sequência de protocolos

create table cc_test_counters (
 id uuid primary key default gen_random_uuid(),
 cc_id uuid references cc(id),
 test_type varchar(3) references test_types(code),
 last_seq integer default 0,
 created_at timestamptz default now(),
 unique(cc_id, test_type)
);