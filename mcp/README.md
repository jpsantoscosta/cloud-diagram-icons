# cloud-diagram-icons-mcp

**Give your AI assistant the real Microsoft icons when it draws draw.io diagrams.**

Ask a model for an Azure architecture diagram and you usually get grey rectangles, because it has no way to look up the correct icon for a named service. This MCP server is the missing lookup layer: 794 Microsoft icons keyed by the names people actually use, so the model resolves "AKS" or "Sentinel" to the exact draw.io style string before it draws anything.

Covers Azure, Power Platform, Dynamics 365, Microsoft Fabric, and Microsoft Entra.

It answers lookups only. Compose it with the official [draw.io MCP tooling](https://github.com/jgraph/drawio-mcp), which builds and exports the diagram.

## Setup

Requires [Node.js](https://nodejs.org) 18 or later. `npx` fetches the server on first run, so there is nothing to install.

**Claude Code:**

```bash
claude mcp add cloud-diagram-icons -- npx -y cloud-diagram-icons-mcp
```

```bash
claude mcp add drawio -- npx -y @drawio/mcp
```

**Claude Desktop, Cursor, and other clients** using an `mcpServers` config:

```json
{
  "mcpServers": {
    "drawio": { "command": "npx", "args": ["-y", "@drawio/mcp"] },
    "cloud-diagram-icons": { "command": "npx", "args": ["-y", "cloud-diagram-icons-mcp"] }
  }
}
```

**VS Code / GitHub Copilot**, in `.vscode/mcp.json` (the key is `servers`):

```json
{
  "servers": {
    "drawio": { "command": "npx", "args": ["-y", "@drawio/mcp"] },
    "cloud-diagram-icons": { "command": "npx", "args": ["-y", "cloud-diagram-icons-mcp"] }
  }
}
```

## Using it

Ask for a diagram in plain language:

> Create a draw.io diagram of an Azure web app: Front Door routing to App Service, which uses Azure SQL Database and Key Vault, with Application Insights monitoring. Save it as architecture.drawio.

To have the model resolve icons every time rather than only when asked, install the [Claude skill or Copilot instructions](https://github.com/jpsantoscosta/cloud-diagram-icons#quick-start) from the repository.

## Tools

- `search_icons(query, provider?, limit?)`: rank icons for a name, alias, acronym, or keyword ("AKS", "Sentinel", "queue"). Word-boundary matching; exact name and alias hits rank first.
- `get_icon(name, provider?)`: one icon by exact name or alias, with suggestions when the name is ambiguous.
- `list_categories(provider?)` and `list_providers()`: browse the index.

Results carry the `style` string to drop into an mxCell `style` attribute, plus default `w` and `h`.

## Notes

The server fetches the latest index from GitHub at startup, so new icons arrive without reinstalling, and falls back to the snapshot bundled at publish time when offline. Set `CLOUD_DIAGRAM_ICONS_URL` to point at a fork or mirror.

Not connecting? Run `npx -y cloud-diagram-icons-mcp` directly. It prints `ready: 794 icons from ...` to stderr and waits; if that works, the problem is in your client's config rather than the server.

## Security

The index is treated as untrusted input: a style is accepted only when its `image=` value is a relative path into draw.io's bundled assets or an inline `data:image/svg+xml` URI, and anything else is dropped on load. This prevents a tampered index from injecting external image URLs, which draw.io would request every time the diagram is opened. See [SECURITY.md](https://github.com/jpsantoscosta/cloud-diagram-icons/blob/main/SECURITY.md).

## Licensing

Icons are Microsoft's property under Microsoft's terms of use, which permit their use in architecture diagrams, training materials, and documentation. Builtin entries reference draw.io's bundled assets by path and redistribute nothing.
