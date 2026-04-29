-- Garante que cada aluno fique em apenas uma turma.
-- Execute no Supabase em SQL Editor > Run.
-- Este arquivo complementa supabase_turmas.sql.

-- Remove vínculos duplicados antigos, mantendo apenas o vínculo mais recente de cada aluno.
with ranked as (
  select
    id,
    user_id,
    row_number() over (
      partition by user_id
      order by created_at desc, id desc
    ) as rn
  from public.class_students
)
delete from public.class_students cs
using ranked r
where cs.id = r.id
  and r.rn > 1;

-- Impede que o mesmo aluno fique em mais de uma turma.
create unique index if not exists class_students_one_class_per_user_idx
  on public.class_students(user_id);

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
  previous_class_number integer;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

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

  select cs.class_number
  into previous_class_number
  from public.class_students cs
  where cs.user_id = target_user_id
  limit 1;

  insert into public.class_students (class_number, user_id)
  values (target_class_number, target_user_id)
  on conflict (user_id) do update
  set
    class_number = excluded.class_number,
    created_at = now()
  returning id into inserted_id;

  return jsonb_build_object(
    'ok', true,
    'id', inserted_id,
    'previous_class_number', previous_class_number,
    'new_class_number', target_class_number
  );
end;
$$;

grant execute on function public.add_teacher_class_student(integer, uuid) to authenticated;
