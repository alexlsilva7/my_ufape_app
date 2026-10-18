-- Leitura pública dos documentos acadêmicos usados pelo app sem login.
-- Não concede INSERT, UPDATE ou DELETE e não altera tabelas de usuários/feedback.
begin;

grant select on table public.courses, public.course_curricula,
  public.course_schedules, public.course_contents to anon, authenticated;

alter table public.courses enable row level security;
alter table public.course_curricula enable row level security;
alter table public.course_schedules enable row level security;
alter table public.course_contents enable row level security;

create policy flutter_public_academic_read on public.courses
  for select to anon, authenticated using (true);
create policy flutter_public_academic_read on public.course_curricula
  for select to anon, authenticated using (true);
create policy flutter_public_academic_read on public.course_schedules
  for select to anon, authenticated using (true);
create policy flutter_public_academic_read on public.course_contents
  for select to anon, authenticated using (true);

commit;
