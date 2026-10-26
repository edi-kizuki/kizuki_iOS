// Shared helpers for the Kizuki hub: markdown rendering, wikilink resolution, doc index.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join, relative, sep } from "node:path";

export const HUB_DIR = import.meta.dir;
export const ROOT = join(HUB_DIR, "..");
export const DOCS_DIR = join(ROOT, "docs");

export const escapeHtml = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

/** Split off YAML-ish frontmatter. Returns the body and a flat key/value map. */
export function splitFrontmatter(src: string): { body: string; meta: Record<string, string> } {
  const m = src.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/);
  if (!m) return { body: src, meta: {} };
  const meta: Record<string, string> = {};
  for (const line of m[1].split(/\r?\n/)) {
    const kv = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (kv) meta[kv[1]] = kv[2].trim();
  }
  return { body: src.slice(m[0].length), meta };
}

function walk(dir: string, out: string[]) {
  let entries: string[];
  try {
    entries = readdirSync(dir);
  } catch {
    return;
  }
  for (const name of entries) {
    if (name.startsWith(".") || name === "node_modules") continue;
    const full = join(dir, name);
    let st;
    try {
      st = statSync(full);
    } catch {
      continue;
    }
    if (st.isDirectory()) walk(full, out);
    else if (name.toLowerCase().endsWith(".md")) out.push(full);
  }
}

/** Map of lowercase note name -> served URL, for [[wikilinks]]. docs/ wins over hub/ on collisions. */
export function buildNoteIndex(): Map<string, string> {
  const idx = new Map<string, string>();
  const hubFiles: string[] = [];
  walk(HUB_DIR, hubFiles);
  for (const f of hubFiles) {
    idx.set(basename(f, ".md").toLowerCase(), "/" + relative(HUB_DIR, f).split(sep).map(encodeURIComponent).join("/"));
  }
  const docFiles: string[] = [];
  walk(DOCS_DIR, docFiles);
  for (const f of docFiles) {
    idx.set(
      basename(f, ".md").toLowerCase(),
      "/docs/" + relative(DOCS_DIR, f).split(sep).map(encodeURIComponent).join("/"),
    );
  }
  // Root instruction files, served read-only under /repo/.
  for (const n of ["AGENTS", "CLAUDE"]) idx.set(n.toLowerCase(), `/repo/${n}.md`);
  return idx;
}

/** Replace [[wikilinks]] with markdown links (outside code). Unresolved links become muted spans. */
export function resolveWikilinks(md: string, idx: Map<string, string>): string {
  const wiki = (_: string, target: string, alias?: string) => {
    const name = target.split("#")[0].trim();
    const label = (alias ?? target).trim();
    const url = idx.get(name.toLowerCase());
    return url ? `[${label}](${url})` : `<span class="missing" title="Not in repo yet">${escapeHtml(label)}</span>`;
  };
  const lines = md.split("\n");
  let inFence = false;
  return lines
    .map((line) => {
      if (/^\s*(```|~~~)/.test(line)) {
        inFence = !inFence;
        return line;
      }
      if (inFence) return line;
      return line
        .split(/(`[^`]*`)/)
        .map((part) => (part.startsWith("`") ? part : part.replace(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g, wiki)))
        .join("");
    })
    .join("\n");
}

const MD_OPTS = { tables: true, strikethrough: true, tasklists: true, autolinks: true, headings: true } as any;

export function renderMarkdownBody(md: string, idx: Map<string, string>): string {
  const html = (Bun as any).markdown.html(resolveWikilinks(md, idx), MD_OPTS) as string;
  return html.replace(/<table>/g, '<div class="tbl"><table>').replace(/<\/table>/g, "</table></div>");
}

/** Render a short inline snippet (no wrapping <p>). */
export function renderInline(md: string, idx: Map<string, string>): string {
  const html = (Bun as any).markdown.html(resolveWikilinks(md, idx), MD_OPTS) as string;
  return html.trim().replace(/^<p>/, "").replace(/<\/p>$/, "");
}

export function pageShell(opts: { title: string; body: string; meta?: string; crumb?: string }): string {
  const { title, body, meta = "", crumb = "" } = opts;
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<meta name="color-scheme" content="light dark">
<title>${escapeHtml(title)} · Kizuki hub</title>
<link rel="stylesheet" href="/assets/hub.css">
</head>
<body>
<header class="topbar"><div class="wrap">
<a class="brand" href="/">Kizuki <span>hub</span></a>
<nav><a href="/">Home</a><a href="/walkthrough.html">Walkthrough</a><a href="/docs/">Repo docs</a></nav>
</div></header>
<main class="wrap doc">
${crumb ? `<p class="crumb">${crumb}</p>` : ""}
${meta ? `<p class="docmeta">${meta}</p>` : ""}
<article class="md">
${body}
</article>
</main>
</body>
</html>`;
}

export function readText(path: string): string {
  return readFileSync(path, "utf8");
}
