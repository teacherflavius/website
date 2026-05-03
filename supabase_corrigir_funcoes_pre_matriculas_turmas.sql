-- Correção para erro 42P13 ao executar supabase_pre_matriculas_turmas.sql
-- Execute este arquivo uma vez no Supabase em SQL Editor > Run.
-- Depois execute novamente supabase_pre_matriculas_turmas.sql.

-- O PostgreSQL não permite alterar o retorno de uma função com CREATE OR REPLACE
-- quando a função usa OUT parameters / RETURNS TABLE.
-- Por isso, as funções abaixo precisam ser removidas antes da recriação.

drop function if exists public.get_teacher_class_students(integer);
drop function if exists public.get_teacher_class_activity_history(integer);

-- Opcionalmente, removemos versões intermediárias caso tenham sido criadas parcialmente.
drop function if exists public.add_teacher_class_student_by_ref(integer, text, text);
drop function if exists public.remove_teacher_class_student_by_ref(integer, text, text);
drop function if exists public.save_teacher_class_attendance_by_ref(integer, date, text, jsonb);
