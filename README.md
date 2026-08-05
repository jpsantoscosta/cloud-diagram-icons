# cloud-diagram-icons

[![GitHub stars](https://img.shields.io/github/stars/jpsantoscosta/cloud-diagram-icons?style=social)](https://github.com/jpsantoscosta/cloud-diagram-icons/stargazers)
[![npm](https://img.shields.io/npm/v/cloud-diagram-icons-mcp)](https://www.npmjs.com/package/cloud-diagram-icons-mcp)

The icon lookup layer for AI-generated draw.io diagrams. Microsoft first, multi-cloud later.

If this repository is useful to you, please give it a star. It helps other people find it.

LLMs generating draw.io XML have no way to look up the correct modern icon for a named cloud service. This repo provides [`icons.json`](icons.json), a machine-readable index that maps service names (official names, portal names, acronyms, legacy names) to exact draw.io style strings. Combined with the official [draw.io MCP tooling](https://github.com/jgraph/drawio-mcp), it lets Claude, Copilot, or any MCP-capable model render Azure diagrams with the real portal icons.

**One-sentence pitch:** official draw.io MCP + this icon index = AI-generated Azure diagrams with real portal icons.

## What's in the index

846 entries: 766 Azure and Power Platform icons referenced from draw.io's builtin `azure2` shape library, plus 80 icons for the estates draw.io does not bundle (Dynamics 365, Microsoft Fabric items, Microsoft Entra product family, current Power Platform), embedded from Microsoft's official packs. Curated official names and aliases sit on top:

```json
{
  "provider": "microsoft",
  "category": "ai_machine_learning",
  "name": "Azure OpenAI",
  "aliases": ["Azure OpenAI Service", "AOAI", "OpenAI"],
  "w": 68, "h": 68,
  "ref": "builtin",
  "style": "image;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/azure2/ai_machine_learning/Azure_OpenAI.svg;",
  "tags": "openai ..."
}
```

- `ref: "builtin"` entries reference draw.io's own bundled assets by path. Nothing is redistributed and they cost kilobytes.
- `ref: "embedded"` entries carry base64 SVG from Microsoft's official packs, for estates draw.io does not bundle. Where a pack duplicates a builtin icon, the builtin reference wins.
- Fabric item names are estate-qualified (`Fabric SQL Database`) because several are distinct products that share a name with an Azure service.
- Names follow official Microsoft product naming ("Microsoft Sentinel", "Azure Kubernetes Service"); draw.io's shorter builtin titles are kept as searchable aliases, alongside common shorthand ("AKS", "ADF") and legacy names ("Azure AD" resolves to Microsoft Entra ID).

## Using a style string

Any entry's `style` value drops straight into a draw.io `mxCell`:

```xml
<mxCell id="2" value="Azure OpenAI" style="image;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/azure2/ai_machine_learning/Azure_OpenAI.svg;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="68" height="68" as="geometry"/>
</mxCell>
```

## Icon mirror

[`icons/microsoft/`](icons/microsoft) holds a categorised, sanitised mirror of the official Microsoft packs behind the embedded entries, with [`icons/manifest.json`](icons/manifest.json) recording each pack's source URL, checksum, and sync date alongside a sha256 per file. Useful on its own for slides, wikis, and docs; hotlink individual files through a CDN such as jsDelivr.

Every mirrored SVG is stripped of scripts, event handlers, remote references, and embedded HTML before it lands, because hotlinked SVGs execute in the consuming page.

Per-estate draw.io libraries live in [`libraries/`](libraries) and load into the editor via **File > Open Library From > URL**.

## Rebuilding

```powershell
pwsh scripts/build-index.ps1      # builtin Azure entries, from jgraph/drawio
pwsh scripts/build-gap-icons.ps1  # gap estates, mirror, and per-estate libraries
```

The first parses `Sidebar-Azure2.js` from [jgraph/drawio](https://github.com/jgraph/drawio) and merges curated names and aliases from [`data/aliases/azure.json`](data/aliases/azure.json). The second downloads Microsoft's official packs from an allowlist of Microsoft domains, sanitises and gates them, and refreshes the mirror and embedded entries. Each owns its own entry type and preserves the other's, so they can run in either order. A monthly GitHub Action runs both and opens a pull request when anything upstream changes, so the index does not go stale.

## Using with AI (MCP)

The [`cloud-diagram-icons-mcp`](https://www.npmjs.com/package/cloud-diagram-icons-mcp) npm package (source in [`mcp/`](mcp/)) serves this index over MCP with `search_icons`, `get_icon`, `list_categories`, and `list_providers`. Compose it with the official draw.io MCP tooling:

```json
{
  "mcpServers": {
    "drawio": { "command": "npx", "args": ["-y", "@drawio/mcp"] },
    "cloud-diagram-icons": { "command": "npx", "args": ["-y", "cloud-diagram-icons-mcp"] }
  }
}
```

To make models resolve icons automatically instead of only when asked:

- **Claude Code:** copy [`.claude/skills/cloud-diagram-icons/`](.claude/skills/cloud-diagram-icons/) into your project's `.claude/skills/` (or `~/.claude/skills/` for all projects).
- **GitHub Copilot:** copy the rules from [`docs/copilot-instructions.md`](docs/copilot-instructions.md) into your repo's `.github/copilot-instructions.md`.

A working example produced this way: [`examples/demo.drawio`](examples/demo.drawio).

## Roadmap

- AWS and GCP, using the same provider-aware schema

## Related projects

This project deliberately does one thing: machine-readable icon lookup. For the other pieces of the picture:

- [jgraph/drawio-mcp](https://github.com/jgraph/drawio-mcp): the official draw.io MCP tooling that builds, previews, and exports the diagrams. This project is designed to compose with it, not replace it.
- [dwarfered/azure-architecture-icons-for-drawio](https://github.com/dwarfered/azure-architecture-icons-for-drawio): maintained one-click Azure and M365 shape libraries for humans working in the draw.io editor. If you want drag-and-drop icon palettes rather than AI lookup, that is the right tool.

## Licensing

The referenced icons are Microsoft's property, provided under Microsoft's terms of use, which permit their use in architecture diagrams, training materials, and documentation. This project claims no ownership of any icon. `builtin` entries redistribute nothing (they are path strings into draw.io's own assets).
