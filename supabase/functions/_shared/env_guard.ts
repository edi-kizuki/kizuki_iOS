// Related: [[014-b03-environment-pinning]], [[2026-10-25-vf08-env-bootstrap]].
export const STAGING_REF = "ankgfqkgflcalmlreetu";
export const STAGING_API_HOST = "ankgfqkgflcalmlreetu.supabase.co";
export const DENIED_REFS = ["enosggckdxjiaqtxalhg"];
const LOCAL = new Set(["http://kong:8000", "http://host.docker.internal:54321", "http://127.0.0.1:54321", "http://localhost:54321"]);

type Options = {
  url: string;
  secret: string;
  fetch?: typeof fetch;
  now?: () => number;
};

function parse(value: string): URL {
  if (DENIED_REFS.some((ref) => value.toLowerCase().includes(ref)) || /[\\\s]/.test(value)) throw Error("E_REF_DENIED");
  const url = new URL(value);
  if (url.username || url.password || url.hash) throw Error("E_HOST_NOT_ALLOWED");
  return url;
}

export function environmentGuard(options: Options) {
  const requestFetch = options.fetch ?? fetch;
  const now = options.now ?? Date.now;
  let validUntil = 0;
  // Configuration is checked at cold start. Failed checks remain refused on every request.
  let base: URL | undefined;
  let local = false;
  try {
    base = parse(options.url);
    local = LOCAL.has(options.url);
    if (!local && options.url !== `https://${STAGING_API_HOST}`) base = undefined;
  } catch { base = undefined; }

  return async (request: Request, handler: (request: Request) => Response | Promise<Response>): Promise<Response> => {
    try {
      if (!base) throw Error("E_HOST_NOT_ALLOWED");
      const incoming = parse(request.url);
      const allowed = local ? LOCAL.has(incoming.origin)
        : incoming.origin === `https://${STAGING_API_HOST}` || incoming.origin === `https://${STAGING_REF}.functions.supabase.co`;
      if (!allowed) throw Error("E_HOST_NOT_ALLOWED");
      if (validUntil <= now()) {
        if (!options.secret) throw Error("E_CREDENTIAL");
        const endpoint = `${base.origin}/rest/v1/rpc/kizuki_environment`;
        const response = await requestFetch(endpoint, {
          method: "POST", redirect: "error", signal: AbortSignal.timeout(10000),
          headers: { apikey: options.secret, "Content-Type": "application/json" }, body: "{}",
        });
        if (response.status !== 200 || response.redirected || (response.url && response.url !== endpoint)) throw Error("E_MARKER_WRONG");
        const marker = await response.json();
        if (!marker || Object.keys(marker).sort().join(",") !== "environment,project_ref" ||
            (local ? marker.environment !== "local" || marker.project_ref !== null
              : marker.environment !== "staging" || marker.project_ref !== STAGING_REF)) throw Error("E_MARKER_WRONG");
        validUntil = now() + 60000;
      }
    } catch {
      validUntil = 0;
      console.error("environment_refused", "E_ENVIRONMENT");
      return Response.json({ error: "environment_refused" }, { status: 503 });
    }
    return await handler(request);
  };
}
