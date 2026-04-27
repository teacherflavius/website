-- Área administrativa do professor
-- Execute este arquivo no Supabase em SQL Editor > Run.
-- Depois, substitua professor@email.com pelo e-mail da conta do professor.

create table if not exists public.teacher_admins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  email text unique not null,
  created_at timestamptz not null default now()
);

alter table public.teacher_admins enable row level security;

drop policy if exists "Professor pode verificar suas próprias credenciais" on public.teacher_admins;
create policy "Professor pode verificar suas próprias credenciais"
  on public.teacher_admins
  for select
  using (lower(email) = lower(auth.jwt() ->> 'email'));

-- Libera leitura de profiles para professores autorizados.
alter table public.profiles enable row level security;

drop policy if exists "Professores podem visualizar alunos matriculados" on public.profiles;
drop policy if exists "Professores podem visualizar perfis" on public.profiles;
create policy "Professores podem visualizar perfis"
  on public.profiles
  for select
  using (
    exists (
      select 1
      from public.teacher_admins ta
      where lower(ta.email) = lower(auth.jwt() ->> 'email')
    )
  );

-- Libera leitura de student_enrollments para professores autorizados, caso a matrícula tenha sido salva nessa tabela.
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'student_enrollments'
  ) then
    execute 'alter table public.student_enrollments enable row level security';
    execute 'drop policy if exists "Professores podem visualizar matrículas" on public.student_enrollments';
    execute 'create policy "Professores podem visualizar matrículas" on public.student_enrollments for select using (exists (select 1 from public.teacher_admins ta where lower(ta.email) = lower(auth.jwt() ->> ''email'')))';
  end if;
end $$;

-- Substitua professor@email.com pelo e-mail usado na conta de login do professor.
insert into public.teacher_admins (email)
values ('professor@email.com')
on conflict (email) do nothing;
