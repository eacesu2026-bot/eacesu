-- ===== Sales Reps System v2 — run in Supabase SQL Editor =====

create table if not exists rep_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  username text unique,
  companies text[] not null default '{}',
  phone text default '',
  active boolean not null default true,
  job_title text default 'مندوب',
  created_at timestamptz not null default now()
);
-- migrate old single company column if exists
do $$ begin
  if exists (select 1 from information_schema.columns where table_name='rep_profiles' and column_name='company') then
    update rep_profiles set companies = array[company] where (companies is null or companies = '{}') and company is not null;
  end if;
exception when others then null;
end $$;

create table if not exists rep_locations (
  rep_id uuid primary key references rep_profiles(user_id) on delete cascade,
  company text not null,
  lat double precision not null,
  lng double precision not null,
  accuracy double precision,
  updated_at timestamptz not null default now()
);

create table if not exists rep_visits (
  id uuid primary key default gen_random_uuid(),
  rep_id uuid not null references rep_profiles(user_id) on delete cascade,
  company text not null,
  customer_id text default '',
  customer_name text default '',
  lat double precision,
  lng double precision,
  accuracy double precision,
  notes text default '',
  visited_at timestamptz not null default now()
);
create index if not exists rep_visits_company_idx on rep_visits (company, visited_at desc);
create index if not exists rep_visits_rep_idx on rep_visits (rep_id, visited_at desc);

create table if not exists rep_sales_draft (
  id uuid primary key default gen_random_uuid(),
  rep_id uuid not null references rep_profiles(user_id) on delete cascade,
  company text not null,
  sale_date date not null default current_date,
  customer_id text default '',
  customer_name text not null,
  item_code text default '',
  item_name text not null,
  qty numeric not null default 0,
  price numeric not null default 0,
  disc numeric not null default 0,
  pay text not null default 'آجل',
  sale_type text not null default 'جملة',
  note text default '',
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  review_note text default '',
  edited_by_admin boolean default false
);
create index if not exists rep_sales_draft_status_idx on rep_sales_draft (company, status, created_at desc);

create table if not exists rep_collections_draft (
  id uuid primary key default gen_random_uuid(),
  rep_id uuid not null references rep_profiles(user_id) on delete cascade,
  company text not null,
  col_date date not null default current_date,
  customer_id text default '',
  customer_name text not null,
  amt numeric not null default 0,
  method text not null default 'كاش',
  note text default '',
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  review_note text default '',
  edited_by_admin boolean default false
);
create index if not exists rep_col_draft_status_idx on rep_collections_draft (company, status, created_at desc);

-- In-app notifications
create table if not exists rep_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text default '',
  kind text default 'info',
  ref_type text default '',
  ref_id uuid,
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists rep_notif_user_idx on rep_notifications (user_id, read, created_at desc);

-- Realtime (ignore errors if already added)
do $$ begin
  alter publication supabase_realtime add table rep_locations;
exception when duplicate_object then null; when others then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table rep_visits;
exception when duplicate_object then null; when others then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table rep_sales_draft;
exception when duplicate_object then null; when others then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table rep_collections_draft;
exception when duplicate_object then null; when others then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table rep_notifications;
exception when duplicate_object then null; when others then null;
end $$;

alter table rep_profiles enable row level security;
alter table rep_locations enable row level security;
alter table rep_visits enable row level security;
alter table rep_sales_draft enable row level security;
alter table rep_collections_draft enable row level security;
alter table rep_notifications enable row level security;

-- Drop old policies if re-run (safe)
do $$ declare r record; begin
  for r in select policyname, tablename from pg_policies where tablename in ('rep_profiles','rep_locations','rep_visits','rep_sales_draft','rep_collections_draft','rep_notifications')
  loop execute format('drop policy if exists %I on %I', r.policyname, r.tablename); end loop;
end $$;

create policy "rep_profiles_select" on rep_profiles for select to authenticated using (true);
create policy "rep_profiles_insert" on rep_profiles for insert to authenticated with check (true);
create policy "rep_profiles_update" on rep_profiles for update to authenticated using (true);

create policy "rep_loc_select" on rep_locations for select to authenticated using (true);
create policy "rep_loc_insert" on rep_locations for insert to authenticated with check (auth.uid() = rep_id);
create policy "rep_loc_update" on rep_locations for update to authenticated using (auth.uid() = rep_id or true);

create policy "rep_visits_select" on rep_visits for select to authenticated using (true);
create policy "rep_visits_insert" on rep_visits for insert to authenticated with check (auth.uid() = rep_id);
create policy "rep_visits_update" on rep_visits for update to authenticated using (true);

create policy "rep_sales_select" on rep_sales_draft for select to authenticated using (true);
create policy "rep_sales_insert" on rep_sales_draft for insert to authenticated with check (auth.uid() = rep_id);
create policy "rep_sales_update" on rep_sales_draft for update to authenticated using (true);

create policy "rep_col_select" on rep_collections_draft for select to authenticated using (true);
create policy "rep_col_insert" on rep_collections_draft for insert to authenticated with check (auth.uid() = rep_id);
create policy "rep_col_update" on rep_collections_draft for update to authenticated using (true);

create policy "rep_notif_select" on rep_notifications for select to authenticated using (auth.uid() = user_id);
create policy "rep_notif_insert" on rep_notifications for insert to authenticated with check (true);
create policy "rep_notif_update" on rep_notifications for update to authenticated using (auth.uid() = user_id);

-- Optional: admin list for multi-company assignment UI (not required)
-- insert into rep_profiles after creating Auth user


-- مسودات مصروفات المندوب
create table if not exists rep_expenses_draft (
  id uuid primary key default gen_random_uuid(),
  rep_id uuid not null references rep_profiles(user_id) on delete cascade,
  company text not null,
  exp_date date not null default current_date,
  "desc" text not null default '',
  cat text not null default 'أخرى',
  amt numeric not null default 0,
  note text default '',
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  review_note text default '',
  edited_by_admin boolean default false
);
create index if not exists rep_exp_draft_status_idx on rep_expenses_draft (company, status, created_at desc);

do $$ begin
  alter publication supabase_realtime add table rep_expenses_draft;
exception when duplicate_object then null; when others then null;
end $$;

alter table rep_expenses_draft enable row level security;
drop policy if exists "rep_exp_select" on rep_expenses_draft;
drop policy if exists "rep_exp_insert" on rep_expenses_draft;
drop policy if exists "rep_exp_update" on rep_expenses_draft;
create policy "rep_exp_select" on rep_expenses_draft for select to authenticated using (true);
create policy "rep_exp_insert" on rep_expenses_draft for insert to authenticated with check (auth.uid() = rep_id);
create policy "rep_exp_update" on rep_expenses_draft for update to authenticated using (true);

-- ===== طلبات تحميل سيارة التوزيع =====
create table if not exists rep_vehicle_load_draft (
  id uuid primary key default gen_random_uuid(),
  rep_id uuid not null references rep_profiles(user_id) on delete cascade,
  company text not null,
  load_date date not null default current_date,
  item_code text default '',
  item_name text not null,
  item_id text default '',
  qty numeric not null default 0,
  note text default '',
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  review_note text default '',
  edited_by_admin boolean default false
);
create index if not exists rep_vehicle_load_status_idx on rep_vehicle_load_draft (company, status, created_at desc);

-- رصيد السيارة (بعد الاعتماد)
create table if not exists rep_vehicle_stock (
  id uuid primary key default gen_random_uuid(),
  rep_id uuid not null references rep_profiles(user_id) on delete cascade,
  company text not null,
  item_id text not null,
  item_code text default '',
  item_name text not null,
  qty numeric not null default 0,
  updated_at timestamptz not null default now(),
  unique(rep_id, company, item_id)
);
create index if not exists rep_vehicle_stock_rep_idx on rep_vehicle_stock (rep_id, company);

do $$ begin
  alter publication supabase_realtime add table rep_vehicle_load_draft;
exception when duplicate_object then null; when others then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table rep_vehicle_stock;
exception when duplicate_object then null; when others then null;
end $$;

alter table rep_vehicle_load_draft enable row level security;
alter table rep_vehicle_stock enable row level security;

drop policy if exists "rep_vload_select" on rep_vehicle_load_draft;
drop policy if exists "rep_vload_insert" on rep_vehicle_load_draft;
drop policy if exists "rep_vload_update" on rep_vehicle_load_draft;
create policy "rep_vload_select" on rep_vehicle_load_draft for select to authenticated using (true);
create policy "rep_vload_insert" on rep_vehicle_load_draft for insert to authenticated with check (auth.uid() = rep_id);
create policy "rep_vload_update" on rep_vehicle_load_draft for update to authenticated using (true);

drop policy if exists "rep_vstock_select" on rep_vehicle_stock;
drop policy if exists "rep_vstock_insert" on rep_vehicle_stock;
drop policy if exists "rep_vstock_update" on rep_vehicle_stock;
create policy "rep_vstock_select" on rep_vehicle_stock for select to authenticated using (true);
create policy "rep_vstock_insert" on rep_vehicle_stock for insert to authenticated with check (true);
create policy "rep_vstock_update" on rep_vehicle_stock for update to authenticated using (true);


-- مسمى وظيفي
ALTER TABLE rep_profiles ADD COLUMN IF NOT EXISTS job_title TEXT DEFAULT 'مندوب';
