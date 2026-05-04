-- Corrige o registro de frequência/lições para alunos pré-matriculados.
-- Execute no Supabase em SQL Editor > Run.
-- Execute depois de supabase_turmas.sql, supabase_pre_matriculas_turmas.sql e supabase_licoes_turma.sql.

-- Permite registros de lições para alunos com conta (user_id) e pré-matriculados sem conta (invite_id).
alter table public.class_lesson_records
  alter column user_id drop not null;

alter table public.class_lesson_records
  add column if not exists invite_id uuid references public.student_enrollment_invites(id) on delete cascade;

-- Remove índices/constraints antigos que impedem pré-matrículas.
alter table public.class_lesson_records
  drop constraint if exists class_lesson_records_class_number_user_id_class_date_key;

alter table public.class_lesson_records
  drop constraint if exists class_lesson_records_lesson_code_check;

alter table public.class_lesson_records
  add constraint class_lesson_records_lesson_code_check
  check (
    lesson_code ~ '^L([1-9]|[1-6][0-9]|7[0-4])$'
    or lesson_code in (
      'Feriado',
      'Teacher Cancelou',
      'Não compareceu',
      'Conversation',
      'Outras atividades',
      'Problemas técnicos'
    )
  );

alter table public.class_lesson_records
  drop constraint if exists class_lesson_records_student_ref_check;

alter table public.class_lesson_records
  add constraint class_lesson_records_student_ref_check
  check (
    (user_id is not null and invite_id is null)
    or
    (user_id is null and invite_id is not null)
  );

create unique index if not exists class_lesson_records_class_user_date_unique_idx
  on public.class_lesson_records(class_number, user_id, class_date)
  where user_id is not null;

create unique index if not exists class_lesson_records_class_invite_date_unique_idx
  on public.class_lesson_records(class_number, invite_id, class_date)
  where invite_id is not null;

create index if not exists class_lesson_records_invite_id_idx
  on public.class_lesson_records(invite_id);

-- A assinatura de retorno desta função muda. Por isso, é obrigatório derrubá-la antes de recriar.
drop function if exists public.get_teacher_class_lesson_records(integer);

-- Atualiza a listagem para devolver referência genérica user/invite.
create function public.get_teacher_class_lesson_records(target_class_number integer)
returns table (
  id text,
  class_number integer,
  user_id text,
  invite_id text,
  student_ref_id text,
  student_ref_type text,
  class_date date,
  lesson_code text,
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

  perform public.assert_teacher_class_exists(target_class_number);

  return query
  select
    clr.id::text,
    clr.class_number,
    clr.user_id::text,
    clr.invite_id::text,
    coalesce(clr.user_id::text, clr.invite_id::text) as student_ref_id,
    case when clr.user_id is not null then 'user' else 'invite' end::text as student_ref_type,
    clr.class_date,
    clr.lesson_code,
    clr.created_at,
    clr.updated_at
  from public.class_lesson_records clr
  where clr.class_number = target_class_number
  order by clr.class_date desc, clr.created_at desc;
end;
$$;

grant execute on function public.get_teacher_class_lesson_records(integer) to authenticated;

-- Nova função usada pela página da turma. Evita converter string vazia para uuid.
create or replace function public.save_teacher_class_lesson_record_by_ref(
  target_class_number integer,
  target_student_ref_id text,
  target_student_ref_type text,
  target_class_date date,
  target_lesson_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_user_id uuid;
  target_invite_id uuid;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  if nullif(trim(target_student_ref_id), '') is null then
    raise exception 'Aluno inválido: referência vazia.';
  end if;

  if not (
    target_lesson_code ~ '^L([1-9]|[1-6][0-9]|7[0-4])$'
    or target_lesson_code in (
      'Feriado',
      'Teacher Cancelou',
      'Não compareceu',
      'Conversation',
      'Outras atividades',
      'Problemas técnicos'
    )
  ) then
    raise exception 'Registro inválido. Use L1 a L74 ou uma das opções especiais.';
  end if;

  if target_student_ref_type = 'user' then
    target_user_id := target_student_ref_id::uuid;
    target_invite_id := null;

    if not exists (
      select 1 from public.class_students cs
      where cs.class_number = target_class_number
        and cs.user_id = target_user_id
    ) then
      raise exception 'Este aluno não pertence a esta turma.';
    end if;

    insert into public.class_lesson_records (
      class_number,
      user_id,
      invite_id,
      class_date,
      lesson_code
    )
    values (
      target_class_number,
      target_user_id,
      null,
      target_class_date,
      target_lesson_code
    )
    on conflict (class_number, user_id, class_date) where user_id is not null do update
    set lesson_code = excluded.lesson_code;

  elsif target_student_ref_type = 'invite' then
    target_user_id := null;
    target_invite_id := target_student_ref_id::uuid;

    if not exists (
      select 1 from public.class_students cs
      where cs.class_number = target_class_number
        and cs.invite_id = target_invite_id
    ) then
      raise exception 'Esta pré-matrícula não pertence a esta turma.';
    end if;

    insert into public.class_lesson_records (
      class_number,
      user_id,
      invite_id,
      class_date,
      lesson_code
    )
    values (
      target_class_number,
      null,
      target_invite_id,
      target_class_date,
      target_lesson_code
    )
    on conflict (class_number, invite_id, class_date) where invite_id is not null do update
    set lesson_code = excluded.lesson_code;

  else
    raise exception 'Tipo de aluno inválido.';
  end if;

  return jsonb_build_object(
    'ok', true,
    'class_number', target_class_number,
    'student_ref_id', coalesce(target_user_id::text, target_invite_id::text),
    'student_ref_type', target_student_ref_type,
    'class_date', target_class_date,
    'lesson_code', target_lesson_code
  );
end;
$$;

grant execute on function public.save_teacher_class_lesson_record_by_ref(integer, text, text, date, text) to authenticated;

-- Compatibilidade: mantém a função antiga para alunos que já têm conta.
create or replace function public.save_teacher_class_lesson_record(
  target_class_number integer,
  target_user_id uuid,
  target_class_date date,
  target_lesson_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.save_teacher_class_lesson_record_by_ref(
    target_class_number,
    target_user_id::text,
    'user',
    target_class_date,
    target_lesson_code
  );
end;
$$;

grant execute on function public.save_teacher_class_lesson_record(integer, uuid, date, text) to authenticated;

-- Quando o aluno concluir a pré-matrícula, migra também os registros de lições.
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

    update public.class_lesson_records
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
