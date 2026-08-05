# Security Policy

## Reporting a vulnerability

Report vulnerabilities privately through GitHub's [private vulnerability reporting](https://github.com/jpsantoscosta/cloud-diagram-icons/security/advisories/new) on this repository. Please do not open a public issue for a security problem.

## Threat model

The icon index (`icons.json`) is fetched over the network by the MCP server, and the `style` strings it contains are pasted verbatim into users' diagrams. draw.io requests whatever host appears in a style's `image=` value when a diagram is opened, so an untrusted style string would act as a tracking beacon, firing for every viewer of the diagram, and could point at attacker-controlled content.

The index is therefore treated as untrusted input at every boundary:

- **Generation.** `scripts/build-index.ps1` parses the upstream sidebar source from jgraph/drawio. It never executes upstream code, and every parsed style must reference a relative `img/lib/...svg` path inside draw.io's own bundled assets. Anything else aborts the build with no output written, so a compromised upstream cannot reach the published index.
- **Consumption.** The MCP server re-validates on load and drops any entry whose style is not a bundled asset path or an inline `data:image/svg+xml` URI, reporting the number dropped on stderr. Transport failures fall back to the bundled snapshot; a hostile index never falls back silently, because that would mask tampering.
- **Overrides.** `CLOUD_DIAGRAM_ICONS_URL` lets users point the server at a fork or mirror. The same validation applies to any source.

## Supply chain

- GitHub Actions are pinned by commit SHA; Dependabot keeps them current.
- The refresh workflow never pushes to `main`. It opens a pull request for review, and opens an issue when a run fails.
- `main` requires pull requests, forbids force-pushes, and enforces linear history.
- Secret scanning with push protection, Dependabot alerts, and Dependabot security updates are enabled.

## Icons

Icons referenced by `ref: "builtin"` entries are not redistributed by this project; the style strings are path references into draw.io's own bundled assets. Icons remain Microsoft's property under Microsoft's terms of use.
