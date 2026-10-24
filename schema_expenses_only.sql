-- مسودات مصروفات المندوب
create table if not exists rep_expenses_draft (
  id uuid primary key default gen_random_uuid(),
  rep_id uuid not null references rep_profiles(user_id) on delete cascade,
  company text not null,
  exp_date date not null default current_date,
  desc text not null default '',
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
