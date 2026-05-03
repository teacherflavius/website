-- Aulas de gramática
-- Execute este arquivo no Supabase em SQL Editor > Run.
-- Este script cria a tabela usada por aulas-de-gramatica.html e aulas-de-gramatica-interface-do-professor.html.

create table if not exists public.grammar_lessons (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  video_url text not null,
  exercise_url text not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.grammar_lessons enable row level security;

drop policy if exists "Alunos autenticados podem visualizar aulas de gramatica" on public.grammar_lessons;
create policy "Alunos autenticados podem visualizar aulas de gramatica"
  on public.grammar_lessons
  for select
  to authenticated
  using (true);

drop policy if exists "Professores podem criar aulas de gramatica" on public.grammar_lessons;
create policy "Professores podem criar aulas de gramatica"
  on public.grammar_lessons
  for insert
  to authenticated
  with check (public.is_teacher_admin());

drop policy if exists "Professores podem editar aulas de gramatica" on public.grammar_lessons;
create policy "Professores podem editar aulas de gramatica"
  on public.grammar_lessons
  for update
  to authenticated
  using (public.is_teacher_admin())
  with check (public.is_teacher_admin());

drop policy if exists "Professores podem excluir aulas de gramatica" on public.grammar_lessons;
create policy "Professores podem excluir aulas de gramatica"
  on public.grammar_lessons
  for delete
  to authenticated
  using (public.is_teacher_admin());

create index if not exists grammar_lessons_created_at_idx
  on public.grammar_lessons (created_at desc);
