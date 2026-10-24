-- إصلاح أعمدة مسودات المندوب (نفّذ بالكامل في Supabase SQL Editor)
-- ملاحظة: desc كلمة محجوزة في PostgreSQL لذلك تُكتب "desc"

-- ===== تحميل سيارة =====
alter table if exists rep_vehicle_load_draft add column if not exists company text;
alter table if exists rep_vehicle_load_draft add column if not exists load_date date;
alter table if exists rep_vehicle_load_draft add column if not exists item_code text;
alter table if exists rep_vehicle_load_draft add column if not exists item_name text;
alter table if exists rep_vehicle_load_draft add column if not exists item_id text;
alter table if exists rep_vehicle_load_draft add column if not exists qty numeric;
alter table if exists rep_vehicle_load_draft add column if not exists note text;
alter table if exists rep_vehicle_load_draft add column if not exists status text default 'pending';
alter table if exists rep_vehicle_load_draft add column if not exists rep_id uuid;
alter table if exists rep_vehicle_load_draft add column if not exists created_at timestamptz default now();
alter table if exists rep_vehicle_load_draft add column if not exists reviewed_at timestamptz;

update rep_vehicle_load_draft set company = coalesce(nullif(company,''), 'الراعي') where company is null or company = '';

-- ===== مبيعات =====
alter table if exists rep_sales_draft add column if not exists company text;
alter table if exists rep_sales_draft add column if not exists sale_date date;
alter table if exists rep_sales_draft add column if not exists customer_id text;
alter table if exists rep_sales_draft add column if not exists customer_name text;
alter table if exists rep_sales_draft add column if not exists item_code text;
alter table if exists rep_sales_draft add column if not exists item_name text;
alter table if exists rep_sales_draft add column if not exists item_id text;
alter table if exists rep_sales_draft add column if not exists qty numeric;
alter table if exists rep_sales_draft add column if not exists price numeric;
alter table if exists rep_sales_draft add column if not exists disc numeric default 0;
alter table if exists rep_sales_draft add column if not exists disc_amt numeric default 0;
alter table if exists rep_sales_draft add column if not exists pay text;
alter table if exists rep_sales_draft add column if not exists sale_type text;
alter table if exists rep_sales_draft add column if not exists note text;
alter table if exists rep_sales_draft add column if not exists status text default 'pending';
alter table if exists rep_sales_draft add column if not exists inv text;

-- ===== تحصيلات =====
alter table if exists rep_collections_draft add column if not exists company text;
alter table if exists rep_collections_draft add column if not exists col_date date;
alter table if exists rep_collections_draft add column if not exists customer_id text;
alter table if exists rep_collections_draft add column if not exists customer_name text;
alter table if exists rep_collections_draft add column if not exists amt numeric;
alter table if exists rep_collections_draft add column if not exists method text;
alter table if exists rep_collections_draft add column if not exists note text;
alter table if exists rep_collections_draft add column if not exists status text default 'pending';

-- ===== مصروفات =====
alter table if exists rep_expenses_draft add column if not exists company text;
alter table if exists rep_expenses_draft add column if not exists exp_date date;
alter table if exists rep_expenses_draft add column if not exists "desc" text;
alter table if exists rep_expenses_draft add column if not exists cat text;
alter table if exists rep_expenses_draft add column if not exists amt numeric;
alter table if exists rep_expenses_draft add column if not exists note text;
alter table if exists rep_expenses_draft add column if not exists status text default 'pending';

-- ===== رصيد السيارة =====
alter table if exists rep_vehicle_stock add column if not exists company text;
alter table if exists rep_vehicle_stock add column if not exists item_id text;
alter table if exists rep_vehicle_stock add column if not exists qty numeric default 0;

-- فهرس
create index if not exists rep_vehicle_load_status_idx on rep_vehicle_load_draft (company, status, created_at desc);

-- تفعيل RLS بأمان
do $$ begin
  alter table rep_vehicle_load_draft enable row level security;
exception when others then null;
end $$;
