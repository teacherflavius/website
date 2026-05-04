-- Campo complementar para link das aulas gravadas nas turmas.
-- Execute no Supabase em SQL Editor > Run.
-- Este arquivo complementa supabase_turmas.sql.

alter table public.class_resources
  add column if not exists recorded_lessons_url text;

-- Necessário porque a estrutura de retorno mudou para incluir recorded_lessons_url.
drop function if exists public.get_teacher_class_resources(integer);

create function public.get_teacher_class_resources(target_class_number integer)
returns table (
  class_number integer,
  video_lesson_url text,
  lesson_material_url text,
  recorded_lessons_url text,
  whatsapp_group_url text,
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
    cr.class_number,
    coalesce(cr.video_lesson_url, '')::text,
    coalesce(cr.lesson_material_url, '')::text,
    coalesce(cr.recorded_lessons_url, '')::text,
    coalesce(cr.whatsapp_group_url, '')::text,
    cr.updated_at
  from public.class_resources cr
  where cr.class_number = target_class_number;
end;
$$;

grant execute on function public.get_teacher_class_resources(integer) to authenticated;

-- Função nova, com target_recorded_lessons_url.
create or replace function public.save_teacher_class_resources(
  target_class_number integer,
  target_video_lesson_url text,
  target_lesson_material_url text,
  target_recorded_lessons_url text,
  target_whatsapp_group_url text
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

  insert into public.class_resources (
    class_number,
    video_lesson_url,
    lesson_material_url,
    recorded_lessons_url,
    whatsapp_group_url
  )
  values (
    target_class_number,
    nullif(trim(coalesce(target_video_lesson_url, '')), ''),
    nullif(trim(coalesce(target_lesson_material_url, '')), ''),
    nullif(trim(coalesce(target_recorded_lessons_url, '')), ''),
    nullif(trim(coalesce(target_whatsapp_group_url, '')), '')
  )
  on conflict (class_number) do update
  set
    video_lesson_url = excluded.video_lesson_url,
    lesson_material_url = excluded.lesson_material_url,
    recorded_lessons_url = excluded.recorded_lessons_url,
    whatsapp_group_url = excluded.whatsapp_group_url;

  return jsonb_build_object('ok', true, 'class_number', target_class_number);
end;
$$;

grant execute on function public.save_teacher_class_resources(integer, text, text, text, text) to authenticated;

-- Compatibilidade: mantém a assinatura antiga de 4 parâmetros.
-- Importante: esta versão preserva recorded_lessons_url já salvo, em vez de apagá-lo.
create or replace function public.save_teacher_class_resources(
  target_class_number integer,
  target_video_lesson_url text,
  target_lesson_material_url text,
  target_whatsapp_group_url text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_recorded_lessons_url text;
begin
  select cr.recorded_lessons_url
  into existing_recorded_lessons_url
  from public.class_resources cr
  where cr.class_number = target_class_number;

  return public.save_teacher_class_resources(
    target_class_number,
    target_video_lesson_url,
    target_lesson_material_url,
    existing_recorded_lessons_url,
    target_whatsapp_group_url
  );
end;
$$;

grant execute on function public.save_teacher_class_resources(integer, text, text, text) to authenticated;

-- Necessário porque a estrutura de retorno mudou para incluir recorded_lessons_url.
drop function if exists public.get_my_student_class();

create function public.get_my_student_class()
returns table (
  id text,
  class_number integer,
  class_name text,
  user_id text,
  student_name text,
  student_email text,
  enrollment_code text,
  video_lesson_url text,
  lesson_material_url text,
  recorded_lessons_url text,
  whatsapp_group_url text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  return query
  select
    cs.id::text,
    cs.class_number,
    coalesce(tc.class_name, 'Turma ' || cs.class_number)::text as class_name,
    cs.user_id::text,
    coalesce(p.name, u.raw_user_meta_data ->> 'name', u.email, 'Aluno sem nome')::text as student_name,
    coalesce(p.email, u.email, '')::text as student_email,
    coalesce(p.enrollment_code, u.raw_user_meta_data ->> 'enrollment_code', '')::text as enrollment_code,
    coalesce(cr.video_lesson_url, '')::text as video_lesson_url,
    coalesce(cr.lesson_material_url, '')::text as lesson_material_url,
    coalesce(cr.recorded_lessons_url, '')::text as recorded_lessons_url,
    coalesce(cr.whatsapp_group_url, '')::text as whatsapp_group_url,
    cs.created_at
  from public.class_students cs
  left join public.teacher_classes tc on tc.class_number = cs.class_number and tc.is_active = true
  left join public.profiles p on p.id = cs.user_id
  left join auth.users u on u.id = cs.user_id
  left join public.class_resources cr on cr.class_number = cs.class_number
  where cs.user_id = auth.uid()
  order by cs.created_at desc;
end;
$$;

grant execute on function public.get_my_student_class() to authenticated;
