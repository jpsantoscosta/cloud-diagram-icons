# cloud-diagram-icons-mcp

Stdio MCP server that gives LLMs the exact draw.io style string for a named cloud service (Microsoft first). Compose it with the official [draw.io MCP tooling](https://github.com/jgraph/drawio-mcp): this server answers icon lookups, draw.io MCP builds and exports the diagram, and the result is AI-generated Azure diagrams with real portal icons.

## Tools

- `search_icons(query, provider?, limit?)`: rank icons for a name, alias, acronym, or keyword ("AKS", "Sentinel", "queue"). Word-boundary matching; exact name and alias hits first.
- `get_icon(name, provider?)`: one icon by exact name or alias, with suggestions when ambiguous.
- `list_categories(provider?)`, `list_providers()`: browse the index.

Results include the `style` string to drop into an mxCell `style` attribute plus default `w`/`h`.

## Install

```json
{
  "mcpServers": {
    "cloud-diagram-icons": {
      "command": "npx",
      "args": ["-y", "cloud-diagram-icons-mcp"]
    }
  }
}
```

The server fetches the latest [icons.json](https://github.com/jpsantoscosta/cloud-diagram-icons) from GitHub at startup, so new icons arrive without reinstalling. Offline, it falls back to the snapshot bundled at publish time. Point `CLOUD_DIAGRAM_ICONS_URL` at a fork or mirror to override the source.

## Security

The index is treated as untrusted input: the server accepts a style only when its `image=` value is a relative path into draw.io's bundled assets or an inline `data:image/svg+xml` URI, and drops anything else on load (reporting the count on stderr). This prevents a tampered index from injecting external image URLs, which draw.io would request every time the diagram is opened. See [SECURITY.md](https://github.com/jpsantoscosta/cloud-diagram-icons/blob/main/SECURITY.md).

## Licensing

Icons are Microsoft's property under Microsoft's terms of use, which permit their use in architecture diagrams. Builtin entries reference draw.io's bundled assets by path and redistribute nothing.
