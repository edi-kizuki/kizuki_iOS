// Related: [[014-b03-environment-pinning]], [[2026-10-25-vf08-env-bootstrap]].
import { environmentGuard } from "./env_guard.ts";

export function serveGuarded(handler: (request: Request) => Response | Promise<Response>) {
  const guard = environmentGuard({
    url: Deno.env.get("SUPABASE_URL") ?? "",
    secret: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  });
  return Deno.serve((request) => guard(request, handler));
}
