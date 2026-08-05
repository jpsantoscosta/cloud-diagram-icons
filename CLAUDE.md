Read PROJECT-SCOPE.md before any work. It defines scope, out-of-scope items, build order, and the decisions log. Derive the current step from the section 6 checklist (first unchecked step), never from memory or session history. Tick completed steps and update the decisions log as part of every change.

Architecture (rev 2): Azure icons are referenced by builtin azure2 path style strings (no base64); embedded base64 is reserved for the estates draw.io does not bundle (Dynamics 365, Fabric, Entra product family, current Power Platform). Two generators share icons.json and each preserves the other's entries: `scripts/build-index.ps1` owns `ref: builtin` (parsed from Sidebar-Azure2.js in jgraph/drawio), `scripts/build-gap-icons.ps1` owns `ref: embedded` plus the icons/microsoft mirror, icons/manifest.json, and libraries/. Curated names and aliases live in data/aliases/azure.json, keyed by exact builtin title (builtin drops the "Azure" prefix: "OpenAI", "Cosmos DB", "Firewalls"). The MCP server lives in mcp/ and is published as cloud-diagram-icons-mcp.

Icon style strings are a security boundary: validate at both generation and load. See SECURITY.md before changing anything that produces or consumes a `style` value.

Build conventions: PROJECT-SCOPE.md section 10 applies to every commit (maintainer git identity only, no AI co-author trailers).
