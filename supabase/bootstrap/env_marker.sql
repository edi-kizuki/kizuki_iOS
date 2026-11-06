-- Related: [[014-b03-environment-pinning]], [[2026-10-25-vf08-env-bootstrap]].
-- Standalone bootstrap, never a migration. Settings are supplied by the guarded driver.
begin;
select pg_advisory_xact_lock(703003);
do $$
declare
  local_reset boolean := coalesce(current_setting('kizuki.bootstrap_environment', true), '') = 'local';
  has_versions boolean;
begin
  if current_user <> 'postgres' then raise exception 'bootstrap_role'; end if;
  if to_regclass('kizuki_env.environment_marker') is not null then
    raise exception 'already_bootstrapped';
  end if;
  if not local_reset then
    if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
               where n.nspname in ('public', 'private', 'kizuki_env') and c.relkind in ('r','p','v','m','f')) then
      raise exception 'not_pristine';
    end if;
    if to_regclass('supabase_migrations.schema_migrations') is not null then
      execute 'select exists (select 1 from supabase_migrations.schema_migrations)' into has_versions;
      if has_versions then raise exception 'not_pristine'; end if;
    end if;
  end if;
end $$;
create schema kizuki_env;
revoke all on schema kizuki_env from public, anon, authenticated, service_role;
create table kizuki_env.environment_marker (
  singleton boolean primary key default true check (singleton),
  environment text not null check (environment in ('local', 'staging')),
  project_ref text,
  api_host text,
  bootstrapped_at timestamptz not null default now(),
  bootstrapped_via text not null check (bootstrapped_via in ('cli', 'mcp', 'local')),
  bootstrap_sha256 text not null check (bootstrap_sha256 ~ '^[0-9a-f]{64}$'),
  check ((environment = 'staging' and project_ref is not null and api_host is not null
          and project_ref = 'ankgfqkgflcalmlreetu' and api_host = 'ankgfqkgflcalmlreetu.supabase.co')
      or (environment = 'local' and project_ref is null and api_host is null))
);
alter table kizuki_env.environment_marker enable row level security;
revoke all on kizuki_env.environment_marker from public, anon, authenticated, service_role;
create function kizuki_env.deny_change() returns trigger language plpgsql set search_path = '' as
$$ begin raise exception 'marker_immutable'; end $$;
revoke all on function kizuki_env.deny_change() from public, anon, authenticated, service_role;
create trigger no_change before update or delete on kizuki_env.environment_marker
  for each row execute function kizuki_env.deny_change();
create trigger no_truncate before truncate on kizuki_env.environment_marker
  for each statement execute function kizuki_env.deny_change();
insert into kizuki_env.environment_marker (environment, project_ref, api_host, bootstrapped_via, bootstrap_sha256)
select case when local_reset then 'local' else 'staging' end,
       case when local_reset then null else 'ankgfqkgflcalmlreetu' end,
       case when local_reset then null else 'ankgfqkgflcalmlreetu.supabase.co' end,
       case when local_reset then 'local' else 'cli' end,
       current_setting('kizuki.bootstrap_sha256')
from (select coalesce(current_setting('kizuki.bootstrap_environment', true), '') = 'local' as local_reset) s;
commit;
