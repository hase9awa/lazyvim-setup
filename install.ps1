$ErrorActionPreference = "Stop"

$ConfigRepoUrl = if ($env:CONFIG_REPO_URL) {
    $env:CONFIG_REPO_URL
} else {
    "https://github.com/hase9awa/lazyvim-config.git"
}

$ConfigRepoBranch = if ($env:CONFIG_REPO_BRANCH) {
    $env:CONFIG_REPO_BRANCH
} else {
    "main"
}

$NvimConfigDir = Join-Path $env:LOCALAPPDATA "nvim"
$NvimDataDir = Join-Path $env:LOCALAPPDATA "nvim-data"
$NvimStateDir = Join-Path $env:LOCALAPPDATA "nvim-state"
$NvimCacheDir = Join-Path $env:LOCALAPPDATA "nvim-cache"

function Log {
    param([string]$Message)
    Write-Host "[ИНФО] $Message" -ForegroundColor Green
}

function Warn {
    param([string]$Message)
    Write-Host "[ВНИМАНИЕ] $Message" -ForegroundColor Yellow
}

function Fail {
    param([string]$Message)
    Write-Host "[ОШИБКА] $Message" -ForegroundColor Red
    exit 1
}

function Command-Exists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Install-Dependencies {
    Log "Проверяю пакетный менеджер Windows"

    if (Command-Exists winget) {
        Log "Обнаружен winget. Устанавливаю зависимости."

        winget install -e --id Neovim.Neovim --accept-source-agreements --accept-package-agreements
        winget install -e --id Git.Git --accept-source-agreements --accept-package-agreements
        winget install -e --id junegunn.fzf --accept-source-agreements --accept-package-agreements
        winget install -e --id BurntSushi.ripgrep.MSVC --accept-source-agreements --accept-package-agreements
        winget install -e --id sharkdp.fd --accept-source-agreements --accept-package-agreements

        return
    }

    if (Command-Exists choco) {
        Log "Обнаружен Chocolatey. Устанавливаю зависимости."

        choco install -y neovim git fzf ripgrep fd

        return
    }

    if (Command-Exists scoop) {
        Log "Обнаружен Scoop. Устанавливаю зависимости."

        scoop install neovim git fzf ripgrep fd

        return
    }

    Fail "Не найден winget, Chocolatey или Scoop. Установите один из них и запустите скрипт снова."
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Backup-Path {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return
    }

    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $Backup = "$Path.bak-$Timestamp"

    Log "Создаю бэкап: $Path -> $Backup"
    Move-Item -Path $Path -Destination $Backup
}

function Backup-NeovimFiles {
    Log "Проверяю существующие файлы Neovim и создаю бэкапы"

    Backup-Path $NvimConfigDir
    Backup-Path $NvimDataDir
    Backup-Path $NvimStateDir
    Backup-Path $NvimCacheDir
}

function Install-LazyVimConfig {
    Log "Клонирую конфигурацию LazyVim"
    Log "Репозиторий: $ConfigRepoUrl"
    Log "Ветка: $ConfigRepoBranch"

    git clone --depth 1 --branch $ConfigRepoBranch $ConfigRepoUrl $NvimConfigDir

    $InitLua = Join-Path $NvimConfigDir "init.lua"

    if (-not (Test-Path $InitLua)) {
        Warn "В репозитории не найден init.lua."
        Warn "Для LazyVim желательно хранить полный конфиг Neovim в корне репозитория:"
        Warn "  init.lua"
        Warn "  lua/config/..."
        Warn "  lua/plugins/..."
    }

    Log "Конфигурация установлена в $NvimConfigDir"
}

function Sync-LazyVim {
    Log "Запускаю Lazy sync"

    try {
        nvim --headless "+Lazy! sync" +qa
    }
    catch {
        Warn "Не удалось выполнить Lazy sync в headless-режиме."
        Warn "После открытия Neovim можно выполнить команду :Lazy sync вручную."
    }
}

function Start-Neovim {
    Log "Запускаю Neovim"
    nvim
}

Install-Dependencies
Refresh-Path

if (-not (Command-Exists git)) {
    Fail "Git не найден после установки. Перезапустите PowerShell и попробуйте снова."
}

if (-not (Command-Exists nvim)) {
    Fail "Neovim не найден после установки. Перезапустите PowerShell и попробуйте снова."
}

Backup-NeovimFiles
Install-LazyVimConfig
Sync-LazyVim
Start-Neovim
