-- Área administrativa do professor
-- Execute este arquivo no Supabase em SQL Editor > Run.
-- Substitua professor@email.com pelo e-mail usado pelo professor para login.

create table if not exists public.teacher_admins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  email text unique not null,
  created_at timestamptz not null default now()
);

alter table public.teacher_admins enable row level security;

drop policy if exists "Professor pode verificar suas próprias credenciais" on public.teacher_admins;
create policy "Professor pode verificar suas próprias credenciais"
  on public.teacher_admins
  for select
  using (lower(email) = lower(auth.jwt() ->> 'email'));

-- IMPORTANTE: troque professor@email.com pelo seu e-mail real de login antes de executar.
insert into public.teacher_admins (email)
values ('professor@email.com')
on conflict (email) do nothing;

alter table public.profiles enable row level security;

drop policy if exists "Professores podem visualizar alunos matriculados" on public.profiles;
drop policy if exists "Professores podem visualizar perfis" on public.profiles;
create policy "Professores podem visualizar perfis"
  on public.profiles
  for select
  using (
    exists (
      select 1 from public.teacher_admins ta
      where lower(ta.email) = lower(auth.jwt() ->> 'email')
    )
  );

create or replace function public.get_teacher_students()
returns table (
  id text,
  user_id text,
  name text,
  email text,
  cpf text,
  whatsapp text,
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
      coalesce(p.cpf, '')::text as cpf,
      coalesce(p.whatsapp, '')::text as whatsapp,
      coalesce(p.enrollment_code, '')::text as enrollment_code,
      coalesce(p.enrolled, false)::boolean as enrolled,
      coalesce(p.availability::jsonb, '{}'::jsonb) as availability,
      'profiles'::text as source,
      null::timestamptz as created_at
    from public.profiles p
  ),
  auth_rows as (
    select
      u.id::uuid as uid,
      u.id::text as id,
      u.id::text as user_id,
      coalesce(u.raw_user_meta_data ->> 'name', '')::text as name,
      coalesce(u.email, '')::text as email,
      coalesce(u.raw_user_meta_data ->> 'cpf', '')::text as cpf,
      coalesce(u.raw_user_meta_data ->> 'whatsapp', '')::text as whatsapp,
      coalesce(u.raw_user_meta_data ->> 'enrollment_code', '')::text as enrollment_code,
      coalesce((u.raw_user_meta_data ->> 'enrolled')::boolean, false)::boolean as enrolled,
      coalesce(u.raw_user_meta_data -> 'availability', '{}'::jsonb) as availability,
      'auth.users'::text as source,
      u.created_at as created_at
    from auth.users u
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

-- Função usada pelo botão EXCLUIR MATRÍCULA em professor.html.
-- Ela remove dados do aluno em profiles, student_frequency e activity_results quando existirem.
-- Também tenta remover o usuário de auth.users para apagar a conta de login.
create or replace function public.delete_teacher_student(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  requester_email text;
  deleted_profile_count integer := 0;
  deleted_frequency_count integer := 0;
  deleted_activity_count integer := 0;
  deleted_auth_count integer := 0;
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
    raise exception 'Não é permitido excluir uma conta de professor.';
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'student_frequency') then
    delete from public.student_frequency where user_id = target_user_id;
    get diagnostics deleted_frequency_count = row_count;
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'activity_results') then
    delete from public.activity_results where user_id = target_user_id;
    get diagnostics deleted_activity_count = row_count;
  end if;

  delete from public.profiles where id = target_user_id;
  get diagnostics deleted_profile_count = row_count;

  delete from auth.users where id = target_user_id;
  get diagnostics deleted_auth_count = row_count;

  return jsonb_build_object(
    'ok', true,
    'deleted_profile_count', deleted_profile_count,
    'deleted_frequency_count', deleted_frequency_count,
    'deleted_activity_count', deleted_activity_count,
    'deleted_auth_count', deleted_auth_count
  );
end;
$$;

grant execute on function public.delete_teacher_student(uuid) to authenticated;
