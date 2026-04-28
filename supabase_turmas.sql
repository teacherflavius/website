-- Tabela e funções para gerenciar alunos nas turmas
-- Execute no Supabase em SQL Editor > Run.
-- Este arquivo pressupõe que teacher_admins e profiles já existem.

create table if not exists public.class_students (
  id uuid primary key default gen_random_uuid(),
  class_number integer not null check (class_number between 1 and 45),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (class_number, user_id)
);

create index if not exists class_students_class_number_idx
  on public.class_students(class_number);

create index if not exists class_students_user_id_idx
  on public.class_students(user_id);

alter table public.class_students enable row level security;

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

drop policy if exists "Professores podem visualizar alunos das turmas" on public.class_students;
create policy "Professores podem visualizar alunos das turmas"
  on public.class_students
  for select
  using (public.is_teacher_admin());

create or replace function public.get_teacher_class_students(target_class_number integer)
returns table (
  id text,
  class_number integer,
  user_id text,
  student_name text,
  student_email text,
  enrollment_code text,
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

  if target_class_number < 1 or target_class_number > 45 then
    raise exception 'Turma inválida. Use um número entre 1 e 45.';
  end if;

  return query
  select
    cs.id::text,
    cs.class_number,
    cs.user_id::text,
    coalesce(p.name, u.raw_user_meta_data ->> 'name', u.email, 'Aluno sem nome')::text as student_name,
    coalesce(p.email, u.email, '')::text as student_email,
    coalesce(p.enrollment_code, u.raw_user_meta_data ->> 'enrollment_code', '')::text as enrollment_code,
    cs.created_at
  from public.class_students cs
  left join public.profiles p on p.id = cs.user_id
  left join auth.users u on u.id = cs.user_id
  where cs.class_number = target_class_number
  order by student_name asc, student_email asc;
end;
$$;

grant execute on function public.get_teacher_class_students(integer) to authenticated;

create or replace function public.add_teacher_class_student(
  target_class_number integer,
  target_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  inserted_id uuid;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if target_class_number < 1 or target_class_number > 45 then
    raise exception 'Turma inválida. Use um número entre 1 e 45.';
  end if;

  if not exists (
    select 1
    from auth.users u
    left join public.profiles p on p.id = u.id
    where u.id = target_user_id
      and not exists (
        select 1 from public.teacher_admins ta
        where lower(ta.email) = lower(u.email)
      )
      and (
        coalesce(p.enrolled, false) = true
        or coalesce(p.enrollment_code, '') <> ''
        or coalesce((u.raw_user_meta_data ->> 'enrolled')::boolean, false) = true
        or coalesce(u.raw_user_meta_data ->> 'enrollment_code', '') <> ''
      )
  ) then
    raise exception 'Aluno matriculado não encontrado.';
  end if;

  insert into public.class_students (class_number, user_id)
  values (target_class_number, target_user_id)
  on conflict (class_number, user_id) do update
  set class_number = excluded.class_number
  returning id into inserted_id;

  return jsonb_build_object('ok', true, 'id', inserted_id);
end;
$$;

grant execute on function public.add_teacher_class_student(integer, uuid) to authenticated;

create or replace function public.remove_teacher_class_student(
  target_class_number integer,
  target_user_id uuid
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

  if target_class_number < 1 or target_class_number > 45 then
    raise exception 'Turma inválida. Use um número entre 1 e 45.';
  end if;

  delete from public.class_students
  where class_number = target_class_number
    and user_id = target_user_id;

  if not found then
    raise exception 'Aluno não encontrado nesta turma.';
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.remove_teacher_class_student(integer, uuid) to authenticated;

create or replace function public.save_teacher_class_attendance(
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
  target_status text;
  target_notes text;
  inserted_count integer := 0;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if target_class_number < 1 or target_class_number > 45 then
    raise exception 'Turma inválida. Use um número entre 1 e 45.';
  end if;

  if attendance_records is null or jsonb_array_length(attendance_records) = 0 then
    raise exception 'Nenhum aluno foi selecionado para registrar frequência.';
  end if;

  for item in select * from jsonb_array_elements(attendance_records)
  loop
    target_user_id := (item ->> 'user_id')::uuid;
    target_status := coalesce(item ->> 'attendance_status', 'Compareceu');
    target_notes := coalesce(nullif(item ->> 'class_notes', ''), target_general_notes, '');

    if target_status not in ('Compareceu', 'Faltou') then
      raise exception 'Situação inválida para um dos alunos.';
    end if;

    if not exists (
      select 1 from public.class_students cs
      where cs.class_number = target_class_number
        and cs.user_id = target_user_id
    ) then
      raise exception 'Um dos alunos selecionados não pertence a esta turma.';
    end if;

    insert into public.student_frequency (user_id, class_date, attendance_status, class_notes)
    values (
      target_user_id,
      target_class_date,
      target_status,
      '[Turma ' || target_class_number || '] ' || target_notes
    );

    inserted_count := inserted_count + 1;
  end loop;

  return jsonb_build_object('ok', true, 'inserted_count', inserted_count);
end;
$$;

grant execute on function public.save_teacher_class_attendance(integer, date, text, jsonb) to authenticated;
