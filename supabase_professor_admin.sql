-- Área administrativa do professor
-- Execute este arquivo no Supabase em SQL Editor > Run.
-- Depois, substitua o e-mail abaixo pelo e-mail da conta do professor.

create table if not exists public.teacher_admins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  email text unique not null,
  created_at timestamptz not null default now()
);

alter table public.teacher_admins enable row level security;

-- O usuário logado só consegue verificar se o próprio e-mail está cadastrado como professor.
drop policy if exists "Professor pode verificar suas próprias credenciais" on public.teacher_admins;
create policy "Professor pode verificar suas próprias credenciais"
  on public.teacher_admins
  for select
  using (lower(email) = lower(auth.jwt() ->> 'email'));

-- Autoriza professores a visualizar perfis de alunos matriculados.
-- Esta política depende de a tabela profiles já existir e ter RLS ativado.
alter table public.profiles enable row level security;

drop policy if exists "Professores podem visualizar alunos matriculados" on public.profiles;
create policy "Professores podem visualizar alunos matriculados"
  on public.profiles
  for select
  using (
    exists (
      select 1
      from public.teacher_admins ta
      where lower(ta.email) = lower(auth.jwt() ->> 'email')
    )
  );

-- Substitua professor@email.com pelo e-mail usado na conta de login do professor.
-- Rode este insert depois que a conta do professor já existir no Supabase Auth.
-- insert into public.teacher_admins (email)
-- values ('professor@email.com')
-- on conflict (email) do nothing;
