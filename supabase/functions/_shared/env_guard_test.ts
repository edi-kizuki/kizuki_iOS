// Related: [[014-b03-environment-pinning]]. All HTTP is stubbed; no network permission.
import { environmentGuard, STAGING_API_HOST, STAGING_REF, DENIED_REFS } from "./env_guard.ts";
const base = `https://${STAGING_API_HOST}`;
const good = { environment: "staging", project_ref: STAGING_REF };
function assert(value: unknown) { if (!value) throw Error("assertion failed"); }
function harness(url = base) {
  let calls = 0, handled = 0, time = 1000;
  let marker: unknown = good, code = 200, failed = false;
  const guard = environmentGuard({ url, secret: "synthetic", now: () => time, fetch: (() => {
    calls++;
    if (failed) return Promise.reject(Error("offline"));
    return Promise.resolve(Response.json(marker, { status: code }));
  }) as typeof fetch });
  return {
    run: (requestURL = base) => guard(new Request(requestURL), () => { handled++; return new Response("ok"); }),
    calls: () => calls, handled: () => handled,
    marker: (value: unknown) => { marker = value; }, code: (value: number) => { code = value; },
    fail: () => { failed = true; }, advance: () => { time += 60001; },
  };
}
Deno.test("F1/F6 denied ref anywhere refuses before any client call", async () => {
  for (const url of [`https://${DENIED_REFS[0]}.supabase.co`, `${base}/${DENIED_REFS[0]}`, `${base}?x=${DENIED_REFS[0]}`, `${base}#${DENIED_REFS[0]}`]) {
    const h = harness(url); const response = await h.run();
    assert(response.status === 503 && h.calls() === 0 && h.handled() === 0);
    assert((await response.json()).error === "environment_refused");
  }
});
Deno.test("F2 staging API and function hosts pass", async () => {
  const h = harness(); assert((await h.run()).status === 200);
  assert((await h.run(`https://${STAGING_REF}.functions.supabase.co/test`)).status === 200);
  assert(h.calls() === 1 && h.handled() === 2);
});
Deno.test("F3 wrong request host never reaches marker or handler", async () => {
  for (const url of [`https://${DENIED_REFS[0]}.supabase.co`, `${base}.evil.test`, "http://kong:8000", `http://${STAGING_API_HOST}`, `${base}:8443`]) {
    const h = harness(); assert((await h.run(url)).status === 503); assert(h.calls() === 0 && h.handled() === 0);
  }
});
Deno.test("F4 local requires a local marker", async () => {
  const h = harness("http://kong:8000"); assert((await h.run("http://kong:8000/test")).status === 503);
  h.marker({ environment: "local", project_ref: null });
  assert((await h.run("http://kong:8000/test")).status === 200);
});
Deno.test("F5 failure never cached; success expires at 60 seconds", async () => {
  for (const marker of [{ environment: "production" }, { environment: "unmarked" }, { ...good, project_ref: "other" }, null, [], { ...good, extra: true }]) {
    const h = harness(); h.marker(marker);
    assert((await h.run()).status === 503 && h.handled() === 0);
    h.marker(good); assert((await h.run()).status === 200 && h.calls() === 2);
    await h.run(); assert(h.calls() === 2);
    h.advance(); await h.run(); assert(h.calls() === 3);
  }
  const h = harness(); h.fail(); await h.run(); await h.run(); assert(h.calls() === 2 && h.handled() === 0);
  const bad = harness(); bad.code(404); assert((await bad.run()).status === 503);
});
Deno.test("F7 only shared serve owns the server entrypoint", async () => {
  async function walk(path: string): Promise<string[]> {
    const files: string[] = [];
    for await (const e of Deno.readDir(path)) {
      if (e.isDirectory) files.push(...await walk(`${path}/${e.name}`));
      else if (e.name.endsWith(".ts") && !e.name.endsWith("_test.ts")) files.push(`${path}/${e.name}`);
    }
    return files;
  }
  const sites = [];
  for (const path of await walk("supabase/functions")) {
    if (/Deno\s*\.\s*serve\s*\(/.test(await Deno.readTextFile(path))) sites.push(path);
  }
  assert(sites.length === 1 && sites[0] === "supabase/functions/_shared/serve.ts");
});
