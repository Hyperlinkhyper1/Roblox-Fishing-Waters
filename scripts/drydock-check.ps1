param([string]$Lute = 'lute.exe')

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$program = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'drydock-geometry.luau'))
$shared = [regex]::Split([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'harbour-geometry.luau')), 'local CFrame = \{\}', 2)[0]
$program = $program.Replace('-- SHARED_PRIMITIVES --', $shared)
$modules = [ordered]@{
    'LOWPOLY' = 'src/server/Map/LowPoly.luau'
    'PROPS' = 'src/server/Map/Props.luau'
    'FISHFREEZERGEOMETRY' = 'src/server/Map/FishFreezerGeometry.luau'
    'FISHFREEZER' = 'src/server/Map/FishFreezer.luau'
    'IMPORTEDMODEL' = 'src/server/Map/ImportedModel.luau'
    'SHOPDESKGEOMETRY' = 'src/server/Map/ShopDeskGeometry.luau'
    'CASHREGISTERGEOMETRY' = 'src/server/Map/CashRegisterGeometry.luau'
    'SHOPDESK' = 'src/server/Map/ShopDesk.luau'
    'BASEHOUSE' = 'src/server/Map/BaseHouse.luau'
    'MEDITERRANEAN' = 'src/server/Map/Mediterranean.luau'
    'BEACHDETAILS' = 'src/server/Map/BeachDetails.luau'
    'ROWBOAT' = 'src/server/Rowboat.luau'
    'FISHINGBOAT' = 'src/server/FishingBoat.luau'
    'SHIPWRIGHT' = 'src/server/Map/Shipwright.luau'
    'DRYDOCKINTERIOR' = 'src/server/Map/DrydockInterior.luau'
    'DRYDOCK' = 'src/server/Map/Drydock.luau'
    'RODSHOP' = 'src/server/Map/RodShop.luau'
    'SEABED' = 'src/server/Map/Seabed.luau'
    'HARBOUR' = 'src/server/Map/Harbour.luau'
    'BIOMES' = 'src/shared/Biomes.luau'
    'BOATCATALOG' = 'src/shared/BoatCatalog.luau'
    'DRYDOCKLAUNCH' = 'src/server/DrydockLaunch.luau'
    'DRYDOCKCAMERA' = 'src/client/DrydockCamera.luau'
}
foreach ($entry in $modules.GetEnumerator()) {
    $source = [IO.File]::ReadAllText((Join-Path $projectRoot $entry.Value))
    $source = [regex]::Replace($source, 'local (\w+) = require\(script\.Parent\.(?:Parent\.)?(\w+)\)', 'local $1 = dependencies.$2')
    $source = [regex]::Replace($source, 'local (\w+) = require\(ReplicatedStorage\.Shared\.(\w+)\)', 'local $1 = dependencies.$2')
    if ($entry.Key -eq 'HARBOUR') {
        $source = [regex]::Replace($source, 'return Harbour\s*$', 'Harbour.makeShape = makeShape; Harbour.coastDistance = coastDistance; Harbour.heightAt = heightAt; Harbour.buildBase = buildBase; Harbour.buildPlaza = buildPlaza; Harbour.buildBeach = buildBeach; Harbour.buildRoad = buildRoad; Harbour.buildHouses = buildHouses; return Harbour')
    }
    $program = $program.Replace('-- ' + $entry.Key + '_SOURCE --', $source)
}
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('drydock-geometry-' + [guid]::NewGuid().ToString('N') + '.luau')
try {
    [IO.File]::WriteAllText($temporary, $program, [Text.UTF8Encoding]::new($false))
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Lute
    $start.Arguments = 'run "' + $temporary + '"'
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    [void]$process.Start()
    $outputTask = $process.StandardOutput.ReadToEndAsync()
    $errorTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(30000)) {
        $process.Kill()
        throw 'Drydock geometry checks exceeded their 30 second limit.'
    }
    Write-Output $outputTask.GetAwaiter().GetResult().TrimEnd()
    $errors = $errorTask.GetAwaiter().GetResult().TrimEnd()
    if ($errors) { Write-Output $errors }
    if ($process.ExitCode -ne 0) { throw "Drydock geometry checks failed (Lute exit $($process.ExitCode))." }
} finally {
    if ($process) { $process.Dispose() }
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
}
