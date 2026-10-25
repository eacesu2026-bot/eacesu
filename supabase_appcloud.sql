-- =====================================================================
-- AppCloud على Supabase — مزامنة سحابية تعمل مع أي استضافة ثابتة (بلا خادم Node)
-- التشغيل: Supabase ← SQL Editor ← الصق هذا الملف كاملًا ← Run
-- ثم غيّر مفتاح الإدارة (آخر سطر) إلى مفتاحك السري الطويل وشغّله.
-- المتصفح يستدعي دالة واحدة فقط (appcloud_call)؛ الجداول مغلقة تمامًا أمام الزوار (RLS بلا سياسات).
-- كل بيانات الأعضاء والشكاوى والأصوات تصل مشفّرة؛ الخادم لا يستطيع قراءتها.
-- =====================================================================
create table if not exists public.appcloud_kv (
  path text primary key,
  body text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.appcloud_cfg (k text primary key, v text not null);
alter table public.appcloud_kv enable row level security;
alter table public.appcloud_cfg enable row level security;
revoke all on public.appcloud_kv, public.appcloud_cfg from anon, authenticated;

create or replace function public.appcloud_set_key(p_key text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if length(coalesce(p_key,'')) < 12 then raise exception 'المفتاح قصير: استخدم 12 حرفًا على الأقل'; end if;
  insert into appcloud_cfg(k,v) values ('admin_hash', encode(sha256(convert_to(p_key,'UTF8')),'hex'))
  on conflict (k) do update set v = excluded.v;
end $$;
revoke all on function public.appcloud_set_key(text) from public, anon, authenticated;

create or replace function public.appcloud_call(p_action text, p_key text default '', p_args jsonb default '{}'::jsonb, p_body text default '')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  c_max_pub constant int := 3670016;
  v_hash text; v_admin boolean := false; v_txt text; v_b jsonb; v_pub jsonb; v_o jsonb; v_el jsonb;
  v_path text; v_poll text; v_n int; v_ms text; v_keys text[] := array['org','news','stocks','fin','votes','regsEnc','stats','rev'];
  v_k text; ix text[]; v_env jsonb; v_now text;
  b64 constant text := '^[A-Za-z0-9+/=]+$';
begin
  v_now := to_char(now() at time zone 'utc','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  v_ms := floor(extract(epoch from clock_timestamp())*1000)::bigint::text;

  /* ---------- عام ---------- */
  if p_action = 'public' then
    select body into v_txt from appcloud_kv where path = 'site/public.json';
    if not found then return jsonb_build_object('s',200,'b',jsonb_build_object('empty',true)); end if;
    return jsonb_build_object('s',200,'b',v_txt::jsonb);
  end if;

  if p_action = 'member' then
    select array(select x from regexp_split_to_table(coalesce(p_args->>'ix',''), ',') x
                 where x ~ b64 and length(x) between 1 and 64 limit 3) into ix;
    if coalesce(array_length(ix,1),0) = 0 then return jsonb_build_object('s',404,'b',jsonb_build_object('error','Not found')); end if;
    select body into v_txt from appcloud_kv where path = 'site/members.json';
    if not found then return jsonb_build_object('s',404,'b',jsonb_build_object('error','Not found')); end if;
    select e into v_env from jsonb_array_elements(v_txt::jsonb) e
      where (e->'ix'->>0) = any(ix) or (e->'ix'->>1) = any(ix) or (e->'ix'->>2) = any(ix) limit 1;
    if v_env is null then return jsonb_build_object('s',404,'b',jsonb_build_object('error','Not found')); end if;
    return jsonb_build_object('s',200,'b',v_env);
  end if;

  if p_action = 'complaint' then
    if length(p_body) > 16384 then return jsonb_build_object('s',413,'b',jsonb_build_object('error','Too large')); end if;
    begin v_b := p_body::jsonb; exception when others then return jsonb_build_object('s',400,'b',jsonb_build_object('error','Invalid')); end;
    if jsonb_typeof(v_b) <> 'object' or v_b->>'kind' is distinct from 'eacesu-complaint'
       or coalesce(v_b->>'id','') !~ '^[A-Za-z0-9_-]{1,48}$'
       or coalesce(v_b->>'iv','') !~ b64 or length(v_b->>'iv') > 64
       or coalesce(v_b->>'ct','') !~ b64 or length(v_b->>'ct') > 12000
       or coalesce(v_b->>'wk','') !~ b64 or length(v_b->>'wk') > 1000
    then return jsonb_build_object('s',400,'b',jsonb_build_object('error','Only encrypted complaints are accepted')); end if;
    select count(*) into v_n from appcloud_kv where path like 'complaints/%';
    if v_n >= 5000 then return jsonb_build_object('s',429,'b',jsonb_build_object('error','Too many requests')); end if;
    insert into appcloud_kv(path,body) values ('complaints/'||v_ms||'-'||(v_b->>'id')||'-'||substr(md5(random()::text||clock_timestamp()::text),1,8)||'.json',
      jsonb_build_object('kind',v_b->>'kind','id',v_b->>'id','iv',v_b->>'iv','ct',v_b->>'ct','wk',v_b->>'wk')::text);
    return jsonb_build_object('s',200,'b',jsonb_build_object('ok',true));
  end if;

  if p_action = 'ballot' then
    if length(p_body) > 16384 then return jsonb_build_object('s',413,'b',jsonb_build_object('error','Too large')); end if;
    begin v_b := p_body::jsonb; exception when others then return jsonb_build_object('s',400,'b',jsonb_build_object('error','Invalid')); end;
    if jsonb_typeof(v_b) <> 'object' or v_b->>'kind' is distinct from 'eacesu-ballot'
       or coalesce(v_b->>'poll','') !~ '^[A-Za-z0-9_-]{1,48}$'
       or coalesce(v_b->>'voter','') !~ '^[0-9a-f]{64}$'
       or coalesce(v_b->>'iv','') !~ b64 or length(v_b->>'iv') > 64
       or coalesce(v_b->>'ct','') !~ b64 or length(v_b->>'ct') > 2000
       or coalesce(v_b->>'wk','') !~ b64 or length(v_b->>'wk') > 1000
    then return jsonb_build_object('s',400,'b',jsonb_build_object('error','Invalid ballot')); end if;
    select body into v_txt from appcloud_kv where path = 'site/public.json';
    if not found or not exists (select 1 from jsonb_array_elements(coalesce((v_txt::jsonb)->'votes','[]'::jsonb)) v
                                where v->>'id' = v_b->>'poll' and v->>'status' = 'open')
    then return jsonb_build_object('s',403,'b',jsonb_build_object('error','Poll closed')); end if;
    select count(*) into v_n from appcloud_kv where path like 'ballots/%';
    if v_n >= 50000 then return jsonb_build_object('s',429,'b',jsonb_build_object('error','Too many requests')); end if;
    v_path := 'ballots/'||(v_b->>'poll')||'/'||(v_b->>'voter')||'.json';
    insert into appcloud_kv(path,body) values (v_path,
      jsonb_build_object('kind',v_b->>'kind','poll',v_b->>'poll','voter',v_b->>'voter','iv',v_b->>'iv','ct',v_b->>'ct','wk',v_b->>'wk')::text)
      on conflict (path) do nothing;
    get diagnostics v_n = row_count;
    if v_n = 0 then return jsonb_build_object('s',409,'b',jsonb_build_object('error','Already voted')); end if;
    return jsonb_build_object('s',200,'b',jsonb_build_object('ok',true));
  end if;

  /* ---------- إدارة (مفتاح) ---------- */
  select v into v_hash from appcloud_cfg where k = 'admin_hash';
  v_admin := v_hash is not null and v_hash = encode(sha256(convert_to(coalesce(p_key,''),'UTF8')),'hex');
  if not v_admin then
    perform pg_sleep(0.4);  -- إبطاء التخمين
    return jsonb_build_object('s',401,'b',jsonb_build_object('error','Unauthorized'));
  end if;

  if p_action = 'selftest' then
    insert into appcloud_kv(path,body) values ('site/selftest.json', v_ms) on conflict (path) do update set body = excluded.body;
    select body into v_txt from appcloud_kv where path = 'site/selftest.json';
    if v_txt is distinct from v_ms then return jsonb_build_object('s',500,'b',jsonb_build_object('error','readback_failed')); end if;
    return jsonb_build_object('s',200,'b',jsonb_build_object('ok',true,'storage','supabase'));
  end if;

  if p_action = 'publish' then
    if length(p_body) > c_max_pub then return jsonb_build_object('s',413,'b',jsonb_build_object('error','Too large')); end if;
    begin v_b := p_body::jsonb; exception when others then return jsonb_build_object('s',400,'b',jsonb_build_object('error','Invalid')); end;
    if jsonb_typeof(v_b->'public') <> 'object' or jsonb_typeof(v_b->'members') <> 'array' then
      return jsonb_build_object('s',400,'b',jsonb_build_object('error','Invalid')); end if;
    if jsonb_array_length(v_b->'members') > 5000 then return jsonb_build_object('s',400,'b',jsonb_build_object('error','Invalid member envelopes')); end if;
    for v_el in select e from jsonb_array_elements(v_b->'members') e loop
      if jsonb_typeof(v_el->'id') <> 'string' or jsonb_typeof(v_el->'ix') <> 'array' or jsonb_array_length(v_el->'ix') < 2
         or coalesce(v_el->>'wa','') !~ b64 or length(v_el->>'wa') > 2000
         or coalesce(v_el->>'ct','') !~ b64 or length(v_el->>'ct') > 20000
         or coalesce(v_el->>'iv','') !~ b64 or length(v_el->>'iv') > 64
         or coalesce(v_el->>'wm','') !~ b64 or length(v_el->>'wm') > 400
         or coalesce(v_el->>'s','')  !~ b64 or length(v_el->>'s')  > 64
         or coalesce(v_el->>'wmi','') !~ b64 or length(v_el->>'wmi') > 64
      then return jsonb_build_object('s',400,'b',jsonb_build_object('error','Invalid member envelopes')); end if;
    end loop;
    v_pub := '{}'::jsonb;
    foreach v_k in array v_keys loop
      if v_b->'public' ? v_k then v_pub := v_pub || jsonb_build_object(v_k, v_b->'public'->v_k); end if;
    end loop;
    v_pub := v_pub || jsonb_build_object('updatedAt', v_now);
    insert into appcloud_kv(path,body) values ('site/public.json', v_pub::text)
      on conflict (path) do update set body = excluded.body, created_at = now();
    insert into appcloud_kv(path,body) values ('site/members.json', (v_b->'members')::text)
      on conflict (path) do update set body = excluded.body, created_at = now();
    return jsonb_build_object('s',200,'b',jsonb_build_object('ok',true,'updatedAt',v_now,'members',jsonb_array_length(v_b->'members')));
  end if;

  if p_action = 'members_all' then
    select body into v_txt from appcloud_kv where path = 'site/members.json';
    return jsonb_build_object('s',200,'b',jsonb_build_object('members', coalesce(v_txt::jsonb,'[]'::jsonb)));
  end if;

  if p_action = 'complaints' then
    select coalesce(jsonb_agg(((body::jsonb) || jsonb_build_object('pathname',path,'uploadedAt',to_char(created_at at time zone 'utc','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))) order by created_at desc),'[]'::jsonb)
      into v_o from (select * from appcloud_kv where starts_with(path,'complaints/') order by created_at desc limit 500) t;
    return jsonb_build_object('s',200,'b',jsonb_build_object('items',v_o));
  end if;

  if p_action = 'delcomplaint' then
    v_path := coalesce(p_args->>'pathname','');
    if not starts_with(v_path,'complaints/') or position('..' in v_path) > 0 then return jsonb_build_object('s',400,'b',jsonb_build_object('error','Bad path')); end if;
    delete from appcloud_kv where path = v_path;
    return jsonb_build_object('s',200,'b',jsonb_build_object('ok',true));
  end if;

  if p_action = 'ballots' then
    v_poll := coalesce(p_args->>'poll','');
    if v_poll !~ '^[A-Za-z0-9_-]{1,48}$' then return jsonb_build_object('s',400,'b',jsonb_build_object('error','Bad poll')); end if;
    select coalesce(jsonb_agg(body::jsonb),'[]'::jsonb) into v_o from (select body from appcloud_kv where starts_with(path,'ballots/'||v_poll||'/') limit 1000) t;
    return jsonb_build_object('s',200,'b',jsonb_build_object('items',v_o));
  end if;

  if p_action = 'backup' then
    if length(p_body) > c_max_pub then return jsonb_build_object('s',413,'b',jsonb_build_object('error','Too large')); end if;
    begin v_b := p_body::jsonb; exception when others then return jsonb_build_object('s',400,'b',jsonb_build_object('error','Invalid JSON')); end;
    if jsonb_typeof(v_b) <> 'object' or v_b->>'kind' is distinct from 'eacesu-cloud' or jsonb_typeof(v_b->'iv') <> 'string' or jsonb_typeof(v_b->'ct') <> 'string' or jsonb_typeof(v_b->'wk') <> 'string'
    then return jsonb_build_object('s',400,'b',jsonb_build_object('error','Only encrypted bundles are accepted')); end if;
    v_path := 'backups/eacesu-'||v_ms||'-'||substr(md5(random()::text),1,6)||'.json';
    insert into appcloud_kv(path,body) values (v_path, p_body);
    delete from appcloud_kv where path in (select path from appcloud_kv where starts_with(path,'backups/') order by created_at desc offset 20);
    select count(*) into v_n from appcloud_kv where starts_with(path,'backups/');
    return jsonb_build_object('s',200,'b',jsonb_build_object('ok',true,'pathname',v_path,'kept',v_n));
  end if;

  if p_action = 'list' then
    select coalesce(jsonb_agg(jsonb_build_object('pathname',path,'size',length(body),'uploadedAt',to_char(created_at at time zone 'utc','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')) order by created_at desc),'[]'::jsonb)
      into v_o from appcloud_kv where starts_with(path,'backups/');
    return jsonb_build_object('s',200,'b',jsonb_build_object('items',v_o));
  end if;

  if p_action = 'get' then
    v_path := coalesce(p_args->>'pathname','');
    if v_path <> '' and not starts_with(v_path,'backups/') then return jsonb_build_object('s',400,'b',jsonb_build_object('error','Bad path')); end if;
    select path, body, created_at into v_path, v_txt, v_now from (
      select path, body, to_char(created_at at time zone 'utc','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') created_at from appcloud_kv
      where starts_with(path,'backups/') and (coalesce(p_args->>'pathname','') = '' or path = p_args->>'pathname')
      order by appcloud_kv.created_at desc limit 1) t;
    if v_txt is null then return jsonb_build_object('s',404,'b',jsonb_build_object('error','Not found')); end if;
    return jsonb_build_object('s',200,'b',jsonb_build_object('pathname',v_path,'uploadedAt',v_now,'bundle',v_txt));
  end if;

  return jsonb_build_object('s',400,'b',jsonb_build_object('error','Unknown action'));
end $$;

revoke all on function public.appcloud_call(text,text,jsonb,text) from public;
grant execute on function public.appcloud_call(text,text,jsonb,text) to anon, authenticated;

-- ===== مفتاح الإدارة (غيّره إلى قيمتك السرّية الطويلة ثم شغّل هذا السطر) =====
-- select public.appcloud_set_key('اكتب-هنا-مفتاحًا-طويلًا-صعب-التخمين');
