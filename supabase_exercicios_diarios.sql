-- Tabela para registrar os exercícios diários concluídos pelos alunos
-- Execute no Supabase em SQL Editor > Run.
-- Este arquivo também cria a função usada pela área do professor para visualizar exercícios feitos.

create table if not exists public.daily_exercise_completion (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_id text not null,
  exercise_title text not null,
  exercise_url text,
  completed boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, exercise_id)
);

create index if not exists daily_exercise_completion_user_id_idx
  on public.daily_exercise_completion(user_id);

create index if not exists daily_exercise_completion_exercise_id_idx
  on public.daily_exercise_completion(exercise_id);

alter table public.daily_exercise_completion enable row level security;

drop policy if exists "Alunos podem ver seus exercícios diários" on public.daily_exercise_completion;
create policy "Alunos podem ver seus exercícios diários"
  on public.daily_exercise_completion
  for select
  using (auth.uid() = user_id);

drop policy if exists "Alunos podem inserir seus exercícios diários" on public.daily_exercise_completion;
create policy "Alunos podem inserir seus exercícios diários"
  on public.daily_exercise_completion
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Alunos podem atualizar seus exercícios diários" on public.daily_exercise_completion;
create policy "Alunos podem atualizar seus exercícios diários"
  on public.daily_exercise_completion
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.set_daily_exercise_completion_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_daily_exercise_completion_updated_at on public.daily_exercise_completion;
create trigger set_daily_exercise_completion_updated_at
before update on public.daily_exercise_completion
for each row
execute function public.set_daily_exercise_completion_updated_at();

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

create or replace function public.get_teacher_daily_exercise_completion()
returns table (
  id text,
  user_id text,
  student_name text,
  student_email text,
  exercise_id text,
  exercise_title text,
  exercise_url text,
  completed boolean,
  completed_at timestamptz,
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

  return query
  select
    dec.id::text,
    dec.user_id::text,
    coalesce(p.name, u.raw_user_meta_data ->> 'name', u.email, 'Aluno sem nome')::text as student_name,
    coalesce(p.email, u.email, '')::text as student_email,
    dec.exercise_id,
    dec.exercise_title,
    coalesce(dec.exercise_url, '')::text as exercise_url,
    dec.completed,
    dec.completed_at,
    dec.updated_at
  from public.daily_exercise_completion dec
  left join public.profiles p on p.id = dec.user_id
  left join auth.users u on u.id = dec.user_id
  where dec.completed = true
    and not exists (
      select 1 from public.teacher_admins ta
      where lower(ta.email) = lower(coalesce(p.email, u.email, ''))
    )
    and (
      coalesce(p.enrolled, false) = true
      or coalesce(p.enrollment_code, '') <> ''
      or coalesce((u.raw_user_meta_data ->> 'enrolled')::boolean, false) = true
      or coalesce(u.raw_user_meta_data ->> 'enrollment_code', '') <> ''
    )
  order by student_name asc, dec.completed_at desc nulls last, dec.updated_at desc;
end;
$$;

grant execute on function public.get_teacher_daily_exercise_completion() to authenticated;
