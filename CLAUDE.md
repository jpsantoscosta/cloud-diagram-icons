Read PROJECT-SCOPE.md before any work. It defines scope, out-of-scope items, build order, and the decisions log. Derive the current step from the section 6 checklist (first unchecked step), never from memory or session history. Tick completed steps and update the decisions log as part of every change.

Architecture (rev 2): Azure icons are referenced by builtin azure2 path style strings (no base64); embedded base64 is reserved for gap estates (M365, Dynamics, full Power Platform). `pwsh scripts/build-index.ps1` regenerates icons.json from Sidebar-Azure2.js in jgraph/drawio. Curated names and aliases live in data/aliases/azure.json, keyed by exact builtin title (builtin drops the "Azure" prefix: "OpenAI", "Cosmos DB", "Firewalls"). The MCP server lives in mcp/ and is published as cloud-diagram-icons-mcp.

Build conventions: PROJECT-SCOPE.md section 10 applies to every commit (maintainer git identity only, no AI co-author trailers).
