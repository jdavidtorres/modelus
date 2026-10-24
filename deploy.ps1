param([switch]$ValidateOnly)

$ErrorActionPreference = "Stop"

function Get-ModelusVersion([string]$ModRoot) {
    $modInfoPath = Join-Path $ModRoot "common/mod.info"
    $mainScreenPath = Join-Path $ModRoot "common/media/lua/client/ModelusMainScreen.lua"
    if (-not (Test-Path -LiteralPath $modInfoPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $mainScreenPath -PathType Leaf)) {
        throw "El paquete debe contener common/mod.info y ModelusMainScreen.lua."
    }
    $versionLines = @(Select-String -Path $modInfoPath -Pattern '^modversion=(\d+\.\d+\.\d+)$')
    if ($versionLines.Count -ne 1) {
        throw "common/mod.info debe contener exactamente una declaración modversion válida."
    }
    $version = $versionLines[0].Matches[0].Groups[1].Value
    $display = Select-String -Path $mainScreenPath -Pattern 'local versionText = "Modelus v(\d+\.\d+\.\d+)"' |
        Select-Object -First 1
    if (-not $display -or $display.Matches[0].Groups[1].Value -ne $version) {
        throw "La versión visible no coincide con mod.info ($version)."
    }
    return $version
}

function Assert-LuaPayload([string]$ModRoot, [string]$ExpectedVersion) {
    $version = Get-ModelusVersion $ModRoot
    if ($ExpectedVersion -and $version -ne $ExpectedVersion) {
        throw "La versión del paquete ($version) no coincide con $ExpectedVersion."
    }
    $luaRoot = Join-Path $ModRoot "common/media/lua"
    if (-not (Test-Path -LiteralPath $luaRoot -PathType Container) -or
        -not (Get-ChildItem -LiteralPath $luaRoot -Filter "*.lua" -File -Recurse | Select-Object -First 1)) {
        throw "El paquete no contiene archivos Lua."
    }
    $artifacts = @(Get-ChildItem -LiteralPath $ModRoot -Recurse -File -Force |
        Where-Object { $_.Extension -in '.jar', '.class' })
    if ($artifacts.Count -gt 0) {
        throw "Se encontraron artefactos compilados en el árbol del mod: $($artifacts.FullName -join ', ')"
    }
    $luaFiles = @(Get-ChildItem -LiteralPath $luaRoot -Filter "*.lua" -File -Recurse)
    foreach ($file in $luaFiles) {
        if (Select-String -LiteralPath $file.FullName -Pattern '(?i)luajava|bindClass|ModelusBridge|com\.modelus|gradlew|gradle' -Quiet) {
            throw "El archivo Lua conserva una dependencia Java/Gradle: $($file.FullName)"
        }
    }
    return $version
}

$sourceDir = Join-Path $PSScriptRoot 'mods/modelus'
$modVersion = Assert-LuaPayload $sourceDir $null
if ($ValidateOnly) {
    Write-Host "Validación completada sin desplegar. Versión $modVersion validada."
    exit 0
}

$isWsl = Test-Path "/proc/sys/fs/binfmt_misc/WSLInterop"
if (-not $isWsl -and (Test-Path "/proc/sys/kernel/osrelease")) {
    $isWsl = (Get-Content "/proc/sys/kernel/osrelease" -Raw) -match "(?i)microsoft|wsl"
}

if ($isWsl) {
    $windowsUserProfile = (& powershell.exe -NoProfile -NonInteractive -Command '[Console]::Write($env:USERPROFILE)' 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $windowsUserProfile) {
        throw "No se pudo resolver USERPROFILE desde Windows."
    }
    $targetUserProfile = (& wslpath -u $windowsUserProfile 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $targetUserProfile) {
        throw "No se pudo convertir USERPROFILE a una ruta WSL: $windowsUserProfile"
    }
} else {
    $targetUserProfile = $env:USERPROFILE
    if (-not $targetUserProfile) { throw "USERPROFILE no está definido." }
}

Write-Host "========================================="
Write-Host "   Modelus - Deploy Local"
Write-Host "========================================="
$targetBaseDir = Join-Path $targetUserProfile "Zomboid/mods"
$targetDir = Join-Path $targetBaseDir "modelus"
if (-not (Test-Path -LiteralPath $targetBaseDir)) {
    Write-Host "Creando directorio base de mods: $targetBaseDir"
    New-Item -ItemType Directory -Path $targetBaseDir | Out-Null
}

$deploymentId = [guid]::NewGuid().ToString("N")
$stagingDir = Join-Path $targetBaseDir ".modelus-staging-$deploymentId"
$backupDir = Join-Path (Split-Path $targetBaseDir -Parent) ".modelus-backup-$deploymentId"
$deploymentCommitted = $false
try {
    New-Item -ItemType Directory -Path $stagingDir | Out-Null
    Get-ChildItem -LiteralPath $sourceDir -Force | Copy-Item -Destination $stagingDir -Recurse -Force
    Assert-LuaPayload $stagingDir $modVersion | Out-Null

    if (Test-Path -LiteralPath $targetDir) {
        Write-Host "  - Conservando la instalación anterior como respaldo: $backupDir"
        Move-Item -LiteralPath $targetDir -Destination $backupDir
    }
    try {
        Move-Item -LiteralPath $stagingDir -Destination $targetDir
        $deploymentCommitted = $true
    } catch {
        if (Test-Path -LiteralPath $backupDir) {
            Move-Item -LiteralPath $backupDir -Destination $targetDir
        }
        throw
    }
} finally {
    if (Test-Path -LiteralPath $stagingDir) {
        Remove-Item -LiteralPath $stagingDir -Recurse -Force
    }
}

if (-not $deploymentCommitted) { throw "El despliegue no se completó." }
Write-Host "  - Archivos Lua copiados correctamente."
Write-Host "  - Versión $modVersion instalada en: $targetDir"
Write-Host "========================================="
Write-Host " ¡Deploy finalizado con éxito! "
Write-Host "========================================="
