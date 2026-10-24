-- نفّذ هذا في Supabase: SQL Editor → New query → Run

-- جدول بيانات الشركات (JSON كامل لكل شركة)
create table if not exists company_data (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

-- فهرس للبحث داخل JSON عند الحاجة لاحقاً
create index if not exists company_data_updated_at_idx on company_data (updated_at desc);

-- تفعيل Realtime (آمن عند إعادة التشغيل)
do $$ begin
  alter publication supabase_realtime add table company_data;
exception when duplicate_object then null; when others then null;
end $$;

-- أمان الصفوف: أي مستخدم مسجّل دخول يقرأ ويكتب
alter table company_data enable row level security;

drop policy if exists "authenticated read company_data" on company_data;
drop policy if exists "authenticated insert company_data" on company_data;
drop policy if exists "authenticated update company_data" on company_data;
drop policy if exists "authenticated delete company_data" on company_data;

create policy "authenticated read company_data"
  on company_data for select
  to authenticated
  using (true);

create policy "authenticated insert company_data"
  on company_data for insert
  to authenticated
  with check (true);

create policy "authenticated update company_data"
  on company_data for update
  to authenticated
  using (true)
  with check (true);

create policy "authenticated delete company_data"
  on company_data for delete
  to authenticated
  using (true);

-- ملاحظة: أنشئ المستخدمين من Authentication → Users → Add user
-- أو فعّل Email signup من Authentication → Providers → Email
