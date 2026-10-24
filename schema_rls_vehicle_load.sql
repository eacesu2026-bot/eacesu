-- صلاحيات طلب تحميل السيارة (أصل مشكلة RLS)
-- نفّذ في Supabase → SQL Editor

alter table if exists rep_vehicle_load_draft enable row level security;

drop policy if exists "rep_vehicle_load_insert_own" on rep_vehicle_load_draft;
drop policy if exists "rep_vehicle_load_select_own" on rep_vehicle_load_draft;
drop policy if exists "rep_vehicle_load_admin_all" on rep_vehicle_load_draft;

create policy "rep_vehicle_load_insert_own" on rep_vehicle_load_draft
  for insert to authenticated
  with check (auth.uid() = rep_id);

create policy "rep_vehicle_load_select_own" on rep_vehicle_load_draft
  for select to authenticated
  using (auth.uid() = rep_id OR true);

-- إن رغبت بتقييد القراءة للمندوب فقط: using (auth.uid() = rep_id);

create policy "rep_vehicle_load_admin_all" on rep_vehicle_load_draft
  for all to authenticated
  using (true)
  with check (true);

-- أعمدة ناقصة شائعة
alter table if exists rep_vehicle_load_draft add column if not exists company text;
alter table if exists rep_vehicle_load_draft add column if not exists load_date date;
alter table if exists rep_vehicle_load_draft add column if not exists item_id text;
alter table if exists rep_vehicle_load_draft add column if not exists item_code text;
alter table if exists rep_vehicle_load_draft add column if not exists item_name text;
alter table if exists rep_vehicle_load_draft add column if not exists qty numeric;
alter table if exists rep_vehicle_load_draft add column if not exists note text;
alter table if exists rep_vehicle_load_draft add column if not exists status text default 'pending';
alter table if exists rep_vehicle_load_draft add column if not exists rep_id uuid;
