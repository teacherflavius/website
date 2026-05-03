-- Pré-matrículas por convite
-- Execute este arquivo no Supabase em SQL Editor > Run.
-- Este script depende da tabela public.teacher_admins e da função public.is_teacher_admin().

create table if not exists public.student_enrollment_invites (
  id uuid primary key default gen_random_uuid(),
  invite_code text unique not null,
  student_name text not null,
  notes text,
  status text not null default 'pending' check (status in ('pending', 'completed', 'cancelled', 'expired')),
  user_id uuid references auth.users(id) on delete set null,
  email text,
  cpf text,
  whatsapp text,
  pix_key text,
  availability jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  expires_at timestamptz
);

alter table public.student_enrollment_invites enable row level security;

drop policy if exists "Professores podem visualizar convites de matricula" on public.student_enrollment_invites;
create policy "Professores podem visualizar convites de matricula"
  on public.student_enrollment_invites
  for select
  to authenticated
  using (public.is_teacher_admin());

drop policy if exists "Professores podem criar convites de matricula" on public.student_enrollment_invites;
create policy "Professores podem criar convites de matricula"
  on public.student_enrollment_invites
  for insert
  to authenticated
  with check (public.is_teacher_admin());

drop policy if exists "Professores podem atualizar convites de matricula" on public.student_enrollment_invites;
create policy "Professores podem atualizar convites de matricula"
  on public.student_enrollment_invites
  for update
  to authenticated
  using (public.is_teacher_admin())
  with check (public.is_teacher_admin());

drop policy if exists "Professores podem excluir convites de matricula" on public.student_enrollment_invites;
create policy "Professores podem excluir convites de matricula"
  on public.student_enrollment_invites
  for delete
  to authenticated
  using (public.is_teacher_admin());

create index if not exists student_enrollment_invites_code_idx
  on public.student_enrollment_invites (invite_code);

create index if not exists student_enrollment_invites_status_idx
  on public.student_enrollment_invites (status);

create or replace function public.get_enrollment_invite_by_code(target_invite_code text)
returns table (
  invite_code text,
  student_name text,
  status text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    sei.invite_code,
    sei.student_name,
    sei.status,
    sei.expires_at
  from public.student_enrollment_invites sei
  where upper(sei.invite_code) = upper(trim(target_invite_code))
    and sei.status = 'pending'
    and (sei.expires_at is null or sei.expires_at > now())
  limit 1;
end;
$$;

grant execute on function public.get_enrollment_invite_by_code(text) to authenticated;

create or replace function public.complete_enrollment_invite(
  target_invite_code text,
  target_name text,
  target_cpf text,
  target_whatsapp text,
  target_pix_key text,
  target_availability jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  invite_row public.student_enrollment_invites%rowtype;
  requester_user_id uuid;
  requester_email text;
  clean_cpf text;
  clean_whatsapp text;
  normalized_availability jsonb;
  enrollment_code text;
begin
  requester_user_id := auth.uid();
  requester_email := auth.jwt() ->> 'email';

  if requester_user_id is null then
    raise exception 'Usuário não autenticado.';
  end if;

  select * into invite_row
  from public.student_enrollment_invites
  where upper(invite_code) = upper(trim(target_invite_code))
  limit 1;

  if invite_row.id is null then
    raise exception 'Código de convite inválido.';
  end if;

  if invite_row.status <> 'pending' then
    raise exception 'Este convite não está mais disponível.';
  end if;

  if invite_row.expires_at is not null and invite_row.expires_at <= now() then
    update public.student_enrollment_invites
    set status = 'expired'
    where id = invite_row.id;
    raise exception 'Este convite expirou.';
  end if;

  clean_cpf := regexp_replace(coalesce(target_cpf, ''), '\D', '', 'g');
  clean_whatsapp := regexp_replace(coalesce(target_whatsapp, ''), '\D', '', 'g');
  normalized_availability := coalesce(target_availability, '{}'::jsonb);
  enrollment_code := invite_row.invite_code;

  if coalesce(trim(target_name), '') = '' then
    raise exception 'Informe o nome completo.';
  end if;

  if clean_cpf is null or length(clean_cpf) <> 11 then
    raise exception 'CPF inválido.';
  end if;

  if clean_whatsapp is null or length(clean_whatsapp) < 10 then
    raise exception 'WhatsApp inválido.';
  end if;

  if coalesce(trim(target_pix_key), '') = '' then
    raise exception 'Informe a chave PIX.';
  end if;

  insert into public.profiles (
    id,
    name,
    email,
    cpf,
    whatsapp,
    pix_key,
    availability,
    enrollment_code,
    enrolled,
    availability_seg_09,
    availability_seg_10,
    availability_seg_12,
    availability_seg_13,
    availability_seg_15,
    availability_seg_17,
    availability_seg_18,
    availability_seg_20,
    availability_seg_21,
    availability_ter_09,
    availability_ter_10,
    availability_ter_12,
    availability_ter_13,
    availability_ter_15,
    availability_ter_17,
    availability_ter_18,
    availability_ter_20,
    availability_ter_21,
    availability_qua_09,
    availability_qua_10,
    availability_qua_12,
    availability_qua_13,
    availability_qua_15,
    availability_qua_17,
    availability_qua_18,
    availability_qua_20,
    availability_qua_21,
    availability_qui_09,
    availability_qui_10,
    availability_qui_12,
    availability_qui_13,
    availability_qui_15,
    availability_qui_17,
    availability_qui_18,
    availability_qui_20,
    availability_qui_21,
    availability_sex_09,
    availability_sex_10,
    availability_sex_12,
    availability_sex_13,
    availability_sex_15,
    availability_sex_17,
    availability_sex_18,
    availability_sex_20,
    availability_sex_21
  )
  values (
    requester_user_id,
    trim(target_name),
    requester_email,
    clean_cpf,
    clean_whatsapp,
    trim(target_pix_key),
    normalized_availability,
    enrollment_code,
    true,
    coalesce((normalized_availability -> 'seg') ? '09', false),
    coalesce((normalized_availability -> 'seg') ? '10', false),
    coalesce((normalized_availability -> 'seg') ? '12', false),
    coalesce((normalized_availability -> 'seg') ? '13', false),
    coalesce((normalized_availability -> 'seg') ? '15', false),
    coalesce((normalized_availability -> 'seg') ? '17', false),
    coalesce((normalized_availability -> 'seg') ? '18', false),
    coalesce((normalized_availability -> 'seg') ? '20', false),
    coalesce((normalized_availability -> 'seg') ? '21', false),
    coalesce((normalized_availability -> 'ter') ? '09', false),
    coalesce((normalized_availability -> 'ter') ? '10', false),
    coalesce((normalized_availability -> 'ter') ? '12', false),
    coalesce((normalized_availability -> 'ter') ? '13', false),
    coalesce((normalized_availability -> 'ter') ? '15', false),
    coalesce((normalized_availability -> 'ter') ? '17', false),
    coalesce((normalized_availability -> 'ter') ? '18', false),
    coalesce((normalized_availability -> 'ter') ? '20', false),
    coalesce((normalized_availability -> 'ter') ? '21', false),
    coalesce((normalized_availability -> 'qua') ? '09', false),
    coalesce((normalized_availability -> 'qua') ? '10', false),
    coalesce((normalized_availability -> 'qua') ? '12', false),
    coalesce((normalized_availability -> 'qua') ? '13', false),
    coalesce((normalized_availability -> 'qua') ? '15', false),
    coalesce((normalized_availability -> 'qua') ? '17', false),
    coalesce((normalized_availability -> 'qua') ? '18', false),
    coalesce((normalized_availability -> 'qua') ? '20', false),
    coalesce((normalized_availability -> 'qua') ? '21', false),
    coalesce((normalized_availability -> 'qui') ? '09', false),
    coalesce((normalized_availability -> 'qui') ? '10', false),
    coalesce((normalized_availability -> 'qui') ? '12', false),
    coalesce((normalized_availability -> 'qui') ? '13', false),
    coalesce((normalized_availability -> 'qui') ? '15', false),
    coalesce((normalized_availability -> 'qui') ? '17', false),
    coalesce((normalized_availability -> 'qui') ? '18', false),
    coalesce((normalized_availability -> 'qui') ? '20', false),
    coalesce((normalized_availability -> 'qui') ? '21', false),
    coalesce((normalized_availability -> 'sex') ? '09', false),
    coalesce((normalized_availability -> 'sex') ? '10', false),
    coalesce((normalized_availability -> 'sex') ? '12', false),
    coalesce((normalized_availability -> 'sex') ? '13', false),
    coalesce((normalized_availability -> 'sex') ? '15', false),
    coalesce((normalized_availability -> 'sex') ? '17', false),
    coalesce((normalized_availability -> 'sex') ? '18', false),
    coalesce((normalized_availability -> 'sex') ? '20', false),
    coalesce((normalized_availability -> 'sex') ? '21', false)
  )
  on conflict (id) do update
  set
    name = excluded.name,
    email = excluded.email,
    cpf = excluded.cpf,
    whatsapp = excluded.whatsapp,
    pix_key = excluded.pix_key,
    availability = excluded.availability,
    enrollment_code = excluded.enrollment_code,
    enrolled = true,
    availability_seg_09 = excluded.availability_seg_09,
    availability_seg_10 = excluded.availability_seg_10,
    availability_seg_12 = excluded.availability_seg_12,
    availability_seg_13 = excluded.availability_seg_13,
    availability_seg_15 = excluded.availability_seg_15,
    availability_seg_17 = excluded.availability_seg_17,
    availability_seg_18 = excluded.availability_seg_18,
    availability_seg_20 = excluded.availability_seg_20,
    availability_seg_21 = excluded.availability_seg_21,
    availability_ter_09 = excluded.availability_ter_09,
    availability_ter_10 = excluded.availability_ter_10,
    availability_ter_12 = excluded.availability_ter_12,
    availability_ter_13 = excluded.availability_ter_13,
    availability_ter_15 = excluded.availability_ter_15,
    availability_ter_17 = excluded.availability_ter_17,
    availability_ter_18 = excluded.availability_ter_18,
    availability_ter_20 = excluded.availability_ter_20,
    availability_ter_21 = excluded.availability_ter_21,
    availability_qua_09 = excluded.availability_qua_09,
    availability_qua_10 = excluded.availability_qua_10,
    availability_qua_12 = excluded.availability_qua_12,
    availability_qua_13 = excluded.availability_qua_13,
    availability_qua_15 = excluded.availability_qua_15,
    availability_qua_17 = excluded.availability_qua_17,
    availability_qua_18 = excluded.availability_qua_18,
    availability_qua_20 = excluded.availability_qua_20,
    availability_qua_21 = excluded.availability_qua_21,
    availability_qui_09 = excluded.availability_qui_09,
    availability_qui_10 = excluded.availability_qui_10,
    availability_qui_12 = excluded.availability_qui_12,
    availability_qui_13 = excluded.availability_qui_13,
    availability_qui_15 = excluded.availability_qui_15,
    availability_qui_17 = excluded.availability_qui_17,
    availability_qui_18 = excluded.availability_qui_18,
    availability_qui_20 = excluded.availability_qui_20,
    availability_qui_21 = excluded.availability_qui_21,
    availability_sex_09 = excluded.availability_sex_09,
    availability_sex_10 = excluded.availability_sex_10,
    availability_sex_12 = excluded.availability_sex_12,
    availability_sex_13 = excluded.availability_sex_13,
    availability_sex_15 = excluded.availability_sex_15,
    availability_sex_17 = excluded.availability_sex_17,
    availability_sex_18 = excluded.availability_sex_18,
    availability_sex_20 = excluded.availability_sex_20,
    availability_sex_21 = excluded.availability_sex_21;

  update auth.users
  set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
    'name', trim(target_name),
    'cpf', clean_cpf,
    'whatsapp', clean_whatsapp,
    'pix_key', trim(target_pix_key),
    'availability', normalized_availability,
    'enrollment_code', enrollment_code,
    'enrolled', true
  ),
  updated_at = now()
  where id = requester_user_id;

  update public.student_enrollment_invites
  set
    status = 'completed',
    user_id = requester_user_id,
    email = requester_email,
    cpf = clean_cpf,
    whatsapp = clean_whatsapp,
    pix_key = trim(target_pix_key),
    availability = normalized_availability,
    completed_at = now()
  where id = invite_row.id;

  return jsonb_build_object('ok', true, 'enrollment_code', enrollment_code);
end;
$$;

grant execute on function public.complete_enrollment_invite(text, text, text, text, text, jsonb) to authenticated;
