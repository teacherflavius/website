-- Integra pré-matrículas com Perfil dos Alunos, Turmas e Frequência.
-- Execute no Supabase depois de executar:
-- 1) supabase_professor_admin.sql
-- 2) supabase_turmas.sql
-- 3) supabase_pre_matriculas.sql

-- Permite que uma turma tenha alunos com conta (user_id) e pré-matriculados ainda sem conta (invite_id).
alter table public.class_students
  alter column user_id drop not null;

alter table public.class_students
  add column if not exists invite_id uuid references public.student_enrollment_invites(id) on delete cascade;

create unique index if not exists class_students_class_invite_unique_idx
  on public.class_students(class_number, invite_id)
  where invite_id is not null;

create index if not exists class_students_invite_id_idx
  on public.class_students(invite_id);

-- Permite registrar frequência/atividade para pré-matriculados.
alter table public.student_frequency
  alter column user_id drop not null;

alter table public.student_frequency
  add column if not exists invite_id uuid references public.student_enrollment_invites(id) on delete cascade;

create index if not exists student_frequency_invite_id_idx
  on public.student_frequency(invite_id);

-- Substitui a função de listagem administrativa para incluir pré-matriculados pendentes.
drop function if exists public.get_teacher_students();

create function public.get_teacher_students()
returns table (
  id text,
  user_id text,
  invite_id text,
  student_ref_id text,
  student_ref_type text,
  name text,
  email text,
  cpf text,
  whatsapp text,
  pix_key text,
  enrollment_code text,
  enrolled boolean,
  availability jsonb,
  source text,
  pre_enrollment_status text,
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
      p.id::text as id,
      p.id::text as user_id,
      null::text as invite_id,
      p.id::text as student_ref_id,
      'user'::text as student_ref_type,
      coalesce(p.name, '')::text as name,
      coalesce(p.email, '')::text as email,
      coalesce(p.cpf, '')::text as cpf,
      coalesce(p.whatsapp, '')::text as whatsapp,
      coalesce(p.pix_key, '')::text as pix_key,
      coalesce(p.enrollment_code, '')::text as enrollment_code,
      coalesce(p.enrolled, false)::boolean as enrolled,
      coalesce(p.availability::jsonb, '{}'::jsonb) as availability,
      'profiles'::text as source,
      'completed'::text as pre_enrollment_status,
      null::timestamptz as created_at
    from public.profiles p
  ),
  auth_rows as (
    select
      u.id::text as id,
      u.id::text as user_id,
      null::text as invite_id,
      u.id::text as student_ref_id,
      'user'::text as student_ref_type,
      coalesce(u.raw_user_meta_data ->> 'name', '')::text as name,
      coalesce(u.email, '')::text as email,
      coalesce(u.raw_user_meta_data ->> 'cpf', '')::text as cpf,
      coalesce(u.raw_user_meta_data ->> 'whatsapp', '')::text as whatsapp,
      coalesce(u.raw_user_meta_data ->> 'pix_key', '')::text as pix_key,
      coalesce(u.raw_user_meta_data ->> 'enrollment_code', '')::text as enrollment_code,
      coalesce((u.raw_user_meta_data ->> 'enrolled')::boolean, false)::boolean as enrolled,
      coalesce(u.raw_user_meta_data -> 'availability', '{}'::jsonb) as availability,
      'auth.users'::text as source,
      'completed'::text as pre_enrollment_status,
      u.created_at as created_at
    from auth.users u
    where not exists (
      select 1 from public.teacher_admins ta
      where lower(ta.email) = lower(u.email)
    )
  ),
  invite_rows as (
    select
      sei.id::text as id,
      sei.user_id::text as user_id,
      sei.id::text as invite_id,
      coalesce(sei.user_id::text, sei.id::text) as student_ref_id,
      case when sei.user_id is null then 'invite' else 'user' end::text as student_ref_type,
      coalesce(sei.student_name, '')::text as name,
      coalesce(sei.email, '')::text as email,
      coalesce(sei.cpf, '')::text as cpf,
      coalesce(sei.whatsapp, '')::text as whatsapp,
      coalesce(sei.pix_key, '')::text as pix_key,
      coalesce(sei.invite_code, '')::text as enrollment_code,
      (sei.status = 'completed')::boolean as enrolled,
      coalesce(sei.availability, '{}'::jsonb) as availability,
      'student_enrollment_invites'::text as source,
      sei.status::text as pre_enrollment_status,
      sei.created_at
    from public.student_enrollment_invites sei
    where sei.status in ('pending', 'completed')
      and not exists (
        select 1 from public.profiles p
        where p.id = sei.user_id
      )
  ),
  merged_rows as (
    select * from profile_rows
    union all
    select * from auth_rows ar
    where not exists (select 1 from profile_rows pr where pr.user_id = ar.user_id)
    union all
    select * from invite_rows
  )
  select
    mr.id,
    mr.user_id,
    mr.invite_id,
    mr.student_ref_id,
    mr.student_ref_type,
    mr.name,
    mr.email,
    mr.cpf,
    mr.whatsapp,
    mr.pix_key,
    mr.enrollment_code,
    mr.enrolled,
    mr.availability,
    mr.source,
    mr.pre_enrollment_status,
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

-- Contagem de turmas considerando alunos com conta e pré-matrículas.
create or replace function public.get_teacher_classes()
returns table (
  id text,
  class_number integer,
  class_name text,
  student_count integer,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  return query
  select
    tc.id::text,
    tc.class_number,
    tc.class_name,
    count(cs.id)::integer as student_count,
    tc.is_active,
    tc.created_at,
    tc.updated_at
  from public.teacher_classes tc
  left join public.class_students cs on cs.class_number = tc.class_number
  where tc.is_active = true
  group by tc.id, tc.class_number, tc.class_name, tc.is_active, tc.created_at, tc.updated_at
  order by tc.class_number asc;
end;
$$;

grant execute on function public.get_teacher_classes() to authenticated;

-- Lista alunos de uma turma, incluindo pré-matriculados.
create or replace function public.get_teacher_class_students(target_class_number integer)
returns table (
  id text,
  class_number integer,
  user_id text,
  invite_id text,
  student_ref_id text,
  student_ref_type text,
  student_name text,
  student_email text,
  enrollment_code text,
  pre_enrollment_status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  return query
  select
    cs.id::text,
    cs.class_number,
    cs.user_id::text,
    cs.invite_id::text,
    coalesce(cs.user_id::text, cs.invite_id::text) as student_ref_id,
    case when cs.user_id is not null then 'user' else 'invite' end::text as student_ref_type,
    coalesce(p.name, u.raw_user_meta_data ->> 'name', sei.student_name, u.email, 'Aluno sem nome')::text as student_name,
    coalesce(p.email, u.email, sei.email, '')::text as student_email,
    coalesce(p.enrollment_code, u.raw_user_meta_data ->> 'enrollment_code', sei.invite_code, '')::text as enrollment_code,
    coalesce(sei.status, case when cs.user_id is not null then 'completed' else 'pending' end)::text as pre_enrollment_status,
    cs.created_at
  from public.class_students cs
  left join public.profiles p on p.id = cs.user_id
  left join auth.users u on u.id = cs.user_id
  left join public.student_enrollment_invites sei on sei.id = cs.invite_id
  where cs.class_number = target_class_number
  order by student_name asc, student_email asc;
end;
$$;

grant execute on function public.get_teacher_class_students(integer) to authenticated;

-- Adiciona à turma por referência genérica: user:<uuid> ou invite:<uuid>.
create or replace function public.add_teacher_class_student_by_ref(
  target_class_number integer,
  target_student_ref_id text,
  target_student_ref_type text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  inserted_id uuid;
  target_user_id uuid;
  target_invite_id uuid;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  if target_student_ref_type = 'user' then
    target_user_id := target_student_ref_id::uuid;

    if not exists (
      select 1 from auth.users u
      left join public.profiles p on p.id = u.id
      where u.id = target_user_id
        and not exists (
          select 1 from public.teacher_admins ta
          where lower(ta.email) = lower(u.email)
        )
    ) then
      raise exception 'Aluno não encontrado.';
    end if;

    insert into public.class_students (class_number, user_id, invite_id)
    values (target_class_number, target_user_id, null)
    on conflict (class_number, user_id) do update
    set user_id = excluded.user_id
    returning id into inserted_id;

  elsif target_student_ref_type = 'invite' then
    target_invite_id := target_student_ref_id::uuid;

    if not exists (
      select 1 from public.student_enrollment_invites sei
      where sei.id = target_invite_id
        and sei.status in ('pending', 'completed')
    ) then
      raise exception 'Pré-matrícula não encontrada.';
    end if;

    insert into public.class_students (class_number, user_id, invite_id)
    values (target_class_number, null, target_invite_id)
    on conflict (class_number, invite_id) where invite_id is not null do update
    set invite_id = excluded.invite_id
    returning id into inserted_id;

  else
    raise exception 'Tipo de aluno inválido.';
  end if;

  return jsonb_build_object('ok', true, 'id', inserted_id);
end;
$$;

grant execute on function public.add_teacher_class_student_by_ref(integer, text, text) to authenticated;

create or replace function public.remove_teacher_class_student_by_ref(
  target_class_number integer,
  target_student_ref_id text,
  target_student_ref_type text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  if target_student_ref_type = 'user' then
    delete from public.class_students
    where class_number = target_class_number
      and user_id = target_student_ref_id::uuid;
  elsif target_student_ref_type = 'invite' then
    delete from public.class_students
    where class_number = target_class_number
      and invite_id = target_student_ref_id::uuid;
  else
    raise exception 'Tipo de aluno inválido.';
  end if;

  if not found then
    raise exception 'Aluno não encontrado nesta turma.';
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.remove_teacher_class_student_by_ref(integer, text, text) to authenticated;

-- Histórico com alunos matriculados e pré-matriculados.
create or replace function public.get_teacher_class_activity_history(target_class_number integer)
returns table (
  frequency_id text,
  class_number integer,
  user_id text,
  invite_id text,
  student_ref_id text,
  student_ref_type text,
  student_name text,
  student_email text,
  enrollment_code text,
  class_date date,
  attendance_status text,
  class_notes text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  return query
  select
    sf.id::text as frequency_id,
    cs.class_number,
    sf.user_id::text,
    sf.invite_id::text,
    coalesce(sf.user_id::text, sf.invite_id::text) as student_ref_id,
    case when sf.user_id is not null then 'user' else 'invite' end::text as student_ref_type,
    coalesce(p.name, u.raw_user_meta_data ->> 'name', sei.student_name, u.email, 'Aluno sem nome')::text as student_name,
    coalesce(p.email, u.email, sei.email, '')::text as student_email,
    coalesce(p.enrollment_code, u.raw_user_meta_data ->> 'enrollment_code', sei.invite_code, '')::text as enrollment_code,
    sf.class_date,
    sf.attendance_status,
    coalesce(sf.class_notes, '')::text as class_notes,
    sf.created_at,
    sf.updated_at
  from public.student_frequency sf
  join public.class_students cs
    on cs.class_number = target_class_number
   and (
     (sf.user_id is not null and cs.user_id = sf.user_id)
     or
     (sf.invite_id is not null and cs.invite_id = sf.invite_id)
   )
  left join public.profiles p on p.id = sf.user_id
  left join auth.users u on u.id = sf.user_id
  left join public.student_enrollment_invites sei on sei.id = coalesce(sf.invite_id, cs.invite_id)
  where sf.class_notes ilike ('[Turma ' || target_class_number || ']%')
  order by sf.class_date desc, sf.created_at desc, student_name asc;
end;
$$;

grant execute on function public.get_teacher_class_activity_history(integer) to authenticated;

create or replace function public.save_teacher_class_attendance_by_ref(
  target_class_number integer,
  target_class_date date,
  target_general_notes text,
  attendance_records jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  item jsonb;
  target_user_id uuid;
  target_invite_id uuid;
  target_ref_id text;
  target_ref_type text;
  target_status text;
  target_notes text;
  inserted_count integer := 0;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  if attendance_records is null or jsonb_array_length(attendance_records) = 0 then
    raise exception 'Nenhum aluno foi selecionado para registrar frequência.';
  end if;

  for item in select * from jsonb_array_elements(attendance_records)
  loop
    target_ref_id := item ->> 'student_ref_id';
    target_ref_type := item ->> 'student_ref_type';
    target_status := coalesce(item ->> 'attendance_status', 'Compareceu');
    target_notes := coalesce(nullif(item ->> 'class_notes', ''), target_general_notes, '');
    target_user_id := null;
    target_invite_id := null;

    if target_status not in ('Compareceu', 'Faltou') then
      raise exception 'Situação inválida para um dos alunos.';
    end if;

    if target_ref_type = 'user' then
      target_user_id := target_ref_id::uuid;
      if not exists (
        select 1 from public.class_students cs
        where cs.class_number = target_class_number
          and cs.user_id = target_user_id
      ) then
        raise exception 'Um dos alunos selecionados não pertence a esta turma.';
      end if;
    elsif target_ref_type = 'invite' then
      target_invite_id := target_ref_id::uuid;
      if not exists (
        select 1 from public.class_students cs
        where cs.class_number = target_class_number
          and cs.invite_id = target_invite_id
      ) then
        raise exception 'Uma das pré-matrículas selecionadas não pertence a esta turma.';
      end if;
    else
      raise exception 'Tipo de aluno inválido.';
    end if;

    insert into public.student_frequency (user_id, invite_id, class_date, attendance_status, class_notes)
    values (
      target_user_id,
      target_invite_id,
      target_class_date,
      target_status,
      '[Turma ' || target_class_number || '] ' || target_notes
    );

    inserted_count := inserted_count + 1;
  end loop;

  return jsonb_build_object('ok', true, 'inserted_count', inserted_count);
end;
$$;

grant execute on function public.save_teacher_class_attendance_by_ref(integer, date, text, jsonb) to authenticated;

-- Quando o aluno concluir o convite, migra automaticamente turma e frequência do invite_id para user_id.
create or replace function public.migrate_invite_records_to_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'completed' and new.user_id is not null then
    update public.class_students
    set user_id = new.user_id
    where invite_id = new.id
      and user_id is null;

    update public.student_frequency
    set user_id = new.user_id
    where invite_id = new.id
      and user_id is null;
  end if;

  return new;
end;
$$;

drop trigger if exists migrate_invite_records_to_user_trigger on public.student_enrollment_invites;
create trigger migrate_invite_records_to_user_trigger
  after update of status, user_id on public.student_enrollment_invites
  for each row
  execute function public.migrate_invite_records_to_user();
