# cloud-diagram-icons

The icon lookup layer for AI-generated draw.io diagrams. Microsoft first, multi-cloud later.

LLMs generating draw.io XML have no way to look up the correct modern icon for a named cloud service. This repo provides [`icons.json`](icons.json), a machine-readable index that maps service names (official names, portal names, acronyms, legacy names) to exact draw.io style strings. Combined with the official [draw.io MCP tooling](https://github.com/jgraph/drawio-mcp), it lets Claude, Copilot, or any MCP-capable model render Azure diagrams with the real portal icons.

**One-sentence pitch:** official draw.io MCP + this icon index = AI-generated Azure diagrams with real portal icons.

## What's in the index

766 Azure and Power Platform entries generated from draw.io's builtin `azure2` shape library, with curated official names and aliases on top:

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

- `ref: "builtin"` entries reference draw.io's own bundled assets by path. Nothing is redistributed and the whole index stays around 200 KB.
- `ref: "embedded"` entries (planned, for estates draw.io lacks: M365, Dynamics 365, Microsoft Fabric) will carry base64 SVG from Microsoft's official icon packs.
- Names follow official Microsoft product naming ("Microsoft Sentinel", "Azure Kubernetes Service"); draw.io's shorter builtin titles are kept as searchable aliases, alongside common shorthand ("AKS", "ADF") and legacy names ("Azure AD" resolves to Microsoft Entra ID).

## Using a style string

Any entry's `style` value drops straight into a draw.io `mxCell`:

```xml
<mxCell id="2" value="Azure OpenAI" style="image;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/azure2/ai_machine_learning/Azure_OpenAI.svg;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="68" height="68" as="geometry"/>
</mxCell>
```

## Rebuilding the index

```powershell
pwsh scripts/build-index.ps1
```

The script parses `Sidebar-Azure2.js` from [jgraph/drawio](https://github.com/jgraph/drawio) and merges curated names and aliases from [`data/aliases/azure.json`](data/aliases/azure.json). A monthly GitHub Action re-runs it and opens a PR when draw.io ships new icons, so the index does not go stale.

## Roadmap

- MCP server (`cloud-diagram-icons-mcp`): `search_icons`, `get_icon`, `list_categories`, `list_providers` over this index
- Gap estates with embedded icons: M365, Dynamics 365, Microsoft Fabric, full Power Platform
- Claude skill and Copilot instructions layer
- AWS and GCP, using the same provider-aware schema

## Licensing and credits

The referenced icons are Microsoft's property, provided under Microsoft's terms of use, which permit their use in architecture diagrams, training materials, and documentation. This project claims no ownership of any icon. `builtin` entries redistribute nothing (they are path strings into draw.io's own assets).

Built to compose with the official [draw.io MCP project](https://github.com/jgraph/drawio-mcp) by JGraph. If you want ready-made human shape libraries for draw.io, see [dwarfered/azure-architecture-icons-for-drawio](https://github.com/dwarfered/azure-architecture-icons-for-drawio).
