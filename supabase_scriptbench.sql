-- ScriptBench submissions: run once in the SQL Editor of your Supabase project.
-- (The table and functions keep the rxlab_ prefix from the tool's earlier name, RxLab;
-- ScriptBench.html calls them by these names, so leave them as they are.)
-- Safe to re-run.
--
-- Security model: the browser (publishable / anon key) can only call two functions.
--   rxlab_submit(p)              insert one save; cannot read, update, or delete anything
--   rxlab_pickup(email, code)    return the latest save for that email + pickup code only
-- Grading reads the table with the SECRET (service_role) key, which never goes in ScriptBench.html.
--
-- Who may submit: edit the email pattern in BOTH functions (search for EMAIL CHECK)
-- to your school's domain, e.g. '^[a-z0-9._%+-]+@myschool\.edu$', and keep
-- RXLAB_CONFIG.emailPattern in ScriptBench.html in step with it.

create table if not exists public.rxlab_submissions (
  id            bigint generated always as identity primary key,
  received_at   timestamptz not null default now(),
  client_id     uuid not null unique,          -- makes a retried send a no-op
  student_email text not null,
  student_name  text,
  product_id    text,
  rx_number     text,
  pickup_code   text,
  payload       jsonb not null
);

create index if not exists rxlab_submissions_student on public.rxlab_submissions (student_email, received_at);
create index if not exists rxlab_submissions_pickup on public.rxlab_submissions (student_email, pickup_code, received_at);

alter table public.rxlab_submissions enable row level security;
revoke all on public.rxlab_submissions from anon, authenticated;
grant select on public.rxlab_submissions to service_role;

create or replace function public.rxlab_submit(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(trim(coalesce(p->>'student_email', '')));
  v_id    uuid;
begin
  if octet_length(p::text) > 32000 then
    return jsonb_build_object('ok', false, 'error', 'payload too large');
  end if;
  -- EMAIL CHECK: restrict to your school's domain
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    return jsonb_build_object('ok', false, 'error', 'email not allowed');
  end if;
  begin
    v_id := (p->>'client_id')::uuid;
  exception when others then
    return jsonb_build_object('ok', false, 'error', 'bad client_id');
  end;

  insert into public.rxlab_submissions (client_id, student_email, student_name, product_id, rx_number, pickup_code, payload)
  values (v_id, v_email, left(p->>'student_name', 120), left(p->>'product_id', 60), left(p->>'rx_number', 20),
          nullif(left(upper(regexp_replace(coalesce(p->>'pickup_code', ''), '[^A-Za-z0-9]', '', 'g')), 12), ''), p)
  on conflict (client_id) do nothing;

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.rxlab_submit(jsonb) from public;
grant execute on function public.rxlab_submit(jsonb) to anon;

-- Lab PC pickup: the student signs in on the lab PC and types the code their own
-- device showed when they saved. Returns the latest save of that one Rx, nothing else.
create or replace function public.rxlab_pickup(p_email text, p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_code  text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  v_row   public.rxlab_submissions%rowtype;
begin
  -- EMAIL CHECK: restrict to your school's domain
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or v_code !~ '^[2-9A-HJ-NP-Z]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'not found');
  end if;
  select * into v_row from public.rxlab_submissions
   where student_email = v_email and pickup_code = v_code
   order by received_at desc, id desc limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not found');
  end if;
  return jsonb_build_object('ok', true, 'record', v_row.payload->'record',
                            'student_name', v_row.student_name, 'saved_at', v_row.payload->>'saved_at');
end;
$$;

revoke all on function public.rxlab_pickup(text, text) from public;
grant execute on function public.rxlab_pickup(text, text) to anon;
