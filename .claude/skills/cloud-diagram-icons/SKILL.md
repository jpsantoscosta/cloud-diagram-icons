---
name: cloud-diagram-icons
description: Use when creating or editing draw.io diagrams that contain cloud services (Azure, Microsoft Entra, Power Platform, Dynamics 365, Microsoft Fabric, or any Microsoft service). Resolves every service to its correct modern portal icon through the cloud-diagram-icons MCP server before any diagram XML is written. Trigger on any request to draw, generate, or modify an architecture diagram.
---

# cloud-diagram-icons

Generate draw.io diagrams whose cloud services carry the real, current portal icons. Never guess icon styles: every service icon comes from the cloud-diagram-icons MCP server.

## Workflow

1. **List the services.** Extract every cloud service named or implied in the request (an "API backend on Azure" implies App Service or Container Apps; ask if genuinely ambiguous).

2. **Resolve each service through the MCP server** (`cloud-diagram-icons`):
   - `get_icon(name)` for exact names or well-known aliases ("AKS", "Azure AD", "ADF").
   - `search_icons(query)` when unsure; take the top hit unless its score is weak, then ask.
   - Qualify the estate when a name is ambiguous across products: "Fabric Data Factory" and "Azure Data Factory" are different services with different icons, as are Fabric and Azure SQL Database.
   - Use the returned `style` string **verbatim**. Never write `image=img/lib/azure2/...` paths by hand, never use `mxgraph.azure`/`mscae` legacy shapes, never substitute emoji or generic shapes for a service that resolved.
   - Use the returned `w`/`h` as the default size; scale proportionally if needed (aspect stays fixed).

3. **Place labels below icons.** Append `verticalLabelPosition=bottom;verticalAlign=top;` to each returned style string so the service name sits under the icon, portal style.

4. **Build the diagram** with the draw.io MCP tools when available, otherwise write the mxfile XML directly.

5. **Unresolved services:** if `search_icons` returns nothing, use a plain rounded rectangle labelled with the service name, and tell the user which services had no icon so the gap can be fed back to github.com/jpsantoscosta/cloud-diagram-icons (alias candidates).

## Layout standards

- Flow left to right for request/data paths; monitoring and supporting services below the main flow.
- Orthogonal edges (`edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;endArrow=block;`), short verb-free edge labels ("HTTPS", "SQL", "Secrets").
- Dashed edges (`dashed=1`) for telemetry/monitoring paths, solid for data paths.
- Keep node spacing generous (icon width x2 minimum between nodes); snap positions to a 10px grid.
- Never crop, flip, rotate, or recolour icons (Microsoft's icon terms and basic taste both forbid it).
- Group related resources with labelled container rectangles (subscription, VNet, resource group) behind the icons, not overlapping them.

## XML conventions

- Standard skeleton: `mxfile > diagram > mxGraphModel > root`, with the two reserved cells (`id="0"`, `id="1" parent="0"`) first.
- Stable, human-readable cell ids (`fd`, `app`, `sql`), `<mxGeometry ... as="geometry"/>` on every vertex and `relative="1"` geometry on edges.
- Save as `.drawio`; the file opens directly in app.diagrams.net and the desktop app.
