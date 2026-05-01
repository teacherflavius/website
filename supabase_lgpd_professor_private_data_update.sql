-- LGPD: atualização das funções administrativas do professor
-- Execute este arquivo depois de supabase_lgpd_private_student_data.sql.
-- Objetivo: fazer a área do professor ler/escrever CPF, WhatsApp e PIX em student_private_data.

create or replace function public.get_teacher_students()
returns table (
  id text,
  user_id text,
  name text,
  email text,
  cpf text,
  whatsapp text,
  pix_key text,
  enrollment_code text,
  enrolled boolean,
  availability jsonb,
  source text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  requester_email text;
begin
  requester_email := auth.jwt() ->> 'email';

  if requester_email is null or not exists (
    select 1 from public.teacher_admins ta
    where lower(ta.email) = lower(requester_email)
  ) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  return query
  with profile_rows as (
    select
      p.id::uuid as uid,
      p.id::text as id,
      p.id::text as user_id,
      coalesce(p.name, '')::text as name,
      coalesce(p.email, '')::text as email,
      coalesce(spd.cpf, p.cpf, '')::text as cpf,
      coalesce(spd.whatsapp, p.whatsapp, '')::text as whatsapp,
      coalesce(spd.pix_key, p.pix_key, '')::text as pix_key,
      coalesce(p.enrollment_code, '')::text as enrollment_code,
      coalesce(p.enrolled, false)::boolean as enrolled,
      coalesce(p.availability::jsonb, '{}'::jsonb) as availability,
      'profiles'::text as source,
      null::timestamptz as created_at
    from public.profiles p
    left join public.student_private_data spd on spd.user_id = p.id
  ),
  auth_rows as (
    select
      u.id::uuid as uid,
      u.id::text as id,
      u.id::text as user_id,
      coalesce(u.raw_user_meta_data ->> 'name', '')::text as name,
      coalesce(u.email, '')::text as email,
      coalesce(spd.cpf, '')::text as cpf,
      coalesce(spd.whatsapp, '')::text as whatsapp,
      coalesce(spd.pix_key, '')::text as pix_key,
      coalesce(u.raw_user_meta_data ->> 'enrollment_code', '')::text as enrollment_code,
      coalesce((u.raw_user_meta_data ->> 'enrolled')::boolean, false)::boolean as enrolled,
      coalesce(u.raw_user_meta_data -> 'availability', '{}'::jsonb) as availability,
      'auth.users'::text as source,
      u.created_at as created_at
    from auth.users u
    left join public.student_private_data spd on spd.user_id = u.id
    where not exists (
      select 1 from public.teacher_admins ta
      where lower(ta.email) = lower(u.email)
    )
  ),
  merged_rows as (
    select * from profile_rows
    union all
    select * from auth_rows ar
    where not exists (
      select 1 from profile_rows pr
      where pr.uid = ar.uid
    )
  )
  select
    mr.id,
    mr.user_id,
    mr.name,
    mr.email,
    mr.cpf,
    mr.whatsapp,
    mr.pix_key,
    mr.enrollment_code,
    mr.enrolled,
    mr.availability,
    mr.source,
    mr.created_at
  from merged_rows mr
  where not exists (
    select 1 from public.teacher_admins ta
    where lower(ta.email) = lower(mr.email)
  )
  order by mr.name asc nulls last, mr.email asc nulls last;
end;
$$;

grant execute on function public.get_teacher_students() to authenticated;

create or replace function public.update_teacher_student_profile(
  target_user_id uuid,
  target_name text,
  target_email text,
  target_cpf text,
  target_whatsapp text,
  target_pix_key text,
  target_enrollment_code text,
  target_availability jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  requester_email text;
begin
  requester_email := auth.jwt() ->> 'email';

  if requester_email is null or not exists (
    select 1 from public.teacher_admins ta
    where lower(ta.email) = lower(requester_email)
  ) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if exists (
    select 1 from public.teacher_admins ta
    join auth.users u on lower(u.email) = lower(ta.email)
    where u.id = target_user_id
  ) then
    raise exception 'Não é permitido editar uma conta de professor por esta tela.';
  end if;

  if coalesce(trim(target_name), '') = '' then
    raise exception 'Informe o nome do aluno.';
  end if;

  if coalesce(trim(target_email), '') = '' then
    raise exception 'Informe o e-mail do aluno.';
  end if;

  if length(regexp_replace(coalesce(target_cpf, ''), '\\D', '', 'g')) <> 11 then
    raise exception 'CPF inválido.';
  end if;

  if length(regexp_replace(coalesce(target_whatsapp, ''), '\\D', '', 'g')) < 10 then
    raise exception 'WhatsApp inválido.';
  end if;

  insert into public.profiles (
    id,
    name,
    email,
    enrollment_code,
    enrolled,
    availability,
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
    target_user_id,
    trim(target_name),
    trim(target_email),
    trim(coalesce(target_enrollment_code, '')),
    true,
    coalesce(target_availability, '{}'::jsonb),
    coalesce((target_availability -> 'seg') ? '09', false),
    coalesce((target_availability -> 'seg') ? '10', false),
    coalesce((target_availability -> 'seg') ? '12', false),
    coalesce((target_availability -> 'seg') ? '13', false),
    coalesce((target_availability -> 'seg') ? '15', false),
    coalesce((target_availability -> 'seg') ? '17', false),
    coalesce((target_availability -> 'seg') ? '18', false),
    coalesce((target_availability -> 'seg') ? '20', false),
    coalesce((target_availability -> 'seg') ? '21', false),
    coalesce((target_availability -> 'ter') ? '09', false),
    coalesce((target_availability -> 'ter') ? '10', false),
    coalesce((target_availability -> 'ter') ? '12', false),
    coalesce((target_availability -> 'ter') ? '13', false),
    coalesce((target_availability -> 'ter') ? '15', false),
    coalesce((target_availability -> 'ter') ? '17', false),
    coalesce((target_availability -> 'ter') ? '18', false),
    coalesce((target_availability -> 'ter') ? '20', false),
    coalesce((target_availability -> 'ter') ? '21', false),
    coalesce((target_availability -> 'qua') ? '09', false),
    coalesce((target_availability -> 'qua') ? '10', false),
    coalesce((target_availability -> 'qua') ? '12', false),
    coalesce((target_availability -> 'qua') ? '13', false),
    coalesce((target_availability -> 'qua') ? '15', false),
    coalesce((target_availability -> 'qua') ? '17', false),
    coalesce((target_availability -> 'qua') ? '18', false),
    coalesce((target_availability -> 'qua') ? '20', false),
    coalesce((target_availability -> 'qua') ? '21', false),
    coalesce((target_availability -> 'qui') ? '09', false),
    coalesce((target_availability -> 'qui') ? '10', false),
    coalesce((target_availability -> 'qui') ? '12', false),
    coalesce((target_availability -> 'qui') ? '13', false),
    coalesce((target_availability -> 'qui') ? '15', false),
    coalesce((target_availability -> 'qui') ? '17', false),
    coalesce((target_availability -> 'qui') ? '18', false),
    coalesce((target_availability -> 'qui') ? '20', false),
    coalesce((target_availability -> 'qui') ? '21', false),
    coalesce((target_availability -> 'sex') ? '09', false),
    coalesce((target_availability -> 'sex') ? '10', false),
    coalesce((target_availability -> 'sex') ? '12', false),
    coalesce((target_availability -> 'sex') ? '13', false),
    coalesce((target_availability -> 'sex') ? '15', false),
    coalesce((target_availability -> 'sex') ? '17', false),
    coalesce((target_availability -> 'sex') ? '18', false),
    coalesce((target_availability -> 'sex') ? '20', false),
    coalesce((target_availability -> 'sex') ? '21', false)
  )
  on conflict (id) do update
  set
    name = excluded.name,
    email = excluded.email,
    enrollment_code = excluded.enrollment_code,
    enrolled = true,
    availability = excluded.availability,
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

  insert into public.student_private_data (user_id, cpf, whatsapp, pix_key, consent_lgpd, consent_lgpd_at)
  values (
    target_user_id,
    regexp_replace(coalesce(target_cpf, ''), '\\D', '', 'g'),
    regexp_replace(coalesce(target_whatsapp, ''), '\\D', '', 'g'),
    trim(coalesce(target_pix_key, '')),
    true,
    now()
  )
  on conflict (user_id) do update
  set
    cpf = excluded.cpf,
    whatsapp = excluded.whatsapp,
    pix_key = excluded.pix_key,
    consent_lgpd = true,
    consent_lgpd_at = coalesce(public.student_private_data.consent_lgpd_at, now()),
    updated_at = now();

  update auth.users
  set
    email = trim(target_email),
    raw_user_meta_data = (
      coalesce(raw_user_meta_data, '{}'::jsonb)
      - 'cpf'
      - 'whatsapp'
      - 'pix_key'
    ) || jsonb_build_object(
      'name', trim(target_name),
      'enrollment_code', trim(coalesce(target_enrollment_code, '')),
      'enrolled', true,
      'availability', coalesce(target_availability, '{}'::jsonb)
    ),
    updated_at = now()
  where id = target_user_id;

  return jsonb_build_object('ok', true, 'user_id', target_user_id);
end;
$$;

grant execute on function public.update_teacher_student_profile(uuid, text, text, text, text, text, text, jsonb) to authenticated;
