# Project Scope: cloud-diagram-icons

*The icon knowledge layer for AI-generated draw.io diagrams. Microsoft first, multi-cloud later.*

**Status:** Agreed, pre-build (rev 2, post-research pivot)
**Repo:** github.com/jpsantoscosta/cloud-diagram-icons
**Owner:** JP (jpsantoscosta)
**Last updated:** 03 August 2026

---

## 1. Problem

LLMs generating draw.io XML (via the official draw.io MCP servers) have no way to look up the correct modern Microsoft icon for a service. draw.io's built-in Azure library is actually current and complete for Azure (766 icons, verified against source, see section 7a), but an LLM cannot realistically know the exact style path for each of those 766 shapes, and the built-in set has near-zero coverage of M365, Dynamics, and full Power Platform. The result: AI-generated architecture diagrams with generic rectangles or wrong icons, despite the right icons often already existing in the tool.

Human-facing icon availability is largely solved (built-in library for Azure, dwarfered/azure-architecture-icons-for-drawio for one-click Azure + M365 libraries). The unsolved gap is **machine-readable icon lookup**.

## 2. What this project is

**The icon lookup layer that sits between LLMs and draw.io.** It does not generate diagrams and it does not ship yet another human shape library. It gives any LLM (Claude, Copilot, Cursor) the exact draw.io style string for a named Microsoft service, so the official draw.io MCP tooling can render it correctly.

One-sentence pitch: *Official draw.io MCP + this icon server = AI-generated Azure diagrams with real portal icons.*

## 2a. Naming

Verified free on npm and GitHub as of 26 July 2026. Reserve the npm name early (placeholder publish is fine); npm is first-come.

| Thing | Name |
|---|---|
| GitHub repo (monorepo) | `jpsantoscosta/cloud-diagram-icons` |
| Icon index | `icons.json` in repo root |
| Supplemental libraries (gap coverage only) | `libraries/` in repo |
| MCP server (npm) | `cloud-diagram-icons-mcp` |
| Skill | `cloud-diagram-icons` |

Rationale: descriptive beats brandable for a new project (search: "cloud diagram icons mcp"); provider-neutral for the AWS/GCP roadmap; tool-neutral enough to survive beyond draw.io. Rejected: `drawio-cloud-icons` (tool lock-in, one name collision), `archicons` (brandable but opaque, 10 partial collisions).

## 3. What this project is NOT (out of scope)

- **No diagram generation.** The official draw.io MCP project (jgraph/drawio-mcp) already ships an MCP app server with inline previews, an MCP tool server (`npx @drawio/mcp`), a Skill + CLI for Claude Code with PNG/SVG/PDF export, and a project-instructions method. We compose with it, we do not duplicate it.
- **No general-purpose human shape libraries.** draw.io's built-in Azure library is current, and dwarfered/azure-architecture-icons-for-drawio covers one-click Azure + M365 libraries. Building another would be the fifth stale-in-two-years repo in that space. We only ship supplemental libraries for estate the built-in set lacks (M365, Dynamics, full Power Platform), as a byproduct of the gap pipeline.
- **No Copilot Extension.** GitHub sunset GitHub App-based Copilot Extensions on 10 Nov 2025 in favour of MCP. MCP is the single integration path for Copilot, Claude, Cursor, VS Code, Visual Studio, and Copilot CLI.
- **No third-party icon sources.** Azure icon references point at draw.io's own built-in assets (paths, not copies). Supplemental icons for gaps come exclusively from Microsoft's official downloadable SVG packs.
- **No icon ownership claims.** Icons remain Microsoft's property under Microsoft's terms of use, which permit copying, distribution, and use in architecture diagrams and documentation. The icon mirror (D4) redistributes on that permitted-use basis, stated plainly in the README per source pack. Azure lookup entries redistribute nothing at all (path strings into draw.io's own bundled assets).
- **No web app in v1.** Deferred until real demand exists (see section 8). The stdio MCP server runs locally on the user's machine and uses the user's own AI subscription, so there is no hosting cost and no token-cost problem to solve.

## 4. Deliverables

### D1. icons.json (Phase 1, the core artefact)
Machine-readable index. Provider-aware schema from day one. Two icon reference types:

```json
{
  "provider": "microsoft",
  "category": "ai_machine_learning",
  "name": "Azure OpenAI",
  "aliases": ["OpenAI", "AOAI"],
  "w": 48, "h": 48,
  "ref": "builtin",
  "style": "image;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/azure2/ai_machine_learning/Azure_OpenAI.svg;"
}
```

- `ref: "builtin"` — Azure estate. Style is a tiny path string into draw.io's bundled azure2 assets. No SVG shipped, kilobytes total.
- `ref: "embedded"` — gap estate (M365, Dynamics, full Power Platform). Style carries base64 SVG from official Microsoft packs.

### D2. Build pipeline (Phase 1)
- **Index generator:** parses `Sidebar-Azure2.js` (or the `img/lib/azure2` tree) from jgraph/drawio to produce all builtin entries automatically. Aliases curated manually on top.
- **Gap converter:** downloads official Microsoft SVG packs for M365/Dynamics/Power Platform, produces embedded entries plus supplemental mxlibrary files in `libraries/`.
- **GitHub Action, monthly:** diff against jgraph/drawio (builtin freshness) and Microsoft packs (gap freshness), commit changes. The index never goes stale, which is the failure mode of every existing icon repo.

### D3. Icon MCP server (Phase 2)
npm package `cloud-diagram-icons-mcp`, stdio transport, local execution. Tools:
- `search_icons(query)` — returns the exact draw.io style string for a service name, alias-aware
- `get_icon(name)`
- `list_categories(provider?)`
- `list_providers`

Lookups only. The LLM calls this server for icons, then the official draw.io MCP server to build/open/export the diagram. Fetches `icons.json` from the GitHub repo at startup so icon updates ship without reinstalls.

Distribution: npm + GitHub MCP Registry (Copilot discovery surface) + Anthropic-side skill (Claude discovery surface).

### D4. Microsoft icon mirror (Phase 1.5)
An always-current, categorised mirror of the official Microsoft icon estate, kept fresh by the same monthly Action. Standalone value for non-AI users (PowerPoint, docs, wikis) and the source for all embedded entries in icons.json.

Structure:
```
icons/microsoft/<estate>/<category>/<normalised-name>.svg
manifest.json   (per icon: source pack, pack version, sha256, last sync date)
```
- Normalised kebab-case filenames, one folder per estate (azure, m365, entra, power-platform, dynamics, fabric)
- Consumers hotlink via jsDelivr for free CDN delivery
- Git history doubles as the changelog of Microsoft icon additions/renames

**Protection measures (pipeline integrity and supply-chain):**
1. **Official sources only, allowlisted.** The Action downloads exclusively from an allowlist of microsoft.com / learn.microsoft.com domains. Any source URL outside the allowlist fails the run.
2. **SVG sanitisation.** Every SVG is sanitised before commit: strip `<script>`, event handlers (`on*=`), external references (`href`/`xlink:href` to remote URLs), and embedded foreignObject HTML. Hotlinked SVGs execute in consumers' pages; a poisoned upstream zip must not become an XSS vector.
3. **Sanity gates before commit.** Per-run checks: file count within ±20% of previous sync (a collapsed zip must not wipe the mirror), every file parses as valid SVG, no file over 500 KB. Any gate failure aborts with no partial state.
4. **PR-based updates, protected main.** The Action never pushes to main. It opens a PR with a diff summary (added/renamed/removed counts per estate) for JP's review. Branch protection on main: PRs only, no force-push, linear history.
5. **Loud failure.** A broken scraper or failed gate opens a GitHub issue automatically. The manifest's per-source last-sync date makes staleness visible, so "up to date" is verifiable, never assumed.
6. **Pinned toolchain.** All GitHub Actions pinned by commit SHA, Dependabot enabled for the pipeline's dependencies.
7. **Integrity manifest.** sha256 per file in manifest.json; consumers can verify, and the diff gate uses it to detect silent content changes upstream.
8. **Rollback.** Any bad sync reverts with a single git revert of the merge commit; the manifest keeps history consistent.

### D5. Skill / instructions layer (Phase 2)
Thin wrapper for Claude (skill) and Copilot (instructions file) that:
- Instructs the model to resolve every Microsoft service through the icon server before generating
- Encodes JP's layout standards (existing drawio-standards skill)
- References draw.io's official AI style reference for XML conventions

## 5. Validation test (do this FIRST, before writing much code)

1. Install `@drawio/mcp`
2. Have Claude place one shape using a builtin style string, e.g. `image;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/azure2/ai_machine_learning/Azure_OpenAI.svg;`
3. Confirm it renders correctly in the draw.io editor (web)
4. Repeat in the desktop app to confirm bundled asset freshness matches the web app
5. Repeat once with an embedded base64 style string (any official M365 SVG) for the gap path

If 2-3 work, the core thesis works. If 4 shows the desktop bundle lagging, record it in the decisions log and note web-first support. If 5 fails, the gap pipeline needs a different embedding approach before any converter code exists.

## 6. Build order

Progress tracking: mark steps `[x]` when done. The first unchecked step is the current step. AI sessions derive progress from this checklist, never from memory.

- [x] 1. Validation test (section 5) — passed 04 Aug 2026, see decisions log
- [x] 2. Index generator → icons.json for Azure builtin entries (scripts/build-index.ps1, 766 entries, 04 Aug 2026)
- [x] 3. Manual quality pass: naming, aliases for common services (top ~100 first) — 117 entries accepted by JP 05 Aug 2026 (official names canonical, builtin titles as aliases); refine as usage reveals gaps
- [ ] 4. Gap converter → embedded entries + supplemental libraries for M365/Dynamics/Power Platform — DEFERRED per JP 05 Aug 2026: get the core (builtin index → publish → MCP) working first
- [ ] 5. Icon mirror (D4): icons/ tree, manifest.json, sanitisation + sanity gates — DEFERRED with step 4
- [x] 6. GitHub Action (monthly diff against jgraph/drawio, PR-based, loud failure) — .github/workflows/refresh-index.yml, 05 Aug 2026; Microsoft pack diffing joins when step 4 undeferred; needs a live run after first push
- [ ] 7. Repo hardening: SHA-pinned Actions [x], Dependabot [x]; branch protection pending first push
- [x] 8. Repo polish: README, licensing notice, credit to drawio-mcp and dwarfered — 05 Aug 2026
- [ ] 9. Publish + blog post (Phase 1 done)
- [ ] 10. Icon MCP server on top of icons.json
- [ ] 11. Skill / instructions layer
- [ ] 12. Blog post 2 + GitHub MCP Registry listing + MVP activity entries

## 7. Known challenges and decisions log

| Challenge | Decision |
|---|---|
| Icon source | Azure: reference draw.io's builtin azure2 assets by path. Gaps: official Microsoft SVG packs only. No third-party sites or scraping |
| Licensing | Icons are Microsoft property, permitted for diagram use; Azure entries redistribute nothing (path strings only); clear README notice for embedded entries |
| Copilot integration path | MCP only; Extensions are dead as of Nov 2025 |
| Duplicating jgraph's work | Explicitly out of scope; compose with drawio-mcp instead |
| Duplicating community libraries | Human library space is crowded (dwarfered, pacodelacruz, yaegashi); cut as standalone deliverable, link to dwarfered for human users |
| Web app token costs (£0.05-£0.15/generation, abuse risk on public endpoint) | Avoided entirely by stdio MCP model; web app deferred |
| Icon naming/aliases (portal name vs common name) | Alias field in icons.json; manual curation pass, top ~100 services first |
| Icons going stale | Monthly GitHub Action diffing jgraph/drawio and Microsoft packs |
| Multi-cloud lock-in via naming | Project name must not be Microsoft-specific; schema provider-aware from v1 |
| Desktop vs web asset freshness | Unverified; validation test step 4 checks it |
| Microsoft download URLs are unstable (versioned zips, per-estate pages) | Per-source scraper in the Action; fails loudly and opens an issue rather than shipping stale "latest"; manifest records last successful sync per source |
| Mirror redistribution risk | Permitted-use basis under Microsoft icon terms (same basis as existing community collections); per-pack notice in README |
| Poisoned/malformed upstream SVGs | Sanitisation + sanity gates + PR review before anything reaches main (D4 protection measures) |
| "Reliable source" is an ongoing promise | Accepted: light maintenance commitment; loud-failure design keeps it honest |
| Validation test results (04 Aug 2026) | Steps 2-3 PASSED: builtin style `image=img/lib/azure2/ai_machine_learning/Azure_OpenAI.svg` renders in the web editor; draw.io resolves the path to its own hosted asset (HTTP 200, valid SVG). Step 4 proxy-verified: desktop app not installed locally, but latest drawio-desktop release (v31.1.5) matches web version exactly, so bundles track web at release cadence; users on stale desktop installs may lag. Step 5 PASSED: embedded base64 style with official M365 SVG (Teams Purple / Apps.svg) renders at 48x48; embedded Azure V24 icons also validated 26 Jul 2026. Embedded style strings must use comma-form data URI (`image=data:image/svg+xml,<base64>`, no `;base64` marker, since `;` delimits draw.io styles) |
| M365 icon pack is effectively frozen | The M365 architecture icons Learn page is archived/retired (content dated Apr 2024, zip files dated Jan 2024), though the fwlink download (linkid=869455) still works. Monthly diffs against it will mostly no-op; treat it as a static source and revisit if Microsoft publishes a successor |
| M365 pack is UI glyphs, not service logos | Pack contains 1,026 files of generic UI symbols (Apps, Arrows, Attach...) in per-product colourways (Teams Purple, SharePoint Teal, Microsoft Blue, Planner Green...), plus PNG duplicates. No Teams/SharePoint product logos. Gap converter needs estate+colourway-aware naming and SVG-only filtering; product logos may need a different official source |
| Builtin titles drop the "Azure" prefix | draw.io names them "OpenAI", "Cosmos DB", "Firewalls", not "Azure OpenAI" etc. Alias keys in data/aliases/azure.json are keyed by exact builtin title; the "Azure ..." forms live in the alias values. Builtin also spells "Entra Privileged Identity Management" correctly, unlike the V24 pack filename |
| Duplicate titles inside the builtin set | 7 title pairs map to genuinely distinct assets (Workspaces/Workspaces2, Dashboard/Dashboard2, Logic Apps in three folders...). Kept as-is in icons.json; MCP search will return all matches and the style paths disambiguate |
| Sidebar tags harvested | Each builtin entry keeps draw.io's own search keywords in a `tags` field, harvested from getTagsForStencil calls; free search corpus for the MCP server on top of curated aliases |
| Canonical naming (JP, 05 Aug 2026) | `name` = official Microsoft product name ("Microsoft Sentinel", not "Sentinel"). Alias file supports rename via object form `{"name": ..., "aliases": [...]}` keyed by exact builtin title; the builtin title is kept as an alias automatically. Shorthand ("Sentinel", "AKS") and legacy names ("Azure AD" on Microsoft Entra ID) must resolve via search |
| Entra ID icon identity | The modern Entra ID logo is builtin `other/Entra_Identity.svg` (renamed "Microsoft Entra ID", aliases Azure AD/AAD/Entra); `identity/Azure_Active_Directory.svg` is the legacy AAD icon and keeps the historical name |
| MCP search must be word-boundary, not substring | Raw substring matching makes "Azure AD" match "Azure ADvisor". Phase 2 search tool: token/word-boundary matching over name + aliases + tags, exact-alias hits ranked first |

### 7a. Corrected assumptions (research findings, 03 Aug 2026)

1. **WRONG: "draw.io's built-in Azure set is Visio-style / frozen at 2019."** Verified against `Sidebar-Azure2.js` in jgraph/drawio (dev branch): 766 icons, 30+ palettes, includes Azure OpenAI, AI Foundry, Foundry Agent Service, Foundry IQ, Fabric, Copilot, Container Apps, 42 Entra entries. Actively maintained with 2025-era names. Builtin shapes are addressed by plain path style strings, no base64.
2. **WRONG: "No modern icon libraries exist for draw.io."** dwarfered/azure-architecture-icons-for-drawio ships maintained one-click Azure + M365 libraries. pacodelacruz and yaegashi repos exist but are stale (2020), which is the cautionary tale for our freshness automation.
3. **CONFIRMED gaps:** builtin library has zero Teams/SharePoint/Dynamics and token Power Platform coverage (1 Power Apps, 1 Power Automate, 3 Power BI). The machine-readable lookup layer (icons.json + MCP) does not exist anywhere.
4. **Consequence:** project pivoted from "icon availability" to "icon lookup". Original D1 (general shape libraries) cut; supplemental libraries survive only as a gap-pipeline byproduct.

## 8. Future roadmap (not v1)

- **AWS icons**: draw.io also bundles AWS shape libraries (builtin ref type likely works there too, verify coverage first). Then GCP.
- **Web app** only on evidence of demand. If built: Azure Static Web Apps free tier + Functions consumption + jsDelivr for icon data; funding via bring-your-own-key or MVP Azure credit with a capped free tier. Decision made with real usage numbers, not guesses.

## 9. Success measures

- Phase 1: icons.json covers the full builtin Azure set with curated aliases for the top ~100 services
- Mirror: manifest shows all sources synced within the last month, every month; zero unsanitised SVGs ever merged
- Phase 2: a Claude or Copilot user generates a diagram with correct modern icons using the two composed MCP servers
- Community: stars, shares, links from the drawio-mcp ecosystem and Microsoft community
- Personal: two blog posts on getpractical.co.uk, MVP activity log entries, reusable at work for design-session diagrams

## 10. Build rules for AI sessions

- **Git identity:** Never commit using Claude's identity, never add Claude as co-author, and never include "Co-Authored-By: Claude" or "Generated with Claude Code" trailers in commit messages. All commits are authored solely as JP (jpsantoscosta) using his configured git user.name and user.email. Enforced via `.claude/settings.json` (`"includeCoAuthoredBy": false`) and documented here.
- **Progress tracking:** derive the current step from the section 6 checklist; tick completed steps and update the decisions log at the end of every session.