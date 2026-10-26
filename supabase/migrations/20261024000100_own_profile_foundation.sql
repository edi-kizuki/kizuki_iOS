-- Local foundation only. Public discovery and profile editing are later increments.
create extension if not exists citext with schema extensions;

create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    handle extensions.citext unique,
    display_handle text,
    avatar_path text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint handle_format check (
        handle is null or (
            char_length(handle::text) between 3 and 24
            and handle::text ~ '^[A-Za-z0-9][A-Za-z0-9_.]*[A-Za-z0-9]$'
            and position('..' in handle::text) = 0
        )
    )
);

-- Private state is separate even though this increment does not expose it in the app.
create table public.profile_settings (
    profile_id uuid primary key references public.profiles(id) on delete cascade,
    onboarding_state jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.profile_settings enable row level security;
revoke all on public.profiles, public.profile_settings from anon, authenticated;
grant select on public.profiles, public.profile_settings to authenticated;

create policy profiles_read_own on public.profiles for select to authenticated
    using ((select auth.uid()) = id);
create policy settings_read_own on public.profile_settings for select to authenticated
    using ((select auth.uid()) = profile_id);

create function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger profiles_updated_at before update on public.profiles
    for each row execute function public.set_updated_at();
create trigger settings_updated_at before update on public.profile_settings
    for each row execute function public.set_updated_at();

-- Never copy email, name, or untrusted metadata into a public profile.
create function public.provision_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
    insert into public.profiles(id) values (new.id);
    insert into public.profile_settings(profile_id) values (new.id);
    return new;
end;
$$;
revoke all on function public.provision_profile() from public, anon, authenticated;
revoke all on function public.set_updated_at() from public, anon, authenticated;
create trigger auth_user_profile after insert on auth.users
    for each row execute function public.provision_profile();
