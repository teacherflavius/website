# Configuração do Supabase

Este projeto possui uma camada inicial de autenticação com Supabase para permitir login com e-mail e senha, perfil do aluno e histórico de atividades.

## 1. Criar projeto no Supabase

1. Acesse o Supabase.
2. Crie um novo projeto.
3. Copie a `Project URL` e a chave pública `anon public`.
4. Edite o arquivo `supabase_config.js`:

```javascript
window.SUPABASE_CONFIG = {
  url: "SUA_PROJECT_URL",
  anonKey: "SUA_ANON_PUBLIC_KEY"
};
```

Nunca use a `service_role key` no frontend.

## 2. Criar tabelas

No Supabase, vá em `SQL Editor` e execute:

```sql
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  email text,
  created_at timestamp with time zone default now()
);

create table if not exists public.activity_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_type text not null,
  activity_title text not null,
  score integer not null,
  total integer not null,
  percentage integer not null,
  completed_at timestamp with time zone default now()
);
```

## 3. Ativar RLS

Execute:

```sql
alter table public.profiles enable row level security;
alter table public.activity_results enable row level security;
```

## 4. Políticas de segurança

Execute:

```sql
create policy "Users can read own profile"
on public.profiles
for select
to authenticated
using (auth.uid() = id);

create policy "Users can insert own profile"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);

create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "Users can read own activity results"
on public.activity_results
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert own activity results"
on public.activity_results
for insert
to authenticated
with check (auth.uid() = user_id);
```

## 5. Páginas criadas

- `login.html` — login com e-mail e senha.
- `cadastro.html` — criação de conta.
- `perfil.html` — histórico individual do aluno.
- `auth.js` — funções de autenticação e banco.
- `supabase_config.js` — configuração do projeto Supabase.
- `supabase_results.js` — ponte para salvar resultados no Supabase.

## 6. Observação importante

O projeto ainda mantém o envio para Google Sheets como camada paralela. O Supabase deve ser considerado a base principal para login, perfil e histórico individual.
