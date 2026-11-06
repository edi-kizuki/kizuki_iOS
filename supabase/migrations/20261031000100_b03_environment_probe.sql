-- Related: [[014-b03-environment-pinning]], [[2026-10-25-vf08-env-bootstrap]].
-- Only reads the standalone marker. Safe to install before local bootstrap.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function public.kizuki_environment() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare marker jsonb; row_count integer;
begin
  if to_regclass('kizuki_env.environment_marker') is null then
    return jsonb_build_object('environment', 'unmarked');
  end if;
  select count(*) into row_count from kizuki_env.environment_marker;
  if row_count <> 1 then return jsonb_build_object('environment', 'unmarked'); end if;
  select jsonb_build_object('environment', environment, 'project_ref', project_ref)
    into marker from kizuki_env.environment_marker;
  return marker;
end $$;
revoke all on function public.kizuki_environment() from public;
grant execute on function public.kizuki_environment() to anon, authenticated, service_role;

create or replace function private.url_allowed_for_environment(url text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare marker jsonb := public.kizuki_environment();
begin
  if url is null or url ~ '[[:space:]]' or url like '%\\%' or url ~* 'enosggckdxjiaqtxalhg' then return false; end if;
  if marker->>'environment' = 'staging' and marker->>'project_ref' = 'ankgfqkgflcalmlreetu' then
    return url ~ '^https://ankgfqkgflcalmlreetu\.supabase\.co(/|$)';
  elsif marker->>'environment' = 'local' and marker->>'project_ref' is null then
    return url ~ '^http://(kong:8000|host\.docker\.internal:54321|127\.0\.0\.1:54321)(/|$)';
  end if;
  return false;
end $$;
revoke all on function private.url_allowed_for_environment(text) from public, anon, authenticated, service_role;
