// Rebuilds hub/walkthrough.html from templates/walkthrough.template.html,
// the interview file (decisions ledger) and hub/cards.json (open decisions).
// Run: bun hub/build.ts   (serve.ts also runs it on start.)
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DOCS_DIR, HUB_DIR, buildNoteIndex, escapeHtml, renderInline } from "./lib.ts";

const INTERVIEW = join(DOCS_DIR, "context", "2026-10-24-architecture-round-1-interview.md");

type Decision = { n: number; topic: string; text: string; group: string };

export function parseDecisions(md: string): Decision[] {
  const out: Decision[] = [];
  let group = "";
  for (const line of md.split("\n")) {
    const h = line.match(/^##\s+(.*)$/);
    if (h) group = h[1].trim();
    const m = line.match(/^\|\s*(\d+)\s*\|\s*(.*?)\s*\|\s*(.*)\|\s*$/);
    if (m) out.push({ n: Number(m[1]), topic: m[2], text: m[3].trim(), group });
  }
  return out.sort((a, b) => a.n - b.n);
}

// Notes that cannot be derived from the interview text alone.
const EXTRA_NOTES: Record<number, string> = {
  17: "Decided; the access grant is a user-side action, still pending. See the Figma access decision.",
  27: "Decided; the seat upgrade is a user-side action, still pending. See the Figma access decision.",
};

export function buildWalkthrough(): { decisions: number; open: number } {
  const idx = buildNoteIndex();
  const decisions = parseDecisions(readFileSync(INTERVIEW, "utf8"));
  const cards = JSON.parse(readFileSync(join(HUB_DIR, "cards.json"), "utf8")) as {
    updated: string;
    cards: any[];
  };
  const open = cards.cards.filter((c) => c.type === "decision" && c.status === "needs-you");

  // superseded-by map from "Supersedes #N" in later rows
  const supersededBy = new Map<number, number[]>();
  for (const d of decisions) {
    for (const m of d.text.matchAll(/Supersedes #(\d+)(?:\s+and\s+#(\d+))?/g)) {
      for (const g of [m[1], m[2]]) if (g) supersededBy.set(Number(g), [...(supersededBy.get(Number(g)) ?? []), d.n]);
    }
  }

  const rows = decisions
    .map((d) => {
      const sup = supersededBy.get(d.n);
      const notes: string[] = [];
      if (sup) notes.push(`Superseded by #${sup.join(", #")}.`);
      if (EXTRA_NOTES[d.n]) notes.push(EXTRA_NOTES[d.n]);
      return `<tr class="${sup ? "is-superseded" : ""}">
<td data-l="#">${d.n}</td>
<td data-l="Topic">${escapeHtml(d.topic)}</td>
<td data-l="Decision">${renderInline(d.text, idx)}</td>
<td data-l="Status"><span class="badge s-decided">decided</span></td>
<td data-l="Needs me now?">No</td>
<td data-l="Note">${notes.map(escapeHtml).join(" ")}</td>
</tr>`;
    })
    .join("\n");

  const openRows = open
    .map(
      (c, i) => `<tr class="is-open">
<td data-l="#">O${i + 1}</td>
<td data-l="Topic"><a href="${escapeHtml(c.href)}">${escapeHtml(c.title)}</a></td>
<td data-l="Decision">${escapeHtml(c.summary)}</td>
<td data-l="Status"><span class="badge s-needs">open</span></td>
<td data-l="Needs me now?"><strong>Yes</strong></td>
<td data-l="Note"></td>
</tr>`,
    )
    .join("\n");

  const ledger = `<div class="tbl ledger"><table>
<thead><tr><th>#</th><th>Topic</th><th>Decision</th><th>Status</th><th>Needs me now?</th><th>Note</th></tr></thead>
<tbody>
${openRows}
${rows}
</tbody></table></div>`;

  const tpl = readFileSync(join(HUB_DIR, "templates", "walkthrough.template.html"), "utf8");
  const html = tpl
    .replaceAll("{{LEDGER}}", ledger)
    .replaceAll("{{DECIDED_COUNT}}", String(decisions.length))
    .replaceAll("{{OPEN_COUNT}}", String(open.length))
    .replaceAll("{{UPDATED}}", cards.updated);
  writeFileSync(join(HUB_DIR, "walkthrough.html"), html);
  return { decisions: decisions.length, open: open.length };
}

if (import.meta.main) {
  const r = buildWalkthrough();
  console.log(`walkthrough.html rebuilt: ${r.decisions} decided, ${r.open} open`);
}
