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
set search_path = public
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
  select
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
  order by p.name asc nulls last;
end;
$$;

grant execute on function public.get_teacher_students() to authenticated;
