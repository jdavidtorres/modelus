$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$deploySource = Join-Path $repoRoot "deploy.ps1"
$translationsPath = Join-Path $repoRoot "mods/modelus/common/media/lua/shared/Translate/EN/ContextMenu.json"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("modelus-deploy-test-" + [guid]::NewGuid().ToString("N"))
$scriptPath = Join-Path $tempRoot "deploy.ps1"
$pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
$modRoot = Join-Path $tempRoot "mods/modelus"
$luaRoot = Join-Path $modRoot "common/media/lua/client"

function Write-TestPayload([string]$Version = "0.9.1") {
    New-Item -ItemType Directory -Path $luaRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $modRoot "common/mod.info") -Value "modversion=$Version"
    Set-Content -LiteralPath (Join-Path $luaRoot "ModelusMainScreen.lua") -Value ('local versionText = "Modelus v{0}"' -f $Version)
    Set-Content -LiteralPath (Join-Path $luaRoot "AutoLoot.lua") -Value "print('Lua runtime')"
}

function Invoke-Validation {
    & $pwshPath -NoProfile -File $scriptPath -ValidateOnly *> $null
    return $LASTEXITCODE
}

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    Copy-Item -LiteralPath $deploySource -Destination $scriptPath
    Write-TestPayload
    if ((Invoke-Validation) -ne 0) { throw "Valid test payload was rejected." }
    if (Test-Path -LiteralPath (Join-Path $tempRoot "Zomboid")) {
        throw "ValidateOnly created a deployment target directory."
    }

    New-Item -ItemType Directory -Path (Join-Path $modRoot "common/media/java") | Out-Null
    Set-Content -LiteralPath (Join-Path $modRoot "common/media/java/test.jar") -Value "placeholder"
    if ((Invoke-Validation) -eq 0) { throw "JAR test payload was accepted." }
    Remove-Item -LiteralPath (Join-Path $modRoot "common/media/java/test.jar") -Force
    Set-Content -LiteralPath (Join-Path $modRoot "common/media/java/test.class") -Value "placeholder"
    if ((Invoke-Validation) -eq 0) { throw "Class test payload was accepted." }
    Remove-Item -LiteralPath (Join-Path $modRoot "common/media/java") -Recurse -Force

    Set-Content -LiteralPath (Join-Path $luaRoot "AutoLoot.lua") -Value "luajava.bindClass('example')"
    if ((Invoke-Validation) -eq 0) { throw "Java bridge reference was accepted." }
    Set-Content -LiteralPath (Join-Path $luaRoot "AutoLoot.lua") -Value "ModelusBridge = true"
    if ((Invoke-Validation) -eq 0) { throw "Custom bridge reference was accepted." }
    Set-Content -LiteralPath (Join-Path $luaRoot "AutoLoot.lua") -Value "print('Lua runtime')"
    Set-Content -LiteralPath (Join-Path $luaRoot "AutoLoot.lua") -Value "-- run gradle to regenerate"
    if ((Invoke-Validation) -eq 0) { throw "Gradle runtime instruction was accepted." }
    Set-Content -LiteralPath (Join-Path $luaRoot "AutoLoot.lua") -Value "print('Lua runtime')"

    Set-Content -LiteralPath (Join-Path $modRoot "common/mod.info") -Value "modversion=0.9.2"
    if ((Invoke-Validation) -eq 0) { throw "Mismatched versions were accepted." }

    $translations = Get-Content -LiteralPath $translationsPath -Raw | ConvertFrom-Json
    if ($translations.ContextMenu_ModelusAutoLootStart -ne "Auto Loot: collect" -or
        $translations.ContextMenu_ModelusAutoLootStop -ne "Auto Loot: stop collecting") {
        throw "Auto Loot translations are missing or changed."
    }
    Write-Host "All isolated deployment validation tests passed."
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
