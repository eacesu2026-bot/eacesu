-- إصلاح أعمدة المصروفات (نفّذ في Supabase SQL Editor مرة واحدة)
alter table if exists rep_expenses_draft add column if not exists company text;
alter table if exists rep_expenses_draft add column if not exists exp_date date;
alter table if exists rep_expenses_draft add column if not exists description text;
alter table if exists rep_expenses_draft add column if not exists "desc" text;
alter table if exists rep_expenses_draft add column if not exists cat text;
alter table if exists rep_expenses_draft add column if not exists amt numeric;
alter table if exists rep_expenses_draft add column if not exists note text;
alter table if exists rep_expenses_draft add column if not exists status text default 'pending';
alter table if exists rep_expenses_draft add column if not exists reviewed_at timestamptz;

-- باركود تحميل/تفريغ السيارة (إن كان NOT NULL)
alter table if exists rep_vehicle_load_draft add column if not exists barcode text;
alter table if exists rep_vehicle_load_draft alter column barcode drop not null;
update rep_vehicle_load_draft set barcode = coalesce(nullif(barcode,''), item_code, item_id::text, 'NA') where barcode is null;
