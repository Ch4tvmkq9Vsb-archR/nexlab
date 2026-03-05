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
  cc_id uuid not null references cc(id),
  test_type varchar(3) not null references test_types(code),
  last_seq integer not null default 0,
  created_at timestamptz default now(),
  unique(cc_id, test_type)
);
-- ============================
-- Gerador de protocolo NexLab
-- CCC-XXX-0001 (sequencial por CC + tipo)
-- ============================

-- Função que cria um ensaio já com protocolo gerado
create or replace function create_test_with_protocol(
  p_cc_id uuid,
  p_test_type varchar(3),
  p_os_id uuid default null
)
returns uuid
language plpgsql
as $$
declare
  v_cc_code varchar(3);
  v_next_seq integer;
  v_protocol text;
  v_test_id uuid;
begin
  -- 1) Busca o CCC da obra
  select code into v_cc_code
  from cc
  where id = p_cc_id;

  if v_cc_code is null then
    raise exception 'CC inválido';
  end if;

  -- 2) Garante que existe linha no contador
  insert into cc_test_counters (cc_id, test_type, last_seq)
  values (p_cc_id, p_test_type, 0)
  on conflict (cc_id, test_type) do nothing;

  -- 3) TRAVA a linha do contador (evita duplicidade em concorrência)
  select last_seq into v_next_seq
  from cc_test_counters
  where cc_id = p_cc_id and test_type = p_test_type
  for update;

  -- 4) Incrementa e grava
  v_next_seq := v_next_seq + 1;

  update cc_test_counters
  set last_seq = v_next_seq
  where cc_id = p_cc_id and test_type = p_test_type;

  -- 5) Monta protocolo (4 dígitos)
  v_protocol := v_cc_code || '-' || p_test_type || '-' || lpad(v_next_seq::text, 4, '0');

  -- 6) Cria o ensaio
  insert into tests (cc_id, os_id, test_type, protocol, seq, created_at)
  values (p_cc_id, p_os_id, p_test_type, v_protocol, v_next_seq, now())
  returning id into v_test_id;

  return v_test_id;
end;
$$;

-- (Opcional) Índices/garantias recomendadas para evitar duplicidade
create unique index if not exists uq_tests_protocol on tests(protocol);
create unique index if not exists uq_tests_cc_type_seq on tests(cc_id, test_type, seq);