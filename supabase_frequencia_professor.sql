-- Funções da página Frequência dos Alunos
-- Execute no Supabase em SQL Editor > Run.
-- Este arquivo pressupõe que teacher_admins já existe e que seu e-mail de professor já está cadastrado.

create table if not exists public.student_frequency (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  class_date date not null,
  attendance_status text not null check (attendance_status in ('Compareceu', 'Faltou')),
  class_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists student_frequency_user_id_idx on public.student_frequency(user_id);
create index if not exists student_frequency_class_date_idx on public.student_frequency(class_date desc);

alter table public.student_frequency enable row level security;

drop policy if exists "Alunos podem ver sua própria frequência" on public.student_frequency;
create policy "Alunos podem ver sua própria frequência"
  on public.student_frequency
  for select
  using (auth.uid() = user_id);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_student_frequency_updated_at on public.student_frequency;
create trigger set_student_frequency_updated_at
before update on public.student_frequency
for each row
execute function public.set_updated_at();

create or replace function public.get_teacher_student_frequency(target_user_id uuid)
returns table (
  id text,
  user_id text,
  class_date date,
  attendance_status text,
  class_notes text,
  created_at timestamptz,
  updated_at timestamptz
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
    sf.id::text,
    sf.user_id::text,
    sf.class_date,
    sf.attendance_status,
    coalesce(sf.class_notes, '')::text,
    sf.created_at,
    sf.updated_at
  from public.student_frequency sf
  where sf.user_id = target_user_id
  order by sf.class_date desc, sf.created_at desc;
end;
$$;

grant execute on function public.get_teacher_student_frequency(uuid) to authenticated;

create or replace function public.save_teacher_student_frequency(
  target_user_id uuid,
  target_class_date date,
  target_attendance_status text,
  target_class_notes text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_email text;
  inserted_id uuid;
begin
  requester_email := auth.jwt() ->> 'email';

  if requester_email is null or not exists (
    select 1 from public.teacher_admins ta
    where lower(ta.email) = lower(requester_email)
  ) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if target_attendance_status not in ('Compareceu', 'Faltou') then
    raise exception 'Situação inválida.';
  end if;

  insert into public.student_frequency (user_id, class_date, attendance_status, class_notes)
  values (target_user_id, target_class_date, target_attendance_status, target_class_notes)
  returning id into inserted_id;

  return jsonb_build_object('ok', true, 'id', inserted_id);
end;
$$;

grant execute on function public.save_teacher_student_frequency(uuid, date, text, text) to authenticated;
