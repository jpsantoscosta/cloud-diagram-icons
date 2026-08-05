#Requires -Version 7
<#
.SYNOPSIS
Generates the builtin (ref: "builtin") Azure entries of icons.json by parsing
Sidebar-Azure2.js from jgraph/drawio.

.DESCRIPTION
draw.io's builtin azure2 library is current and complete for Azure (766 shapes,
verified 03 Aug 2026). Builtin entries carry a path-only style string into
draw.io's bundled assets, so nothing is redistributed and the index stays tiny.

Each sidebar entry provides: style path, default width/height (r=400
multipliers), display title, and draw.io's own search keywords (kept as "tags"
for the MCP server's search). Curated aliases from data/aliases/azure.json are
merged on top, keyed by exact title.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$SidebarUrl = 'https://raw.githubusercontent.com/jgraph/drawio/dev/src/main/webapp/js/diagramly/sidebar/Sidebar-Azure2.js',
    [string]$OutFile = 'icons.json'
)

$ErrorActionPreference = 'Stop'
$r = 400  # matches `var r = 400` in the sidebar source
$StyleBase = 'image;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/azure2/'

function Resolve-Dim([string]$Expr) {
    $e = $Expr.Trim()
    if ($e -match '^r\s*\*\s*([\d.]+)$') { return [math]::Round($r * [double]$Matches[1], 2) }
    if ($e -match '^[\d.]+$') { return [double]$e }
    throw "Cannot evaluate dimension expression '$Expr'"
}

$js = (Invoke-WebRequest -Uri $SidebarUrl -TimeoutSec 60).Content
Write-Host "Fetched Sidebar-Azure2.js ($([math]::Round($js.Length/1KB)) KB)"

# Map each palette function to its category folder, from the master palette:
#   this.setCurrentSearchEntryLibrary('azure2', 'azure2AI Machine Learning');
#   this.addAzure2AIMachineLearningPalette(gn, r, sb, s + 'ai_machine_learning/');
$fnCategory = @{}
$fnDisplay = @{}
$masterRx = [regex]"setCurrentSearchEntryLibrary\('azure2',\s*'azure2([^']+)'\);\s*this\.(addAzure2\w+Palette)\(gn,\s*r,\s*sb,\s*s\s*\+\s*'([^']+)/'\)"
foreach ($m in $masterRx.Matches($js)) {
    $fnCategory[$m.Groups[2].Value] = $m.Groups[3].Value
    $fnDisplay[$m.Groups[2].Value] = $m.Groups[1].Value
}
Write-Host "Palette functions mapped: $($fnCategory.Count)"

# Curated aliases, keyed by exact builtin icon title. Two value forms:
#   "Builtin Title": ["alias", ...]                       aliases only
#   "Builtin Title": { "name": "Official Product Name",   rename + aliases;
#                      "aliases": ["alias", ...] }        builtin title is kept
#                                                         as an alias automatically
$aliasPath = Join-Path $RepoRoot 'data/aliases/azure.json'
$aliasMap = @{}
if (Test-Path $aliasPath) {
    foreach ($p in (Get-Content $aliasPath -Raw | ConvertFrom-Json).PSObject.Properties) {
        if ($p.Value -is [System.Management.Automation.PSCustomObject]) {
            $aliasMap[$p.Name] = @{ name = $p.Value.name; aliases = @($p.Value.aliases) }
        }
        else {
            $aliasMap[$p.Name] = @{ name = $null; aliases = @($p.Value) }
        }
    }
}

# Split the file into palette function bodies.
$fnRx = [regex]'Sidebar\.prototype\.(addAzure2\w+Palette)\s*=\s*function'
$sections = $fnRx.Matches($js)
$q = "(?:[^'\\]|\\.)*"  # single-quoted JS string content, allowing escapes
$entryRx = [regex]("this\.createVertexTemplateEntry\(\s*(s\s*\+\s*)?'($q)'\s*,\s*([^,]+),\s*([^,]+),\s*'$q'\s*,\s*'($q)'\s*,[\s\S]*?getTagsForStencil\(gn,\s*'($q)'")

$icons = [System.Collections.Generic.List[object]]::new()
$aliasHits = [System.Collections.Generic.HashSet[string]]::new()

for ($i = 0; $i -lt $sections.Count; $i++) {
    $fnName = $sections[$i].Groups[1].Value
    if ($fnName -eq 'addAzure2Palette') { continue }
    if (-not $fnCategory.ContainsKey($fnName)) { Write-Warning "No category mapping for $fnName"; continue }
    $start = $sections[$i].Index
    $end = if ($i + 1 -lt $sections.Count) { $sections[$i + 1].Index } else { $js.Length }
    $body = $js.Substring($start, $end - $start)
    $category = $fnCategory[$fnName]

    foreach ($m in $entryRx.Matches($body)) {
        $usesPrefix = $m.Groups[1].Value -ne ''
        $styleArg = $m.Groups[2].Value -replace "\\'", "'"
        $style = if ($usesPrefix) { "$StyleBase$category/$styleArg" } else { $styleArg }
        $title = ($m.Groups[5].Value -replace "\\'", "'")
        $name = $title
        $aliases = @()
        if ($aliasMap.ContainsKey($title)) {
            [void]$aliasHits.Add($title)
            $entry = $aliasMap[$title]
            $aliases = @($entry.aliases)
            if ($entry.name -and $entry.name -ne $title) {
                $name = $entry.name
                if ($aliases -notcontains $title) { $aliases += $title }
            }
        }
        $icons.Add([ordered]@{
            provider = 'microsoft'
            category = $category
            name     = $name
            aliases  = $aliases
            w        = Resolve-Dim $m.Groups[3].Value
            h        = Resolve-Dim $m.Groups[4].Value
            ref      = 'builtin'
            style    = $style
            tags     = ($m.Groups[6].Value -replace "\\'", "'")
        })
    }
}

Write-Host "Parsed $($icons.Count) builtin entries across $($fnCategory.Count) categories"
$unmatched = $aliasMap.Keys | Where-Object { -not $aliasHits.Contains($_) }
if ($unmatched) { Write-Warning "Alias keys with no matching builtin title: $($unmatched -join ', ')" }

$dupes = $icons | Group-Object { "$($_.category)/$($_.name)" } | Where-Object Count -gt 1
if ($dupes) { Write-Warning "Duplicate category/name pairs: $(($dupes.Name | Select-Object -First 10) -join '; ')" }

$index = [ordered]@{
    generated = (Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ')
    notice    = 'Azure entries reference draw.io''s bundled azure2 assets by path and redistribute nothing. Icons are Microsoft property, permitted for use in architecture diagrams under Microsoft''s terms of use.'
    count     = $icons.Count
    icons     = $icons
}
$indexPath = Join-Path $RepoRoot $OutFile
Set-Content -Path $indexPath -Value (ConvertTo-Json -InputObject $index -Depth 5 -Compress) -Encoding UTF8 -NoNewline
Write-Host "wrote $indexPath ($([math]::Round((Get-Item $indexPath).Length/1KB)) KB, $($icons.Count) icons)"
