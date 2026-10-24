-- تقارير المساعد الذكي (اختياري)
create table if not exists ai_reports (
  id uuid primary key default gen_random_uuid(),
  rep_id uuid,
  rep_name text,
  company text,
  kind text,
  payload jsonb,
  body text,
  created_at timestamptz default now()
);
alter table ai_reports enable row level security;
drop policy if exists "ai_reports_all" on ai_reports;
create policy "ai_reports_all" on ai_reports for all to authenticated using (true) with check (true);
