-- Correção: permite trocar qualquer aluno de turma.
-- Problema corrigido:
-- duplicate key value violates unique constraint "class_students_one_class_per_user_idx"
--
-- Execute este arquivo uma vez no Supabase:
-- SQL Editor > cole todo o conteúdo > Run.
--
-- Regra adotada: cada aluno fica em apenas uma turma por vez.
-- Ao salvar uma nova turma, a atribuição anterior do aluno é removida automaticamente.

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
      select 1
      from auth.users u
      where u.id = target_user_id
        and not exists (
          select 1
          from public.teacher_admins ta
          where lower(ta.email) = lower(u.email)
        )
    ) then
      raise exception 'Aluno não encontrado.';
    end if;

    -- Garante troca de turma: remove qualquer turma anterior do mesmo aluno.
    delete from public.class_students
    where user_id = target_user_id
      and class_number <> target_class_number;

    insert into public.class_students (class_number, user_id, invite_id)
    values (target_class_number, target_user_id, null)
    on conflict (class_number, user_id) do update
    set user_id = excluded.user_id,
        invite_id = null
    returning id into inserted_id;

  elsif target_student_ref_type = 'invite' then
    target_invite_id := target_student_ref_id::uuid;

    if not exists (
      select 1
      from public.student_enrollment_invites sei
      where sei.id = target_invite_id
        and sei.status in ('pending', 'completed')
    ) then
      raise exception 'Pré-matrícula não encontrada.';
    end if;

    -- Garante troca de turma também para pré-matrículas.
    delete from public.class_students
    where invite_id = target_invite_id
      and class_number <> target_class_number;

    insert into public.class_students (class_number, user_id, invite_id)
    values (target_class_number, null, target_invite_id)
    on conflict (class_number, invite_id) where invite_id is not null do update
    set invite_id = excluded.invite_id,
        user_id = null
    returning id into inserted_id;

  else
    raise exception 'Tipo de aluno inválido.';
  end if;

  return jsonb_build_object('ok', true, 'id', inserted_id, 'class_number', target_class_number);
end;
$$;

grant execute on function public.add_teacher_class_student_by_ref(integer, text, text) to authenticated;

-- Correção complementar: quando uma pré-matrícula vira conta de aluno,
-- evita conflito caso o aluno já esteja em outra turma.
create or replace function public.migrate_invite_records_to_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'completed' and new.user_id is not null then
    -- A turma vinculada ao convite concluído passa a ser a turma atual do aluno.
    delete from public.class_students
    where user_id = new.user_id
      and (invite_id is distinct from new.id);

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
