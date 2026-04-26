-- Execute este script no Supabase SQL Editor.
-- Ele adiciona à tabela public.profiles os campos usados pela matrícula.

alter table public.profiles
  add column if not exists cpf text,
  add column if not exists whatsapp text,
  add column if not exists pix_key text,
  add column if not exists availability jsonb not null default '{}'::jsonb,
  add column if not exists enrollment_code text,
  add column if not exists enrolled boolean not null default false,
  add column if not exists availability_seg_09 boolean not null default false,
  add column if not exists availability_seg_10 boolean not null default false,
  add column if not exists availability_seg_12 boolean not null default false,
  add column if not exists availability_seg_13 boolean not null default false,
  add column if not exists availability_seg_15 boolean not null default false,
  add column if not exists availability_seg_17 boolean not null default false,
  add column if not exists availability_seg_18 boolean not null default false,
  add column if not exists availability_seg_20 boolean not null default false,
  add column if not exists availability_seg_21 boolean not null default false,
  add column if not exists availability_ter_09 boolean not null default false,
  add column if not exists availability_ter_10 boolean not null default false,
  add column if not exists availability_ter_12 boolean not null default false,
  add column if not exists availability_ter_13 boolean not null default false,
  add column if not exists availability_ter_15 boolean not null default false,
  add column if not exists availability_ter_17 boolean not null default false,
  add column if not exists availability_ter_18 boolean not null default false,
  add column if not exists availability_ter_20 boolean not null default false,
  add column if not exists availability_ter_21 boolean not null default false,
  add column if not exists availability_qua_09 boolean not null default false,
  add column if not exists availability_qua_10 boolean not null default false,
  add column if not exists availability_qua_12 boolean not null default false,
  add column if not exists availability_qua_13 boolean not null default false,
  add column if not exists availability_qua_15 boolean not null default false,
  add column if not exists availability_qua_17 boolean not null default false,
  add column if not exists availability_qua_18 boolean not null default false,
  add column if not exists availability_qua_20 boolean not null default false,
  add column if not exists availability_qua_21 boolean not null default false,
  add column if not exists availability_qui_09 boolean not null default false,
  add column if not exists availability_qui_10 boolean not null default false,
  add column if not exists availability_qui_12 boolean not null default false,
  add column if not exists availability_qui_13 boolean not null default false,
  add column if not exists availability_qui_15 boolean not null default false,
  add column if not exists availability_qui_17 boolean not null default false,
  add column if not exists availability_qui_18 boolean not null default false,
  add column if not exists availability_qui_20 boolean not null default false,
  add column if not exists availability_qui_21 boolean not null default false,
  add column if not exists availability_sex_09 boolean not null default false,
  add column if not exists availability_sex_10 boolean not null default false,
  add column if not exists availability_sex_12 boolean not null default false,
  add column if not exists availability_sex_13 boolean not null default false,
  add column if not exists availability_sex_15 boolean not null default false,
  add column if not exists availability_sex_17 boolean not null default false,
  add column if not exists availability_sex_18 boolean not null default false,
  add column if not exists availability_sex_20 boolean not null default false,
  add column if not exists availability_sex_21 boolean not null default false;

-- Opcional: impede códigos de matrícula duplicados quando o campo estiver preenchido.
create unique index if not exists profiles_enrollment_code_unique
  on public.profiles (enrollment_code)
  where enrollment_code is not null;

-- Opcional: busca mais rápida por CPF, WhatsApp, chave PIX e disponibilidade JSON.
create index if not exists profiles_cpf_idx
  on public.profiles (cpf);

create index if not exists profiles_whatsapp_idx
  on public.profiles (whatsapp);

create index if not exists profiles_pix_key_idx
  on public.profiles (pix_key);

create index if not exists profiles_availability_gin_idx
  on public.profiles using gin (availability);
