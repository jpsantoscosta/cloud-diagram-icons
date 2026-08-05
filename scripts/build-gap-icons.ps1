#Requires -Version 7
<#
.SYNOPSIS
Mirrors official Microsoft icon packs and generates embedded icon entries for
the estates draw.io does not bundle.

.DESCRIPTION
Covers the estates the builtin azure2 library lacks (Dynamics 365, Microsoft
Fabric, Entra product-family branding, current Power Platform). For each
source it:

  1. downloads the pack from an allowlisted Microsoft domain
  2. sanitises every SVG (no script, event handlers, remote references, or
     embedded HTML: mirrored SVGs are hotlinkable and must never be a vector)
  3. applies sanity gates (parses as SVG, size ceiling, count drift ceiling)
  4. writes the mirror tree under icons/microsoft/<estate>/<category>/
     with manifest.json recording source, version, sha256 and sync date
  5. emits `ref: "embedded"` entries into icons.json (base64 SVG in the style
     string) and a supplemental draw.io library per estate

Entries already covered by a builtin azure2 icon are skipped, so the index
prefers the reference that redistributes nothing.

Nothing is written unless every gate passes for every source.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$WorkDir = (Join-Path ([IO.Path]::GetTempPath()) 'cloud-diagram-icons-gap'),
    [switch]$SkipDownload
)

$ErrorActionPreference = 'Stop'

$IconSize = 48
$MaxSvgBytes = 500KB
$MaxCountDrift = 0.20

# Downloads are restricted to Microsoft-controlled origins. Anything else
# aborts the run rather than silently pulling from an unexpected host.
$AllowedHosts = @('download.microsoft.com', 'go.microsoft.com', 'learn.microsoft.com', 'arch-center.azureedge.net')
$AllowedGitHubRawPrefix = 'https://raw.githubusercontent.com/microsoft/'

# Each source declares how to pick icons out of its pack and how to turn a
# file path into a display name and category. Packs differ wildly in layout,
# so this stays data rather than becoming a generic guess.
$Sources = @(
    [pscustomobject]@{
        Estate    = 'dynamics'
        Label     = 'Dynamics 365 icons'
        Url       = 'https://download.microsoft.com/download/498606aa-6d27-4f13-aa5c-1401078c153b/Dynamics-365-icons-scalable.zip'
        Reference = 'https://learn.microsoft.com/en-us/dynamics365/get-started/icons'
        Select    = { param($rel) $rel -like '*.svg' }
        Category  = { param($rel) if ($rel -match 'Product Family') { 'product-family' } else { 'app' } }
        Name      = {
            param($rel)
            $base = [IO.Path]::GetFileNameWithoutExtension($rel) -replace '_scalable$', ''
            $words = [regex]::Replace($base, '(?<!^)(?=[A-Z])', ' ')
            if ($words -match '^Dynamics\s*365$') { 'Dynamics 365' } else { "Dynamics 365 $words" }
        }
    },
    [pscustomobject]@{
        Estate    = 'power-platform'
        Label     = 'Microsoft Power Platform icons'
        Url       = 'https://download.microsoft.com/download/498606aa-6d27-4f13-aa5c-1401078c153b/Power-Platform-icons-scalable.zip'
        Reference = 'https://learn.microsoft.com/en-us/power-platform/guidance/icons'
        Select    = { param($rel) $rel -like '*.svg' }
        Category  = { param($rel) 'product' }
        Name      = {
            param($rel)
            $base = [IO.Path]::GetFileNameWithoutExtension($rel) -replace '_scalable$', ''
            switch ($base) {
                'AIBuilder' { 'AI Builder'; break }
                'Agent365' { 'Microsoft Agent 365'; break }
                'CopilotStudio' { 'Microsoft Copilot Studio'; break }
                'Dataverse' { 'Microsoft Dataverse'; break }
                'PowerPlatform' { 'Microsoft Power Platform'; break }
                default { [regex]::Replace($base, '(?<!^)(?=[A-Z])', ' ') }
            }
        }
    },
    [pscustomobject]@{
        Estate    = 'entra'
        Label     = 'Microsoft Entra architecture icons'
        Url       = 'https://download.microsoft.com/download/3/1/a/31a56038-856a-4489-88e4-ee5a1c4352be/Microsoft%20Entra%20architecture%20icons%20-%20Oct%202023.zip'
        Reference = 'https://learn.microsoft.com/en-us/entra/architecture/architecture-icons'
        # Colour icons only; the pack also ships black-and-white variants of
        # the same products, which would duplicate every entry.
        Select    = { param($rel) $rel -like '*.svg' -and $rel -match 'color icons' }
        Category  = { param($rel) 'product' }
        Name      = {
            param($rel)
            $base = [IO.Path]::GetFileNameWithoutExtension($rel)
            ($base -replace '\s+color icon$', '' -replace '\s+BW icon$', '').Trim()
        }
    },
    [pscustomobject]@{
        Estate    = 'fabric'
        Label     = 'Microsoft Fabric icons'
        Url       = 'https://raw.githubusercontent.com/microsoft/fabric-samples/main/docs-samples/Icons.zip'
        Reference = 'https://learn.microsoft.com/en-us/fabric/fundamentals/icons'
        # The pack is the @fabric-msft/svg-icons npm package: item icons are
        # the Fabric item types worth diagramming, at six sizes each. The
        # filled/regular variants are generic Fluent glyphs, not products.
        Select    = { param($rel) $rel -match '_48_item\.svg$' }
        Category  = { param($rel) 'item' }
        # Item names are qualified with the estate. Several Fabric items share
        # a name with an unrelated Azure service ("Data Factory", "SQL
        # Database", "Dashboard") while having their own distinct icon, so
        # bare names would both collide in search and be discarded as
        # duplicates of the Azure entry. The bare words stay in `tags`, so an
        # unqualified query still finds the item, ranked below the Azure
        # service it is not.
        Name      = {
            param($rel)
            $base = [IO.Path]::GetFileNameWithoutExtension($rel) -replace '_48_item$', ''
            $words = ($base -split '_' | Where-Object { $_ } | ForEach-Object {
                if ($_ -match '^(bi|ai|sql|kql|api)$') { $_.ToUpperInvariant() }
                else { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }
            })
            $joined = ($words -join ' ')
            if ($joined -match '^Fabric\b') { $joined } else { "Fabric $joined" }
        }
    }
)

function Assert-AllowedSource([string]$Url) {
    $uri = [Uri]$Url
    if ($uri.Scheme -ne 'https') { throw "Refusing non-HTTPS source: $Url" }
    if ($AllowedHosts -contains $uri.Host) { return }
    if ($Url.StartsWith($AllowedGitHubRawPrefix, [StringComparison]::Ordinal)) { return }
    throw "Refusing source outside the Microsoft allowlist: $Url"
}

<#
Mirrored SVGs are meant to be hotlinked, and an SVG loaded as a document runs
whatever it contains. Strip anything executable or externally referencing
before it can reach the repository.
#>
function Get-SanitisedSvg([string]$Xml, [string]$Origin) {
    $clean = $Xml
    $clean = [regex]::Replace($clean, '<!DOCTYPE[^>]*(\[[\s\S]*?\])?[^>]*>', '', 'IgnoreCase')
    $clean = [regex]::Replace($clean, '<script[\s\S]*?</script\s*>', '', 'IgnoreCase')
    $clean = [regex]::Replace($clean, '<script[^>]*/>', '', 'IgnoreCase')
    $clean = [regex]::Replace($clean, '<foreignObject[\s\S]*?</foreignObject\s*>', '', 'IgnoreCase')
    # Inline event handlers: on<name>="..." or '...'
    $clean = [regex]::Replace($clean, '\son[a-zA-Z]+\s*=\s*"[^"]*"', '', 'IgnoreCase')
    $clean = [regex]::Replace($clean, "\son[a-zA-Z]+\s*=\s*'[^']*'", '', 'IgnoreCase')
    # References out to another origin, including javascript: and data: URIs.
    $clean = [regex]::Replace($clean, '\s(?:xlink:)?href\s*=\s*"(?!#)[^"]*"', '', 'IgnoreCase')
    $clean = [regex]::Replace($clean, "\s(?:xlink:)?href\s*=\s*'(?!#)[^']*'", '', 'IgnoreCase')

    try { $doc = [xml]$clean } catch { throw "Sanitised SVG no longer parses ($Origin): $($_.Exception.Message)" }
    if ($doc.DocumentElement.LocalName -ne 'svg') { throw "Not an SVG document ($Origin): root is <$($doc.DocumentElement.LocalName)>" }
    foreach ($pattern in @('<script', 'javascript:', '<foreignObject')) {
        if ($clean -match [regex]::Escape($pattern)) { throw "Sanitisation failed to remove '$pattern' ($Origin)" }
    }
    return $clean
}

function Get-SvgSize([xml]$Doc) {
    $root = $Doc.DocumentElement
    foreach ($attr in @('width', 'height')) {
        $null = $attr  # sizes are read below; attribute presence varies by pack
    }
    $w = $root.GetAttribute('width'); $h = $root.GetAttribute('height')
    if ($w -match '^([\d.]+)' -and $h -match '^([\d.]+)') {
        $wv = [double]([regex]::Match($w, '^([\d.]+)').Groups[1].Value)
        $hv = [double]([regex]::Match($h, '^([\d.]+)').Groups[1].Value)
        if ($wv -gt 0 -and $hv -gt 0) {
            # Normalise to the project's default icon size, preserving aspect.
            $scale = $IconSize / [math]::Max($wv, $hv)
            return @([math]::Round($wv * $scale, 2), [math]::Round($hv * $scale, 2))
        }
    }
    return @($IconSize, $IconSize)
}

function ConvertTo-KebabCase([string]$Value) {
    $s = $Value -replace '[^A-Za-z0-9]+', '-'
    return ($s -replace '-+', '-').Trim('-').ToLowerInvariant()
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$mirrorRoot = Join-Path $RepoRoot 'icons/microsoft'
$manifestPath = Join-Path $RepoRoot 'icons/manifest.json'

$previousManifest = @{}
if (Test-Path $manifestPath) {
    $prev = Get-Content $manifestPath -Raw | ConvertFrom-Json
    foreach ($e in $prev.estates.PSObject.Properties) { $previousManifest[$e.Name] = $e.Value }
}

# Everything is staged in memory and only committed to disk once every source
# has passed its gates, so a bad sync cannot leave a half-updated mirror.
$staged = [System.Collections.Generic.List[object]]::new()

foreach ($source in $Sources) {
    Assert-AllowedSource $source.Url
    $zipPath = Join-Path $WorkDir "$($source.Estate).zip"
    $extractPath = Join-Path $WorkDir $source.Estate

    if (-not ($SkipDownload -and (Test-Path $zipPath))) {
        Write-Host "[$($source.Estate)] downloading $($source.Url)"
        Invoke-WebRequest -Uri $source.Url -OutFile $zipPath -TimeoutSec 300
    }
    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    $packSha = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $candidates = Get-ChildItem $extractPath -Recurse -File -Filter *.svg | Sort-Object FullName
    $selected = @($candidates | Where-Object {
        $rel = $_.FullName.Substring($extractPath.Length).TrimStart('\', '/') -replace '\\', '/'
        & $source.Select $rel
    })
    if ($selected.Count -eq 0) { throw "[$($source.Estate)] pack contained no matching SVGs; the layout has changed" }

    # Gate: a collapsed or restructured pack must not silently shrink the mirror.
    $prevCount = if ($previousManifest.ContainsKey($source.Estate)) { [int]$previousManifest[$source.Estate].count } else { 0 }
    if ($prevCount -gt 0) {
        $drift = [math]::Abs($selected.Count - $prevCount) / $prevCount
        if ($drift -gt $MaxCountDrift) {
            throw "[$($source.Estate)] icon count moved from $prevCount to $($selected.Count) ($([math]::Round($drift * 100))%), above the $([int]($MaxCountDrift * 100))% gate. Review upstream before syncing."
        }
    }

    $icons = [System.Collections.Generic.List[object]]::new()
    $seenNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $selected) {
        $rel = $file.FullName.Substring($extractPath.Length).TrimStart('\', '/') -replace '\\', '/'
        if ($file.Length -gt $MaxSvgBytes) { throw "[$($source.Estate)] $rel is $([math]::Round($file.Length/1KB))KB, above the $([int]($MaxSvgBytes/1KB))KB gate" }

        $clean = Get-SanitisedSvg ([IO.File]::ReadAllText($file.FullName)) "$($source.Estate)/$rel"
        $name = (& $source.Name $rel)
        $category = (& $source.Category $rel)
        if (-not $seenNames.Add($name)) { continue }

        $bytes = [Text.Encoding]::UTF8.GetBytes($clean)
        $size = Get-SvgSize ([xml]$clean)
        $icons.Add([pscustomobject]@{
            Name     = $name
            Category = $category
            FileName = "$(ConvertTo-KebabCase $name).svg"
            Svg      = $clean
            Sha256   = ([BitConverter]::ToString([Security.Cryptography.SHA256]::HashData($bytes)) -replace '-', '').ToLowerInvariant()
            Base64   = [Convert]::ToBase64String($bytes)
            W        = $size[0]
            H        = $size[1]
            Source   = $rel
        })
    }

    Write-Host "[$($source.Estate)] $($icons.Count) icons selected and sanitised"
    $staged.Add([pscustomobject]@{ Source = $source; Icons = $icons; PackSha = $packSha })
}

# --- All gates passed; commit to disk -------------------------------------

$indexPath = Join-Path $RepoRoot 'icons.json'
$index = Get-Content $indexPath -Raw | ConvertFrom-Json
$builtin = @($index.icons | Where-Object { $_.ref -eq 'builtin' })

# Names (and aliases) already served by a builtin reference win: those cost
# nothing to ship and redistribute nothing.
$builtinNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($icon in $builtin) {
    [void]$builtinNames.Add($icon.name)
    foreach ($alias in @($icon.aliases)) { [void]$builtinNames.Add($alias) }
}

$embedded = [System.Collections.Generic.List[object]]::new()
$manifestEstates = [ordered]@{}
$syncedAt = (Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ')

foreach ($stage in $staged) {
    $estate = $stage.Source.Estate
    $estateDir = Join-Path $mirrorRoot $estate
    if (Test-Path $estateDir) { Remove-Item $estateDir -Recurse -Force }

    $manifestFiles = [System.Collections.Generic.List[object]]::new()
    $libraryEntries = [System.Collections.Generic.List[object]]::new()
    $skipped = 0

    foreach ($icon in $stage.Icons) {
        $categoryDir = Join-Path $estateDir $icon.Category
        New-Item -ItemType Directory -Force -Path $categoryDir | Out-Null
        Set-Content -Path (Join-Path $categoryDir $icon.FileName) -Value $icon.Svg -Encoding UTF8 -NoNewline

        $manifestFiles.Add([ordered]@{
            name   = $icon.Name
            path   = "microsoft/$estate/$($icon.Category)/$($icon.FileName)"
            source = $icon.Source
            sha256 = $icon.Sha256
        })

        $libraryEntries.Add([ordered]@{
            data   = "data:image/svg+xml;base64,$($icon.Base64)"
            w      = $icon.W
            h      = $icon.H
            title  = $icon.Name
            aspect = 'fixed'
        })

        if ($builtinNames.Contains($icon.Name)) { $skipped++; continue }
        $embedded.Add([ordered]@{
            provider = 'microsoft'
            category = "$estate/$($icon.Category)"
            name     = $icon.Name
            aliases  = @()
            w        = $icon.W
            h        = $icon.H
            ref      = 'embedded'
            style    = "shape=image;verticalLabelPosition=bottom;html=1;verticalAlign=top;aspect=fixed;imageAspect=0;image=data:image/svg+xml,$($icon.Base64);"
            tags     = "$estate $($icon.Category) $($icon.Name.ToLowerInvariant())"
        })
    }

    $libraryPath = Join-Path $RepoRoot "libraries/$estate.xml"
    New-Item -ItemType Directory -Force -Path (Split-Path $libraryPath) | Out-Null
    $libraryJson = ConvertTo-Json -InputObject @($libraryEntries) -Depth 4 -Compress
    Set-Content -Path $libraryPath -Value "<mxlibrary>$libraryJson</mxlibrary>" -Encoding UTF8 -NoNewline

    $manifestEstates[$estate] = [ordered]@{
        label       = $stage.Source.Label
        source      = $stage.Source.Url
        reference   = $stage.Source.Reference
        pack_sha256 = $stage.PackSha
        synced      = $syncedAt
        count       = $stage.Icons.Count
        files       = $manifestFiles
    }

    Write-Host "[$estate] mirrored $($stage.Icons.Count) icons, $skipped already covered by a builtin reference"
}

$manifest = [ordered]@{
    generated = $syncedAt
    notice    = 'Icons are Microsoft property, mirrored here on the permitted-use basis stated in each source pack''s terms: they may be copied, distributed, and displayed for use in architecture diagrams, training materials, and documentation.'
    estates   = $manifestEstates
}
New-Item -ItemType Directory -Force -Path (Split-Path $manifestPath) | Out-Null
Set-Content -Path $manifestPath -Value (ConvertTo-Json -InputObject $manifest -Depth 6) -Encoding UTF8 -NoNewline

$merged = [System.Collections.Generic.List[object]]::new()
foreach ($icon in $builtin) { $merged.Add($icon) }
foreach ($icon in $embedded) { $merged.Add($icon) }

$index.generated = $syncedAt
$index.count = $merged.Count
$index.icons = $merged
Set-Content -Path $indexPath -Value (ConvertTo-Json -InputObject $index -Depth 5 -Compress) -Encoding UTF8 -NoNewline

Write-Host "wrote $indexPath ($($builtin.Count) builtin + $($embedded.Count) embedded = $($merged.Count) icons)"
Write-Host "wrote $manifestPath ($($manifestEstates.Count) estates)"
