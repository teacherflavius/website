-- Permite registrar, além de L1 a L74, opções especiais na frequência da turma.
-- Execute no Supabase em SQL Editor > Run.
-- Este arquivo complementa supabase_licoes_turma.sql.

alter table public.class_lesson_records
  drop constraint if exists class_lesson_records_lesson_code_check;

alter table public.class_lesson_records
  add constraint class_lesson_records_lesson_code_check
  check (
    lesson_code ~ '^L([1-9]|[1-6][0-9]|7[0-4])$'
    or lesson_code in (
      'Feriado',
      'Teacher Cancelou',
      'Aluno cancelou',
      'Conversation',
      'Outras atividades',
      'Problemas técnicos'
    )
  );

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
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  if not (
    target_lesson_code ~ '^L([1-9]|[1-6][0-9]|7[0-4])$'
    or target_lesson_code in (
      'Feriado',
      'Teacher Cancelou',
      'Aluno cancelou',
      'Conversation',
      'Outras atividades',
      'Problemas técnicos'
    )
  ) then
    raise exception 'Registro inválido. Use L1 a L74 ou uma das opções especiais.';
  end if;

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
    class_date,
    lesson_code
  )
  values (
    target_class_number,
    target_user_id,
    target_class_date,
    target_lesson_code
  )
  on conflict (class_number, user_id, class_date) do update
  set lesson_code = excluded.lesson_code;

  return jsonb_build_object(
    'ok', true,
    'class_number', target_class_number,
    'user_id', target_user_id,
    'class_date', target_class_date,
    'lesson_code', target_lesson_code
  );
end;
$$;

grant execute on function public.save_teacher_class_lesson_record(integer, uuid, date, text) to authenticated;
