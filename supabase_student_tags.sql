-- Tags administrativas de alunos
-- Execute este arquivo no Supabase em SQL Editor > Run.
-- Usado por quadro-de-turmas.html para marcar alunos com a tag "pacote antigo".

create table if not exists public.student_tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  invite_id uuid references public.student_enrollment_invites(id) on delete cascade,
  tag_name text not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check (user_id is not null or invite_id is not null)
);

create unique index if not exists student_tags_user_tag_unique_idx
  on public.student_tags(user_id, tag_name)
  where user_id is not null;

create unique index if not exists student_tags_invite_tag_unique_idx
  on public.student_tags(invite_id, tag_name)
  where invite_id is not null;

create index if not exists student_tags_tag_name_idx
  on public.student_tags(tag_name);

alter table public.student_tags enable row level security;

drop policy if exists "Professores podem visualizar tags de alunos" on public.student_tags;
create policy "Professores podem visualizar tags de alunos"
  on public.student_tags
  for select
  to authenticated
  using (public.is_teacher_admin());

drop policy if exists "Professores podem criar tags de alunos" on public.student_tags;
create policy "Professores podem criar tags de alunos"
  on public.student_tags
  for insert
  to authenticated
  with check (public.is_teacher_admin());

drop policy if exists "Professores podem excluir tags de alunos" on public.student_tags;
create policy "Professores podem excluir tags de alunos"
  on public.student_tags
  for delete
  to authenticated
  using (public.is_teacher_admin());

create or replace function public.get_teacher_student_tags()
returns table (
  id text,
  user_id text,
  invite_id text,
  student_ref_id text,
  student_ref_type text,
  tag_name text,
  created_at timestamptz
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
    st.id::text,
    st.user_id::text,
    st.invite_id::text,
    coalesce(st.user_id::text, st.invite_id::text) as student_ref_id,
    case when st.user_id is not null then 'user' else 'invite' end::text as student_ref_type,
    st.tag_name::text,
    st.created_at
  from public.student_tags st
  order by st.created_at desc;
end;
$$;

grant execute on function public.get_teacher_student_tags() to authenticated;

create or replace function public.toggle_teacher_student_tag(
  target_student_ref_id text,
  target_student_ref_type text,
  target_tag_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_user_id uuid;
  target_invite_id uuid;
  existing_id uuid;
  normalized_tag text;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  normalized_tag := lower(trim(target_tag_name));

  if normalized_tag = '' then
    raise exception 'Tag inválida.';
  end if;

  if target_student_ref_type = 'user' then
    target_user_id := target_student_ref_id::uuid;

    select id into existing_id
    from public.student_tags
    where user_id = target_user_id
      and tag_name = normalized_tag
    limit 1;

    if existing_id is not null then
      delete from public.student_tags where id = existing_id;
      return jsonb_build_object('ok', true, 'tagged', false, 'tag_name', normalized_tag);
    end if;

    insert into public.student_tags(user_id, tag_name, created_by)
    values (target_user_id, normalized_tag, auth.uid());

    return jsonb_build_object('ok', true, 'tagged', true, 'tag_name', normalized_tag);
  elsif target_student_ref_type = 'invite' then
    target_invite_id := target_student_ref_id::uuid;

    select id into existing_id
    from public.student_tags
    where invite_id = target_invite_id
      and tag_name = normalized_tag
    limit 1;

    if existing_id is not null then
      delete from public.student_tags where id = existing_id;
      return jsonb_build_object('ok', true, 'tagged', false, 'tag_name', normalized_tag);
    end if;

    insert into public.student_tags(invite_id, tag_name, created_by)
    values (target_invite_id, normalized_tag, auth.uid());

    return jsonb_build_object('ok', true, 'tagged', true, 'tag_name', normalized_tag);
  else
    raise exception 'Tipo de aluno inválido.';
  end if;
end;
$$;

grant execute on function public.toggle_teacher_student_tag(text, text, text) to authenticated;

-- Se um aluno pré-matriculado concluir a matrícula depois de receber uma tag,
-- a tag passa a apontar também para o user_id dele.
create or replace function public.migrate_invite_student_tags_to_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'completed' and new.user_id is not null then
    update public.student_tags
    set user_id = new.user_id
    where invite_id = new.id
      and user_id is null;
  end if;

  return new;
end;
$$;

drop trigger if exists migrate_invite_student_tags_to_user_trigger on public.student_enrollment_invites;
create trigger migrate_invite_student_tags_to_user_trigger
  after update of status, user_id on public.student_enrollment_invites
  for each row
  execute function public.migrate_invite_student_tags_to_user();
