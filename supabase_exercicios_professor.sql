-- Exercícios criados pelo professor
-- Execute no Supabase em SQL Editor > Run.
-- Este arquivo pressupõe que teacher_admins já existe.

create table if not exists public.teacher_exercises (
  id uuid primary key default gen_random_uuid(),
  exercise_id text unique not null,
  exercise_title text not null,
  exercise_url text not null,
  created_by uuid references auth.users(id) on delete set null,
  is_active boolean not null default true,
  scheduled_publish_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.teacher_exercises
  add column if not exists scheduled_publish_at timestamptz;

create index if not exists teacher_exercises_created_at_idx
  on public.teacher_exercises(created_at desc);

create index if not exists teacher_exercises_scheduled_publish_at_idx
  on public.teacher_exercises(scheduled_publish_at desc);

alter table public.teacher_exercises enable row level security;

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

drop policy if exists "Professores podem gerenciar exercícios" on public.teacher_exercises;
create policy "Professores podem gerenciar exercícios"
  on public.teacher_exercises
  for all
  using (public.is_teacher_admin())
  with check (public.is_teacher_admin());

drop policy if exists "Alunos autenticados podem visualizar exercícios ativos" on public.teacher_exercises;
create policy "Alunos autenticados podem visualizar exercícios ativos"
  on public.teacher_exercises
  for select
  using (
    auth.uid() is not null
    and is_active = true
    and (scheduled_publish_at is null or scheduled_publish_at <= now())
  );

create or replace function public.set_teacher_exercises_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_teacher_exercises_updated_at on public.teacher_exercises;
create trigger set_teacher_exercises_updated_at
before update on public.teacher_exercises
for each row
execute function public.set_teacher_exercises_updated_at();

-- Necessário porque a assinatura da função mudou para incluir target_scheduled_publish_at.
drop function if exists public.create_teacher_exercise(text, text, text);
drop function if exists public.create_teacher_exercise(text, text, text, timestamptz);

create function public.create_teacher_exercise(
  target_exercise_id text,
  target_exercise_title text,
  target_exercise_url text,
  target_scheduled_publish_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if coalesce(trim(target_exercise_title), '') = '' then
    raise exception 'Informe o título do exercício.';
  end if;

  if coalesce(trim(target_exercise_url), '') = '' then
    raise exception 'Informe o link do exercício.';
  end if;

  insert into public.teacher_exercises (
    exercise_id,
    exercise_title,
    exercise_url,
    created_by,
    is_active,
    scheduled_publish_at
  )
  values (
    target_exercise_id,
    trim(target_exercise_title),
    trim(target_exercise_url),
    auth.uid(),
    true,
    target_scheduled_publish_at
  )
  returning id into new_id;

  return jsonb_build_object('ok', true, 'id', new_id, 'scheduled_publish_at', target_scheduled_publish_at);
end;
$$;

grant execute on function public.create_teacher_exercise(text, text, text, timestamptz) to authenticated;

-- Necessário porque a estrutura de retorno mudou para incluir scheduled_publish_at.
drop function if exists public.get_teacher_created_exercises();

create function public.get_teacher_created_exercises()
returns table (
  id text,
  exercise_id text,
  exercise_title text,
  exercise_url text,
  is_active boolean,
  scheduled_publish_at timestamptz,
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
    te.id::text,
    te.exercise_id,
    te.exercise_title,
    te.exercise_url,
    te.is_active,
    te.scheduled_publish_at,
    te.created_at,
    te.updated_at
  from public.teacher_exercises te
  order by coalesce(te.scheduled_publish_at, te.created_at) desc, te.created_at desc;
end;
$$;

grant execute on function public.get_teacher_created_exercises() to authenticated;

-- Necessário porque a estrutura e o filtro de retorno mudaram.
drop function if exists public.get_public_teacher_exercises();

create function public.get_public_teacher_exercises()
returns table (
  exercise_id text,
  exercise_title text,
  exercise_url text,
  scheduled_publish_at timestamptz,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    te.exercise_id,
    te.exercise_title,
    te.exercise_url,
    te.scheduled_publish_at,
    te.created_at
  from public.teacher_exercises te
  where te.is_active = true
    and (te.scheduled_publish_at is null or te.scheduled_publish_at <= now())
  order by coalesce(te.scheduled_publish_at, te.created_at) desc, te.created_at desc;
$$;

grant execute on function public.get_public_teacher_exercises() to authenticated;
