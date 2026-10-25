// Kizuki hub server. Run: bun hub/serve.ts   (PORT=4747 to pin a port)
//   /            -> hub/ (static; *.md rendered as styled HTML, add ?raw for source)
//   /docs/...    -> repo docs/ (read-only, single source of truth; *.md rendered)
//   /repo/AGENTS.md, /repo/CLAUDE.md -> read-only, rendered
// Adds X-Robots-Tag: noindex to every response. GET/HEAD only. Binds to 127.0.0.1.
import { existsSync, readdirSync, realpathSync, statSync } from "node:fs";
import { basename, extname, join, sep } from "node:path";
import { buildWalkthrough } from "./build.ts";
import { DOCS_DIR, HUB_DIR, ROOT, buildNoteIndex, escapeHtml, pageShell, readText, renderMarkdownBody, splitFrontmatter } from "./lib.ts";

const HUB_BLOCKED = new Set(["serve.ts", "build.ts", "lib.ts", "templates"]);
const REPO_FILES = new Set(["AGENTS.md", "CLAUDE.md"]);

const HEADERS = { "X-Robots-Tag": "noindex, nofollow", "X-Content-Type-Options": "nosniff" };

function respond(body: BodyInit | null, status = 200, extra: Record<string, string> = {}) {
  return new Response(body, { status, headers: { ...HEADERS, ...extra } });
}
const html = (s: string, status = 200) => respond(s, status, { "Content-Type": "text/html; charset=utf-8" });

function notFound(path: string) {
  return html(
    pageShell({ title: "Not found", body: `<h1>404</h1><p>Nothing at <code>${escapeHtml(path)}</code>.</p><p><a href="/">Back to the hub</a></p>` }),
    404,
  );
}

/** Resolve a URL sub-path inside base, refusing traversal and symlink escapes. */
function safeResolve(base: string, sub: string): string | null {
  if (sub.includes("\0")) return null;
  const parts = sub.split("/").filter(Boolean);
  if (parts.some((p) => p === ".." || p.startsWith("."))) return null;
  const full = join(base, ...parts);
  if (!existsSync(full)) return full; // caller handles 404
  const real = realpathSync(full);
  const realBase = realpathSync(base);
  if (real !== realBase && !real.startsWith(realBase + sep)) return null;
  return real;
}

function listing(urlPath: string, dir: string) {
  const entries = readdirSync(dir)
    .filter((n) => !n.startsWith("."))
    .sort((a, b) => a.localeCompare(b));
  const base = urlPath.endsWith("/") ? urlPath : urlPath + "/";
  const items = entries
    .map((n) => {
      const isDir = statSync(join(dir, n)).isDirectory();
      return `<li><a href="${base}${encodeURIComponent(n)}${isDir ? "/" : ""}">${escapeHtml(n)}${isDir ? "/" : ""}</a></li>`;
    })
    .join("\n");
  const up = urlPath === "/docs/" ? `<a href="/">Hub home</a>` : `<a href="${base}../">Up</a>`;
  return html(pageShell({ title: urlPath, crumb: up, body: `<h1><code>${escapeHtml(urlPath)}</code></h1><p>Read-only view of the repo. Single source of truth.</p><ul>${items}</ul>` }));
}

function renderMd(file: string, urlPath: string) {
  const { body, meta } = splitFrontmatter(readText(file));
  const idx = buildNoteIndex();
  const h1 = body.match(/^#\s+(.+)$/m);
  const title = meta.title || (h1 ? h1[1] : basename(file, ".md"));
  const chips = [meta.status && `status: ${meta.status}`, meta.created && `created ${meta.created}`, meta.updated && `updated ${meta.updated}`]
    .filter(Boolean)
    .map((s) => escapeHtml(String(s)))
    .join(" · ");
  const source = urlPath.startsWith("/docs/") || urlPath.startsWith("/repo/") ? `${urlPath.replace(/^\//, "")}` : `hub${urlPath}`;
  return html(
    pageShell({
      title,
      body: renderMarkdownBody(body, idx),
      meta: `<code>${escapeHtml(source)}</code>${chips ? " · " + chips : ""} · <a href="${encodeURI(urlPath)}?raw">raw</a>`,
      crumb: `<a href="/">Hub</a>`,
    }),
  );
}

function serveFile(file: string, urlPath: string, raw: boolean): Response {
  const st = statSync(file);
  if (st.isDirectory()) {
    const index = join(file, "index.html");
    if (existsSync(index)) return serveFile(index, urlPath, raw);
    return listing(urlPath.endsWith("/") ? urlPath : urlPath + "/", file);
  }
  if (extname(file).toLowerCase() === ".md") {
    if (raw) return respond(Bun.file(file), 200, { "Content-Type": "text/plain; charset=utf-8" });
    return renderMd(file, urlPath);
  }
  return respond(Bun.file(file), 200, { "Cache-Control": "no-cache" });
}

function handle(req: Request): Response {
  if (req.method !== "GET" && req.method !== "HEAD") return respond("Method not allowed", 405, { Allow: "GET, HEAD" });
  const url = new URL(req.url);
  let path: string;
  try {
    path = decodeURIComponent(url.pathname);
  } catch {
    return respond("Bad request", 400);
  }
  const raw = url.searchParams.has("raw");
  if (path === "/favicon.ico") return respond(null, 204);

  if (path === "/docs" || path.startsWith("/docs/")) {
    const sub = path.slice("/docs".length);
    const file = safeResolve(DOCS_DIR, sub);
    if (!file || !existsSync(file)) return notFound(path);
    if (statSync(file).isDirectory() && !path.endsWith("/")) return respond(null, 301, { Location: path + "/" });
    return serveFile(file, path, raw);
  }

  if (path.startsWith("/repo/")) {
    const name = path.slice("/repo/".length);
    if (!REPO_FILES.has(name)) return notFound(path);
    return serveFile(join(ROOT, name), path, raw);
  }

  const first = path.split("/").filter(Boolean)[0];
  if (first && HUB_BLOCKED.has(first)) return notFound(path);
  const file = safeResolve(HUB_DIR, path === "/" ? "" : path);
  if (!file || !existsSync(file)) return notFound(path);
  if (statSync(file).isDirectory() && path !== "/" && !path.endsWith("/")) return respond(null, 301, { Location: path + "/" });
  return serveFile(file, path, raw);
}

const built = buildWalkthrough();

const preferred = process.env.PORT ? [Number(process.env.PORT)] : [4747, 4748, 4749, 4750, 0];
let server: ReturnType<typeof Bun.serve> | undefined;
for (const port of preferred) {
  try {
    server = Bun.serve({ hostname: "127.0.0.1", port, fetch: handle });
    break;
  } catch (e: any) {
    if (e?.code !== "EADDRINUSE") throw e;
  }
}
if (!server) throw new Error("No free port found");
console.log(`Kizuki hub: http://127.0.0.1:${server.port}/  (pid ${process.pid})`);
console.log(`walkthrough rebuilt: ${built.decisions} decided, ${built.open} open`);
