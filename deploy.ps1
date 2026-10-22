$ErrorActionPreference = "Stop"

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
    if (-not $targetUserProfile) {
        throw "USERPROFILE no está definido."
    }
}

Write-Host "========================================="
Write-Host "   Modelus - Deploy Local"
Write-Host "========================================="

# 1. Compilar el proyecto de validaciones/generadores (opcional si es puro Lua, pero buena práctica)
Write-Host "[1/2] Compilando con Gradle..."
Push-Location (Join-Path $PSScriptRoot "java")
$previousPzJar = $env:PZ_JAR
try {
    if ($isWsl -and -not $env:PZ_JAR) {
        $env:PZ_JAR = "/mnt/d/SteamLibrary/steamapps/common/ProjectZomboid/projectzomboid.jar"
    }
    gradle build
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle build falló con código $LASTEXITCODE"
    }
} finally {
    $env:PZ_JAR = $previousPzJar
    Pop-Location
}

# 2. Desplegar los archivos del mod
Write-Host "[2/2] Desplegando archivos en el directorio del juego..."
$sourceDir = Join-Path $PSScriptRoot "mods\modelus"
$targetBaseDir = Join-Path $targetUserProfile "Zomboid/mods"
$targetDir = Join-Path $targetBaseDir "modelus"
$versionLine = Select-String -Path (Join-Path $sourceDir "common/mod.info") -Pattern '^modversion=(\d+\.\d+\.\d+)$' | Select-Object -First 1
if (-not $versionLine) {
    throw "No se pudo leer modversion desde common/mod.info."
}
$modVersion = $versionLine.Matches[0].Groups[1].Value
$currentJarName = "modelus-$modVersion.jar"
$sourceJar = Join-Path $sourceDir "common/media/java/$currentJarName"
if (-not (Test-Path -LiteralPath $sourceJar -PathType Leaf)) {
    throw "No se encontró el JAR de la versión ${modVersion}: $sourceJar"
}

# Validar que exista la ruta base de los mods
if (-not (Test-Path $targetBaseDir)) {
    Write-Host "Creando directorio base de mods: $targetBaseDir"
    New-Item -ItemType Directory -Path $targetBaseDir | Out-Null
}

# Preparar una copia completa en el mismo disco antes de tocar el mod instalado.
$deploymentId = [guid]::NewGuid().ToString("N")
$stagingDir = Join-Path $targetBaseDir ".modelus-staging-$deploymentId"
$backupDir = Join-Path (Split-Path $targetBaseDir -Parent) ".modelus-backup-$deploymentId"
$deploymentCommitted = $false
try {
    New-Item -ItemType Directory -Path $stagingDir | Out-Null
    Get-ChildItem -LiteralPath $sourceDir -Force | Copy-Item -Destination $stagingDir -Recurse -Force

    $stagedJarDir = Join-Path $stagingDir "common/media/java"
    Get-ChildItem -LiteralPath $stagedJarDir -Filter "modelus-*.jar" -File |
        Where-Object { $_.Name -ne $currentJarName } |
        Remove-Item -Force

    $stagedModInfo = Join-Path $stagingDir "common/mod.info"
    $stagedJar = Join-Path $stagedJarDir $currentJarName
    if (-not (Test-Path -LiteralPath $stagedModInfo -PathType Leaf) -or
        -not (Test-Path -LiteralPath $stagedJar -PathType Leaf)) {
        throw "La copia temporal no contiene mod.info y el JAR $currentJarName."
    }

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

if (-not $deploymentCommitted) {
    throw "El despliegue no se completó."
}

Write-Host "  - Versión $modVersion instalada en: $targetDir"

Write-Host "========================================="
Write-Host " ¡Deploy finalizado con éxito! "
Write-Host "========================================="
