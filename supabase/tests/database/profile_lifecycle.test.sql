begin;
create extension if not exists pgtap with schema extensions;
select plan(9);
insert into auth.users(id) values
    ('00000000-0000-0000-0000-000000000071'),
    ('00000000-0000-0000-0000-000000000072');
select is((select account_status from public.profiles where id = '00000000-0000-0000-0000-000000000071'), 'active', 'new account status defaults active');
select ok((select eligible_at is null and onboarding_completed_at is null from public.profiles where id = '00000000-0000-0000-0000-000000000071'), 'no fabricated eligibility or completion');
select throws_ok($$update public.profiles set account_status = 'invalid'$$, '23514', null, 'invalid account state rejected');
update public.profiles set eligible_at = now(), onboarding_completed_at = now(), account_status = 'suspended'
    where id = '00000000-0000-0000-0000-000000000071';
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000071';
select is((select count(*) from public.profiles), 1::bigint, 'lifecycle projection remains owner only');
select is((select account_status from public.profiles), 'suspended', 'owner reads account state');
select ok((select eligible_at is not null and onboarding_completed_at is not null from public.profiles), 'owner reads lifecycle dates');
select throws_ok($$update public.profiles set eligible_at = now()$$, '42501', null, 'client cannot self-certify eligibility');
reset role;
set local role anon;
select throws_ok('select eligible_at from public.profiles', '42501', null, 'anonymous lifecycle read denied');
reset role;
select ok((select relrowsecurity from pg_class where oid = 'public.profile_settings'::regclass), 'private settings RLS retained');
select * from finish();
rollback;
