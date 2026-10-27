alter table public.profiles
    add column onboarding_completed_at timestamptz,
    add column eligible_at timestamptz,
    add column account_status text not null default 'active'
        check (account_status in ('active', 'deleting', 'suspended'));

insert into public.profiles(id)
    select id from auth.users
    on conflict (id) do nothing;

insert into public.profile_settings(profile_id)
    select id from public.profiles
    on conflict (profile_id) do nothing;

notify pgrst, 'reload schema';
