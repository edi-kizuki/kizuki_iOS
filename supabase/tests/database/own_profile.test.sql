begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users(id) values
    ('00000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000002');
select is((select count(*) from public.profiles), 2::bigint, 'auth trigger creates profiles');
select is((select count(*) from public.profile_settings), 2::bigint, 'auth trigger creates private settings');
select ok((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass), 'profile RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.profile_settings'::regclass), 'settings RLS enabled');

set local role anon;
select throws_ok('select * from public.profiles', '42501', 'permission denied for table profiles', 'anonymous read denied');
reset role;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
select results_eq('select id from public.profiles',
    $$values ('00000000-0000-0000-0000-000000000001'::uuid)$$, 'only own profile visible');
select results_eq('select profile_id from public.profile_settings',
    $$values ('00000000-0000-0000-0000-000000000001'::uuid)$$, 'private settings owner only');
select throws_ok($$update public.profiles set handle = 'changed'$$,
    '42501', 'permission denied for table profiles', 'no client profile edits in foundation');
select throws_ok($$insert into public.profile_settings(profile_id) values ('00000000-0000-0000-0000-000000000002')$$,
    '42501', 'permission denied for table profile_settings', 'no foreign settings writes');
reset role;

delete from auth.users where id = '00000000-0000-0000-0000-000000000001';
select is((select count(*) from public.profile_settings), 1::bigint, 'auth deletion cascades private state');
select * from finish();
rollback;
