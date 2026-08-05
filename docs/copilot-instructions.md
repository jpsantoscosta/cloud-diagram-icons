# Copilot instructions: draw.io diagrams with real cloud icons

Copy this file's content into your repository's `.github/copilot-instructions.md` (or the relevant instructions file for your Copilot surface), alongside configuring the two MCP servers:

```json
{
  "mcpServers": {
    "drawio": { "command": "npx", "args": ["-y", "@drawio/mcp"] },
    "cloud-diagram-icons": { "command": "npx", "args": ["-y", "cloud-diagram-icons-mcp"] }
  }
}
```

---

## Diagram generation rules

When creating or editing draw.io diagrams that contain cloud services:

1. Resolve every cloud service to its icon through the `cloud-diagram-icons` MCP server before writing any diagram XML: `get_icon(name)` for exact names or known aliases (AKS, Azure AD, ADF), `search_icons(query)` otherwise. Use the returned `style` string verbatim and the returned `w`/`h` as the default size. Never hand-write `img/lib/azure2/...` paths, never use legacy `mxgraph.azure` or `mscae` shapes.
2. Qualify the estate when a name is ambiguous across products: "Fabric Data Factory" and "Azure Data Factory" are different services with different icons, as are Fabric and Azure SQL Database.
3. Append `verticalLabelPosition=bottom;verticalAlign=top;` to each style string so labels sit below icons.
4. If a service returns no icon, use a plain rounded rectangle with the service name and tell the user which services were unresolved.
5. Layout: main flow left to right; monitoring below; orthogonal edges with short labels; dashed edges for telemetry; generous spacing; never crop, flip, rotate, or recolour icons.
6. Build with the draw.io MCP tools when available, otherwise emit standard mxfile XML (`mxfile > diagram > mxGraphModel > root`, reserved cells `0` and `1` first, stable readable cell ids).
