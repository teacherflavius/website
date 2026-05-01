-- LGPD: dados privados dos alunos
-- Execute este arquivo no Supabase em SQL Editor > Run.
-- Objetivo: retirar CPF, WhatsApp e chave PIX de auth.user_metadata e separar dados privados do perfil público.

create table if not exists public.student_private_data (
  user_id uuid primary key references auth.users(id) on delete cascade,
  cpf text,
  whatsapp text,
  pix_key text,
  consent_lgpd boolean not null default false,
  consent_lgpd_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.student_private_data enable row level security;

create or replace function public.is_teacher_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.teacher_admins ta
    where lower(ta.email) = lower(auth.jwt() ->> 'email')
  );
$$;

drop policy if exists "Alunos podem visualizar seus próprios dados privados" on public.student_private_data;
create policy "Alunos podem visualizar seus próprios dados privados"
  on public.student_private_data
  for select
  using (auth.uid() = user_id);

drop policy if exists "Alunos podem inserir seus próprios dados privados" on public.student_private_data;
create policy "Alunos podem inserir seus próprios dados privados"
  on public.student_private_data
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Alunos podem atualizar seus próprios dados privados" on public.student_private_data;
create policy "Alunos podem atualizar seus próprios dados privados"
  on public.student_private_data
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Professores podem visualizar dados privados de alunos" on public.student_private_data;
create policy "Professores podem visualizar dados privados de alunos"
  on public.student_private_data
  for select
  using (public.is_teacher_admin());

create or replace function public.set_student_private_data_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_student_private_data_updated_at on public.student_private_data;
create trigger set_student_private_data_updated_at
before update on public.student_private_data
for each row
execute function public.set_student_private_data_updated_at();

create or replace function public.upsert_my_private_student_data(
  target_cpf text,
  target_whatsapp text,
  target_pix_key text,
  target_consent_lgpd boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_id uuid;
begin
  requester_id := auth.uid();

  if requester_id is null then
    raise exception 'Usuário não autenticado.';
  end if;

  if length(regexp_replace(coalesce(target_cpf, ''), '\\D', '', 'g')) <> 11 then
    raise exception 'CPF inválido.';
  end if;

  if length(regexp_replace(coalesce(target_whatsapp, ''), '\\D', '', 'g')) < 10 then
    raise exception 'WhatsApp inválido.';
  end if;

  if coalesce(trim(target_pix_key), '') = '' then
    raise exception 'Informe a chave PIX.';
  end if;

  insert into public.student_private_data (
    user_id,
    cpf,
    whatsapp,
    pix_key,
    consent_lgpd,
    consent_lgpd_at
  )
  values (
    requester_id,
    regexp_replace(coalesce(target_cpf, ''), '\\D', '', 'g'),
    regexp_replace(coalesce(target_whatsapp, ''), '\\D', '', 'g'),
    trim(target_pix_key),
    coalesce(target_consent_lgpd, false),
    case when coalesce(target_consent_lgpd, false) then now() else null end
  )
  on conflict (user_id) do update
  set
    cpf = excluded.cpf,
    whatsapp = excluded.whatsapp,
    pix_key = excluded.pix_key,
    consent_lgpd = excluded.consent_lgpd,
    consent_lgpd_at = case
      when excluded.consent_lgpd = true and public.student_private_data.consent_lgpd_at is null then now()
      when excluded.consent_lgpd = true then public.student_private_data.consent_lgpd_at
      else null
    end,
    updated_at = now();

  return jsonb_build_object('ok', true, 'user_id', requester_id);
end;
$$;

grant execute on function public.upsert_my_private_student_data(text, text, text, boolean) to authenticated;

create or replace function public.get_my_private_student_data()
returns table (
  cpf text,
  whatsapp text,
  pix_key text,
  consent_lgpd boolean,
  consent_lgpd_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    spd.cpf,
    spd.whatsapp,
    spd.pix_key,
    spd.consent_lgpd,
    spd.consent_lgpd_at,
    spd.updated_at
  from public.student_private_data spd
  where spd.user_id = auth.uid();
$$;

grant execute on function public.get_my_private_student_data() to authenticated;

-- Migração de dados já existentes em profiles para a tabela privada.
-- Depois de validar a migração, os campos cpf, whatsapp e pix_key podem ser removidos gradualmente de profiles.
insert into public.student_private_data (user_id, cpf, whatsapp, pix_key, consent_lgpd, consent_lgpd_at)
select
  p.id,
  nullif(regexp_replace(coalesce(p.cpf, ''), '\\D', '', 'g'), ''),
  nullif(regexp_replace(coalesce(p.whatsapp, ''), '\\D', '', 'g'), ''),
  nullif(trim(coalesce(p.pix_key, '')), ''),
  true,
  now()
from public.profiles p
where p.id is not null
  and (
    coalesce(p.cpf, '') <> ''
    or coalesce(p.whatsapp, '') <> ''
    or coalesce(p.pix_key, '') <> ''
  )
on conflict (user_id) do update
set
  cpf = coalesce(excluded.cpf, public.student_private_data.cpf),
  whatsapp = coalesce(excluded.whatsapp, public.student_private_data.whatsapp),
  pix_key = coalesce(excluded.pix_key, public.student_private_data.pix_key),
  consent_lgpd = true,
  consent_lgpd_at = coalesce(public.student_private_data.consent_lgpd_at, now()),
  updated_at = now();

-- Limpeza opcional do metadata legado em auth.users.
-- Recomendado executar após confirmar que student_private_data foi populada corretamente.
update auth.users
set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
  - 'cpf'
  - 'whatsapp'
  - 'pix_key'
where raw_user_meta_data ?| array['cpf', 'whatsapp', 'pix_key'];
