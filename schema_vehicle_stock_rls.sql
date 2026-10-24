-- إصلاح رصيد السيارة: قيد الباركود + صلاحيات
alter table if exists rep_vehicle_stock enable row level security;

alter table if exists rep_vehicle_stock add column if not exists company text;
alter table if exists rep_vehicle_stock add column if not exists item_id text;
alter table if exists rep_vehicle_stock add column if not exists item_code text;
alter table if exists rep_vehicle_stock add column if not exists item_name text;
alter table if exists rep_vehicle_stock add column if not exists barcode text;
alter table if exists rep_vehicle_stock add column if not exists qty numeric default 0;
alter table if exists rep_vehicle_stock add column if not exists rep_id uuid;
alter table if exists rep_vehicle_stock add column if not exists updated_at timestamptz default now();

alter table if exists rep_vehicle_stock alter column barcode drop not null;
alter table if exists rep_vehicle_stock alter column barcode set default '-';
update rep_vehicle_stock set barcode = coalesce(nullif(trim(barcode),''), item_code, item_id, '-') where barcode is null or trim(barcode)='';

-- صلاحيات كاملة للمستخدمين المسجّلين
drop policy if exists "vehicle_stock_all_auth" on rep_vehicle_stock;
drop policy if exists "vehicle_stock_select" on rep_vehicle_stock;
drop policy if exists "vehicle_stock_insert" on rep_vehicle_stock;
drop policy if exists "vehicle_stock_update" on rep_vehicle_stock;
drop policy if exists "vehicle_stock_delete" on rep_vehicle_stock;
create policy "vehicle_stock_select" on rep_vehicle_stock for select to authenticated using (true);
create policy "vehicle_stock_insert" on rep_vehicle_stock for insert to authenticated with check (true);
create policy "vehicle_stock_update" on rep_vehicle_stock for update to authenticated using (true) with check (true);
create policy "vehicle_stock_delete" on rep_vehicle_stock for delete to authenticated using (true);

-- ملاحظة: القيد الفريد (rep_id, barcode) يبقى — التطبيق يحدّث عند التعارض
