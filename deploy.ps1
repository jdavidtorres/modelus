$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host "   Modelus - Deploy Local"
Write-Host "========================================="

# 1. Compilar el proyecto de validaciones/generadores (opcional si es puro Lua, pero buena práctica)
Write-Host "[1/2] Compilando con Gradle..."
Push-Location java
try {
    .\gradlew.bat build
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle build falló con código $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

# 2. Desplegar los archivos del mod
Write-Host "[2/2] Desplegando archivos en el directorio del juego..."
$sourceDir = ".\mods\modelus"
$targetBaseDir = "$env:USERPROFILE\Zomboid\mods"
$targetDir = "$targetBaseDir\modelus"

# Validar que exista la ruta base de los mods
if (-not (Test-Path $targetBaseDir)) {
    Write-Host "Creando directorio base de mods: $targetBaseDir"
    New-Item -ItemType Directory -Path $targetBaseDir | Out-Null
}

# Limpiar versión anterior
if (Test-Path $targetDir) {
    Write-Host "  - Eliminando versión anterior en destino..."
    Remove-Item -Recurse -Force $targetDir
}

# Copiar nueva versión
Write-Host "  - Copiando archivos a $targetDir..."
Copy-Item -Path $sourceDir -Destination $targetBaseDir -Recurse -Force

Write-Host "========================================="
Write-Host " ¡Deploy finalizado con éxito! "
Write-Host "========================================="
