-- Permite reorganizar a ordem das turmas e manter a mesma ordem em todos os navegadores.
-- Execute no Supabase em SQL Editor > Run.
-- Execute depois de supabase_turmas.sql e, se usado, depois de supabase_pre_matriculas_turmas.sql.

alter table public.teacher_classes
  add column if not exists display_order integer;

-- Inicializa a ordem atual para turmas antigas.
update public.teacher_classes
set display_order = class_number
where display_order is null;

create index if not exists teacher_classes_display_order_idx
  on public.teacher_classes(display_order, class_number);

-- Recria get_teacher_classes para ordenar por display_order.
create or replace function public.get_teacher_classes()
returns table (
  id text,
  class_number integer,
  class_name text,
  student_count integer,
  is_active boolean,
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
    tc.id::text,
    tc.class_number,
    tc.class_name,
    count(cs.id)::integer as student_count,
    tc.is_active,
    tc.created_at,
    tc.updated_at
  from public.teacher_classes tc
  left join public.class_students cs on cs.class_number = tc.class_number
  where tc.is_active = true
  group by tc.id, tc.class_number, tc.class_name, tc.display_order, tc.is_active, tc.created_at, tc.updated_at
  order by coalesce(tc.display_order, tc.class_number) asc, tc.class_number asc;
end;
$$;

grant execute on function public.get_teacher_classes() to authenticated;

-- Garante que novas turmas sejam criadas no final da ordem.
create or replace function public.create_teacher_class(target_class_name text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  next_number integer;
  next_order integer;
  final_name text;
  inserted_id uuid;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  select coalesce(max(class_number), 0) + 1
  into next_number
  from public.teacher_classes;

  select coalesce(max(display_order), 0) + 1
  into next_order
  from public.teacher_classes
  where is_active = true;

  final_name := coalesce(nullif(trim(target_class_name), ''), 'Turma ' || next_number);

  insert into public.teacher_classes (class_number, class_name, display_order, is_active)
  values (next_number, final_name, next_order, true)
  returning id into inserted_id;

  return jsonb_build_object('ok', true, 'id', inserted_id, 'class_number', next_number, 'class_name', final_name);
end;
$$;

grant execute on function public.create_teacher_class(text) to authenticated;

-- Salva a ordem definida na tela turmas.html.
create or replace function public.save_teacher_classes_order(classes_order jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
  target_class_number integer;
  target_display_order integer;
  updated_count integer := 0;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  if classes_order is null or jsonb_typeof(classes_order) <> 'array' then
    raise exception 'Formato de ordem inválido.';
  end if;

  for item in select * from jsonb_array_elements(classes_order)
  loop
    target_class_number := (item ->> 'class_number')::integer;
    target_display_order := (item ->> 'display_order')::integer;

    if target_class_number is null or target_display_order is null or target_display_order < 1 then
      raise exception 'Item de ordem inválido.';
    end if;

    update public.teacher_classes
    set display_order = target_display_order
    where class_number = target_class_number
      and is_active = true;

    if found then
      updated_count := updated_count + 1;
    end if;
  end loop;

  return jsonb_build_object('ok', true, 'updated_count', updated_count);
end;
$$;

grant execute on function public.save_teacher_classes_order(jsonb) to authenticated;
