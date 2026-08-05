# Security Policy

## Reporting a vulnerability

Report vulnerabilities privately through GitHub's [private vulnerability reporting](https://github.com/jpsantoscosta/cloud-diagram-icons/security/advisories/new) on this repository. Please do not open a public issue for a security problem.

## Threat model

The icon index (`icons.json`) is fetched over the network by the MCP server, and the `style` strings it contains are pasted verbatim into users' diagrams. draw.io requests whatever host appears in a style's `image=` value when a diagram is opened, so an untrusted style string would act as a tracking beacon, firing for every viewer of the diagram, and could point at attacker-controlled content.

The index is therefore treated as untrusted input at every boundary:

- **Generation.** `scripts/build-index.ps1` parses the upstream sidebar source from jgraph/drawio. It never executes upstream code, and every parsed style must reference a relative `img/lib/...svg` path inside draw.io's own bundled assets. Anything else aborts the build with no output written, so a compromised upstream cannot reach the published index.
- **Consumption.** The MCP server re-validates on load and drops any entry whose style is not a bundled asset path or an inline `data:image/svg+xml` URI, reporting the number dropped on stderr. Transport failures fall back to the bundled snapshot; a hostile index never falls back silently, because that would mask tampering.
- **Overrides.** `CLOUD_DIAGRAM_ICONS_URL` lets users point the server at a fork or mirror. The same validation applies to any source.

## Icon mirror pipeline

`scripts/build-gap-icons.ps1` pulls icon packs from Microsoft and commits them to this repository, where they can be hotlinked. An SVG loaded as a document executes whatever it contains, so the pipeline treats every pack as untrusted:

- **Allowlisted origins.** Downloads are restricted to HTTPS Microsoft download and Learn domains, plus the `microsoft` GitHub organisation. Any other URL aborts the run.
- **Sanitisation.** Every SVG is stripped of `<script>`, inline event handlers, `<foreignObject>`, DOCTYPE declarations, and any `href`/`xlink:href` that leaves the document, then re-parsed to confirm it is still a valid SVG. The result is re-checked for the same patterns, so a failed strip fails the run rather than shipping.
- **Sanity gates.** Per file: parses as SVG, under 500 KB. Per estate: the icon count may not move more than 20% against the last sync, so a restructured or truncated pack cannot quietly gut the mirror.
- **Staged writes.** Nothing reaches disk until every source has passed every gate, so a failure cannot leave a half-updated mirror.
- **Integrity.** `icons/manifest.json` records each pack's source URL and sha256 plus a sha256 per mirrored file, so any silent upstream content change is visible in the diff.

## Supply chain

- GitHub Actions are pinned by commit SHA; Dependabot keeps both the Actions and the MCP package's dependencies current.
- The refresh workflow never pushes to `main`. It opens a pull request for review, and opens an issue when a run fails.
- `main` requires pull requests, forbids force-pushes, and enforces linear history.
- Secret scanning with push protection, Dependabot alerts, and Dependabot security updates are enabled.

## Dependencies and scanner findings

The npm package has two direct dependencies, `@modelcontextprotocol/sdk` and `zod`, and no known vulnerabilities.

Supply-chain scanners such as Socket report *capability* alerts against the dependency tree: use of `eval`, shell access, and network access. These describe what a package is able to do, not a defect, and every one of them comes from the official MCP SDK rather than from this project's code:

| Alert | Origin | Why it is there |
|---|---|---|
| Uses eval | `ajv` | The JSON Schema validator compiles schemas into functions with `new Function`. This is how ajv has always worked. |
| Shell access | `cross-spawn` | The SDK's stdio **client** transport spawns child server processes. This server is the process being spawned, so it never takes that path. |
| Network access | `express`, `hono`, `cors`, `eventsource` | The SDK's HTTP and SSE server transports. |

This server uses the stdio transport only: it imports `McpServer` and `StdioServerTransport` and nothing else from the SDK, so the HTTP stack is installed but never loaded. npm cannot install part of a package, so those dependencies arrive regardless of which transport is used.

This project's own code contains no `eval`, no `new Function`, and no child process execution. Note that `src/icons.js` contains `.exec(`, which is the regular-expression method rather than process execution; it is easy to misread when auditing.

The server makes exactly one network request of its own: an HTTPS GET for `icons.json`, to the URL in `CLOUD_DIAGRAM_ICONS_URL` or the project's GitHub raw URL by default. The response is validated as described above before any part of it is served.

A "Socket optimized override available" notice is not a finding; it is a vendor offer to substitute their own builds of your dependencies.

## Icons

Icons referenced by `ref: "builtin"` entries are not redistributed by this project; the style strings are path references into draw.io's own bundled assets. Icons remain Microsoft's property under Microsoft's terms of use.
