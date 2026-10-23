param(
    [string]$Lute = 'lute.exe',
    [string]$SourcePath,
    [string]$PreviewPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $SourcePath) {
    $SourcePath = Join-Path $projectRoot 'src/server/Map/Harbour.luau'
}
$harnessPath = Join-Path $PSScriptRoot 'harbour-geometry.luau'
$source = [IO.File]::ReadAllText($SourcePath)
$harness = [IO.File]::ReadAllText($harnessPath)

# Keep the production implementation intact. Only dependency bindings and the
# final return are replaced in this temporary, instrumented copy.
$source = [regex]::Replace($source, 'local (\w+) = require\(script\.Parent\.(\w+)\)', 'local $1 = dependencies.$2')
$beachTakesIsland = if ($source -match 'local function buildBeach\(shape: Shape, island: Model,') { 'true' } else { 'false' }
$exports = 'return { makeShape = makeShape, buildGround = buildGround, buildBeach = buildBeach, buildPlaza = buildPlaza, beachFrame = beachFrame, coastDistance = coastDistance, heightAt = heightAt, beachWeight = beachWeight, LAND = LAND, CELL = CELL, GROUND_MARGIN = GROUND_MARGIN, ensurePlazaPaving = Harbour.ensurePlazaPaving, beachTakesIsland = ' + $beachTakesIsland + ' }'
if ($source -notmatch 'return Harbour\s*$') {
    throw 'Harbour module return changed; update the geometry harness export hook.'
}
$source = [regex]::Replace($source, 'return Harbour\s*$', $exports)
if (-not $harness.Contains('-- HARBOUR_SOURCE --')) {
    throw 'Geometry harness source marker is missing.'
}
$program = $harness.Replace('-- HARBOUR_SOURCE --', $source)
# Exercise the shared foundation code and radial islands alongside the harbour.
foreach ($module in @('Biomes', 'Seabed', 'Islands')) {
    $modulePath = if ($module -eq 'Biomes') { 'src/shared/Biomes.luau' } else { "src/server/Map/$module.luau" }
    $moduleSource = [IO.File]::ReadAllText((Join-Path $projectRoot $modulePath))
    $moduleSource = [regex]::Replace($moduleSource, 'local (\w+) = require\(script\.Parent\.(\w+)\)', 'local $1 = dependencies.$2')
    $moduleSource = $moduleSource.Replace('require(ReplicatedStorage.Shared.Biomes)', 'dependencies.Biomes')
    $program = $program.Replace("-- $($module.ToUpperInvariant())_SOURCE --", $moduleSource)
}
$program = $program.Replace('false -- EXPORT_PREVIEW --', $(if ($PreviewPath) { 'true' } else { 'false' }))
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('harbour-geometry-' + [guid]::NewGuid().ToString('N') + '.luau')
try {
    [IO.File]::WriteAllText($temporary, $program, [Text.UTF8Encoding]::new($false))
    $output = & $Lute run $temporary
    $exitCode = $LASTEXITCODE
    $inPreview = $false
    $previewLines = [Collections.Generic.List[string]]::new()
    foreach ($line in $output) {
        if ($line -eq 'HARBOUR_SVG_BEGIN') { $inPreview = $true; continue }
        if ($line -eq 'HARBOUR_SVG_END') { $inPreview = $false; continue }
        if ($inPreview) { $previewLines.Add($line) } else { Write-Output $line }
    }
    if ($PreviewPath -and $previewLines.Count -gt 0) {
        $resolvedPreview = [IO.Path]::GetFullPath($PreviewPath)
        [IO.File]::WriteAllLines($resolvedPreview, $previewLines, [Text.UTF8Encoding]::new($false))
        Write-Output "Geometry inspection SVG: $resolvedPreview"
    }
    if ($exitCode -ne 0) {
        throw "Harbour geometry checks failed (Lute exit $LASTEXITCODE)."
    }
} finally {
    # This is one generated file, never a source directory.
    if (Test-Path -LiteralPath $temporary) {
        Remove-Item -LiteralPath $temporary -Force
    }
}
