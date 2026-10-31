-- Related: [[014-b03-environment-pinning]], [[2026-10-25-vf08-env-bootstrap]].
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
select is((select count(*) from kizuki_env.environment_marker), 1::bigint, 'E1 singleton');
select throws_ok($$insert into kizuki_env.environment_marker select * from kizuki_env.environment_marker$$,
 '23505', 'duplicate key value violates unique constraint "environment_marker_pkey"', 'E1 second row refused');
select throws_ok($$update kizuki_env.environment_marker set environment='local'$$, 'P0001', 'marker_immutable', 'E2 update denied');
select throws_ok($$delete from kizuki_env.environment_marker$$, 'P0001', 'marker_immutable', 'E2 delete denied');
select throws_ok($$truncate kizuki_env.environment_marker$$, 'P0001', 'marker_immutable', 'E2 truncate denied');
select is(public.kizuki_environment(), '{"environment":"local","project_ref":null}'::jsonb, 'E3 local probe exact shape');
set local role anon;
select throws_ok('select * from kizuki_env.environment_marker', '42501', 'permission denied for schema kizuki_env', 'E3 anon has no marker access');
select is(public.kizuki_environment(), '{"environment":"local","project_ref":null}'::jsonb, 'E3 anon probe');
reset role;
set local role authenticated;
select throws_ok('select * from kizuki_env.environment_marker', '42501', 'permission denied for schema kizuki_env', 'E3 authenticated has no marker access');
select is(public.kizuki_environment(), '{"environment":"local","project_ref":null}'::jsonb, 'E3 authenticated probe');
reset role;
set local role service_role;
select throws_ok('select * from kizuki_env.environment_marker', '42501', 'permission denied for schema kizuki_env', 'E3 service role has no marker access');
select is(public.kizuki_environment(), '{"environment":"local","project_ref":null}'::jsonb, 'E3 service role probe');
reset role;
select ok(private.url_allowed_for_environment('http://kong:8000/functions/v1/test'), 'E4 local kong');
select ok(not private.url_allowed_for_environment('http://kong:8000.evil/test'), 'E4 local lookalike');
select ok(not private.url_allowed_for_environment('https://ankgfqkgflcalmlreetu.supabase.co'), 'E4 local rejects staging');
-- Only this rollback-only test temporarily removes immutability to exercise invalid marker values and constraints.
alter table kizuki_env.environment_marker disable trigger user;
select throws_ok($$update kizuki_env.environment_marker set environment='production'$$, '23514', null, 'E1 production rejected');
select throws_ok($$update kizuki_env.environment_marker set project_ref='other'$$, '23514', null, 'E1 local with ref rejected');
select throws_ok($$update kizuki_env.environment_marker set environment='staging', project_ref='other', api_host='other'$$, '23514', null, 'E1 wrong staging ref rejected');
select throws_ok($$update kizuki_env.environment_marker set environment='staging', project_ref=null, api_host=null$$, '23514', null, 'E1 NULL cannot bypass staging CHECK');
update kizuki_env.environment_marker set environment='staging', project_ref='ankgfqkgflcalmlreetu', api_host='ankgfqkgflcalmlreetu.supabase.co';
select ok(private.url_allowed_for_environment('https://ankgfqkgflcalmlreetu.supabase.co'), 'E4 exact staging');
select ok(private.url_allowed_for_environment('https://ankgfqkgflcalmlreetu.supabase.co/functions/v1/test'), 'E4 staging path');
select ok(not private.url_allowed_for_environment(url), 'E4 rejected ' || label) from (values
 ('https://enosggckdxjiaqtxalhg.supabase.co', 'production'),
 ('https://ankgfqkgflcalmlreetu.supabase.co.evil', 'suffix'),
 ('http://ankgfqkgflcalmlreetu.supabase.co', 'scheme'),
 ('https://ankgfqkgflcalmlreetu.supabase.co:443', 'port'),
 ('https://ankgfqkgflcalmlreetu.supabase.co@evil.test', 'userinfo'),
 ('https://ankgfqkgflcalmlreetu.supabase.co./', 'trailing dot'),
 ('https://xankgfqkgflcalmlreetu.supabase.co', 'lookalike'),
 ('https://ankgfqkgflcalmlreetu.supabase.co/enosggckdxjiaqtxalhg', 'denied ref in path')
) t(url,label);
delete from kizuki_env.environment_marker;
select is(public.kizuki_environment(), '{"environment":"unmarked"}'::jsonb, 'E4 empty marker refused');
select ok(not private.url_allowed_for_environment('http://kong:8000'), 'E4 empty marker has no allowed URL');
drop schema kizuki_env cascade;
select is(public.kizuki_environment(), '{"environment":"unmarked"}'::jsonb, 'E4 absent marker refused');
select ok(not private.url_allowed_for_environment('https://ankgfqkgflcalmlreetu.supabase.co'), 'E4 absent marker has no allowed URL');
select * from finish();
rollback;
