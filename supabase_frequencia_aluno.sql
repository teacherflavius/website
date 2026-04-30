-- Visualização da frequência/regularidade do aluno com base nas lições registradas pelo professor.
-- Execute no Supabase em SQL Editor > Run.
-- Este arquivo depende de supabase_licoes_turma.sql.

create or replace function public.get_my_lesson_records()
returns table (
  id text,
  class_number integer,
  class_name text,
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
  return query
  select
    clr.id::text,
    clr.class_number,
    coalesce(tc.class_name, 'Turma ' || clr.class_number)::text as class_name,
    clr.class_date,
    clr.lesson_code,
    clr.created_at,
    clr.updated_at
  from public.class_lesson_records clr
  left join public.teacher_classes tc on tc.class_number = clr.class_number
  where clr.user_id = auth.uid()
  order by clr.class_date desc, clr.created_at desc;
end;
$$;

grant execute on function public.get_my_lesson_records() to authenticated;
