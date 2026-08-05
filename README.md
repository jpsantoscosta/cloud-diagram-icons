# cloud-diagram-icons

[![GitHub stars](https://img.shields.io/github/stars/jpsantoscosta/cloud-diagram-icons?style=social)](https://github.com/jpsantoscosta/cloud-diagram-icons/stargazers)
[![npm](https://img.shields.io/npm/v/cloud-diagram-icons-mcp)](https://www.npmjs.com/package/cloud-diagram-icons-mcp)

**Give your AI assistant the real Microsoft icons when it draws draw.io diagrams.**

Ask Claude or Copilot for an Azure architecture diagram and you usually get grey rectangles, because the model has no way to look up the correct icon for a named service. This project is the missing lookup layer: an index of 846 Microsoft icons keyed by the names people actually use, served over MCP, so the model resolves "AKS" or "Sentinel" to the exact draw.io style string before it draws anything.

It does not generate diagrams. It composes with the official [draw.io MCP tooling](https://github.com/jgraph/drawio-mcp), which does.

If this repository is useful to you, please give it a star. It helps other people find it.

---

## Quick start

Pick the path that matches what you want to do.

### 1. I want my AI assistant to draw diagrams with real icons

**Prerequisite:** [Node.js](https://nodejs.org) 18 or later. Nothing else to install; `npx` fetches the server on first run.

**Claude Code.** Run this in your project:

```bash
claude mcp add cloud-diagram-icons -- npx -y cloud-diagram-icons-mcp
```

```bash
claude mcp add drawio -- npx -y @drawio/mcp
```

Or commit a `.mcp.json` in the project root so the whole team gets both:

```json
{
  "mcpServers": {
    "drawio": { "command": "npx", "args": ["-y", "@drawio/mcp"] },
    "cloud-diagram-icons": { "command": "npx", "args": ["-y", "cloud-diagram-icons-mcp"] }
  }
}
```

**VS Code / GitHub Copilot.** Create `.vscode/mcp.json` (note the key is `servers`, not `mcpServers`):

```json
{
  "servers": {
    "drawio": { "command": "npx", "args": ["-y", "@drawio/mcp"] },
    "cloud-diagram-icons": { "command": "npx", "args": ["-y", "cloud-diagram-icons-mcp"] }
  }
}
```

**Other MCP clients** (Claude Desktop, Cursor) use the same `mcpServers` block as Claude Code, in that client's own MCP config file.

**Check it worked.** In Claude Code, run `/mcp` and confirm both servers are connected. Or just ask:

> Using the cloud-diagram-icons server, search for AKS and show me the style string.

You should get back `Azure Kubernetes Service` and a style string containing `img/lib/azure2/compute/Kubernetes_Services.svg`.

**Then draw something.** For example:

> Create a draw.io diagram of an Azure web app: Front Door routing to App Service, which uses Azure SQL Database and Key Vault, with Application Insights monitoring. Save it as architecture.drawio.

Open the result at [app.diagrams.net](https://app.diagrams.net) via **File > Open From > Device**. Every service should carry its real portal icon. See [`examples/azure-web-app.drawio`](examples/azure-web-app.drawio) for what to expect.

**Make it automatic.** By default the model resolves icons when you ask it to. To make it always do so, install the instructions layer:

- **Claude Code:** copy [`.claude/skills/cloud-diagram-icons/`](.claude/skills/cloud-diagram-icons/) into your project's `.claude/skills/`, or into `~/.claude/skills/` for every project.
- **GitHub Copilot:** copy the rules from [`docs/copilot-instructions.md`](docs/copilot-instructions.md) into your repository's `.github/copilot-instructions.md`.

### 2. I just want the icons in draw.io, no AI

Azure is already covered by draw.io itself: click **More Shapes**, enable **Networking > Azure 2**, and you get all 766 Azure icons natively.

For the estates draw.io does not bundle, these links open the editor with the library loaded:

| Estate | One-click link |
|---|---|
| Dynamics 365 | [Open](https://app.diagrams.net/?splash=0&clibs=Uhttps://raw.githubusercontent.com/jpsantoscosta/cloud-diagram-icons/main/libraries/dynamics.xml) |
| Microsoft Fabric | [Open](https://app.diagrams.net/?splash=0&clibs=Uhttps://raw.githubusercontent.com/jpsantoscosta/cloud-diagram-icons/main/libraries/fabric.xml) |
| Microsoft Entra | [Open](https://app.diagrams.net/?splash=0&clibs=Uhttps://raw.githubusercontent.com/jpsantoscosta/cloud-diagram-icons/main/libraries/entra.xml) |
| Power Platform | [Open](https://app.diagrams.net/?splash=0&clibs=Uhttps://raw.githubusercontent.com/jpsantoscosta/cloud-diagram-icons/main/libraries/power-platform.xml) |

The library appears as a new section at the top of the shape panel. To load one into an existing diagram instead, use **File > Open Library From > URL** with the raw URL, for example:

```
https://raw.githubusercontent.com/jpsantoscosta/cloud-diagram-icons/main/libraries/fabric.xml
```

Prefer ready-made Azure and M365 palettes maintained for humans? See [dwarfered/azure-architecture-icons-for-drawio](https://github.com/dwarfered/azure-architecture-icons-for-drawio).

### 3. I want the raw icons or the index for my own tool

- [`icons.json`](icons.json): the whole index, fetchable directly from `https://raw.githubusercontent.com/jpsantoscosta/cloud-diagram-icons/main/icons.json`.
- [`icons/microsoft/`](icons/microsoft): individual sanitised SVGs, hotlinkable through a CDN such as jsDelivr, for slides, wikis, and docs.

### Troubleshooting

**The model drew rectangles instead of icons.** It answered without calling the lookup server. Either name the server in your prompt ("resolve every icon through the cloud-diagram-icons server first"), or install the skill or Copilot instructions above so it happens automatically.

**The server will not connect.** Run it directly:

```bash
npx -y cloud-diagram-icons-mcp
```

It should print `cloud-diagram-icons-mcp ready: 846 icons from ...` to stderr and then wait. If that works, the problem is in your client's config file rather than the server.

**An icon is missing or wrongly named.** Please [open an issue](https://github.com/jpsantoscosta/cloud-diagram-icons/issues) with the name you searched for. Alias coverage is curated by hand and gaps are worth reporting.

---

## What's in the index

846 entries: 766 Azure and Power Platform icons referenced from draw.io's builtin `azure2` shape library, plus 80 icons for the estates draw.io does not bundle (Dynamics 365, Microsoft Fabric items, Microsoft Entra product family, current Power Platform), embedded from Microsoft's official packs.

```json
{
  "provider": "microsoft",
  "category": "ai_machine_learning",
  "name": "Azure OpenAI",
  "aliases": ["Azure OpenAI Service", "AOAI", "OpenAI"],
  "w": 68, "h": 68,
  "ref": "builtin",
  "style": "image;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/azure2/ai_machine_learning/Azure_OpenAI.svg;",
  "tags": "openai open ai"
}
```

The `style` value drops straight into a draw.io `mxCell`:

```xml
<mxCell id="2" value="Azure OpenAI" style="image;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/azure2/ai_machine_learning/Azure_OpenAI.svg;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="68" height="68" as="geometry"/>
</mxCell>
```

Notes on the schema:

- `ref: "builtin"` entries reference draw.io's own bundled assets by path. Nothing is redistributed and they cost kilobytes.
- `ref: "embedded"` entries carry base64 SVG from Microsoft's official packs. Where a pack duplicates a builtin icon, the builtin reference wins.
- Names follow official Microsoft product naming ("Microsoft Sentinel", "Azure Kubernetes Service"); draw.io's shorter titles are kept as searchable aliases, alongside shorthand ("AKS", "ADF") and legacy names ("Azure AD" resolves to Microsoft Entra ID).
- Fabric item names are estate-qualified (`Fabric SQL Database`) because several are distinct products that share a name with an Azure service.

## MCP server

[`cloud-diagram-icons-mcp`](https://www.npmjs.com/package/cloud-diagram-icons-mcp) (source in [`mcp/`](mcp/)) exposes four tools: `search_icons(query, provider?, limit?)`, `get_icon(name, provider?)`, `list_categories(provider?)`, and `list_providers()`. It fetches the index from this repository at startup, so new icons arrive without reinstalling, and falls back to a bundled snapshot when offline.

## Icon mirror

[`icons/microsoft/`](icons/microsoft) holds a categorised, sanitised mirror of the four official Microsoft packs behind the embedded entries: 88 SVGs, slightly more than the 80 indexed, because the mirror keeps every icon a pack ships even where the index prefers a builtin reference. [`icons/manifest.json`](icons/manifest.json) records each pack's source URL, checksum, and last content change, alongside a sha256 per file.

Every mirrored SVG is stripped of scripts, event handlers, remote references, and embedded HTML before it lands, because hotlinked SVGs execute in the consuming page. See [SECURITY.md](SECURITY.md).

## Maintaining

```powershell
pwsh scripts/build-index.ps1      # builtin entries, from jgraph/drawio
pwsh scripts/build-gap-icons.ps1  # gap estates, mirror, and per-estate libraries
```

The first parses `Sidebar-Azure2.js` from [jgraph/drawio](https://github.com/jgraph/drawio) and merges curated names and aliases from [`data/aliases/azure.json`](data/aliases/azure.json). The second downloads Microsoft's official packs from an allowlist of Microsoft domains, sanitises and gates them, and refreshes the mirror and embedded entries. Each owns its own entry type and preserves the other's, so they run in either order.

A monthly GitHub Action runs both and opens a pull request only when something upstream actually changed, so the index does not go stale and quiet months stay quiet.

## Roadmap

- AWS and GCP, using the same provider-aware schema

## Related projects

This project deliberately does one thing: machine-readable icon lookup.

- [jgraph/drawio-mcp](https://github.com/jgraph/drawio-mcp): the official draw.io MCP tooling that builds, previews, and exports diagrams. This project composes with it rather than replacing it.
- [dwarfered/azure-architecture-icons-for-drawio](https://github.com/dwarfered/azure-architecture-icons-for-drawio): maintained one-click Azure and M365 shape libraries for humans working in the editor.

## Licensing

The referenced icons are Microsoft's property, provided under Microsoft's terms of use, which permit their use in architecture diagrams, training materials, and documentation. This project claims no ownership of any icon. `builtin` entries redistribute nothing, being path strings into draw.io's own assets.
