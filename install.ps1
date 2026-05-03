$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/LazyVim/starter"
$NvimConfigDir = Join-Path $env:LOCALAPPDATA "nvim"
$NvimDataDir = Join-Path $env:LOCALAPPDATA "nvim-data"

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

    $Backup = "$Path.bak"

    if (Test-Path $Backup) {
        $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $Backup = "$Path.bak-$Timestamp"
    }

    Log "Создаю бэкап: $Path -> $Backup"
    Move-Item -Path $Path -Destination $Backup
}

function Backup-NeovimFiles {
    Log "Проверяю существующие файлы Neovim и создаю бэкапы"

    Backup-Path $NvimConfigDir
    Backup-Path $NvimDataDir
}

function Install-LazyVim {
    Log "Клонирую LazyVim starter"

    git clone $RepoUrl $NvimConfigDir

    $GitDir = Join-Path $NvimConfigDir ".git"

    if (Test-Path $GitDir) {
        Log "Удаляю .git из установленной конфигурации LazyVim"
        Remove-Item -Recurse -Force $GitDir
    }
}

function Configure-LazyVim {
    Log "Записываю пользовательскую конфигурацию LazyVim"

    $ConfigDir = Join-Path $NvimConfigDir "lua\config"
    $PluginsDir = Join-Path $NvimConfigDir "lua\plugins"

    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    New-Item -ItemType Directory -Force -Path $PluginsDir | Out-Null

    $KeymapsPath = Join-Path $ConfigDir "keymaps.lua"
    $ColorschemePath = Join-Path $PluginsDir "colorscheme.lua"

@'
-- Выход из режима вставки по jj
vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })
'@ | Set-Content -Path $KeymapsPath -Encoding UTF8

@'
return {
  {
    "hase9awa/kanagawa.nvim",
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "kanagawa",
    },
  },
}
'@ | Set-Content -Path $ColorschemePath -Encoding UTF8
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
Install-LazyVim
Configure-LazyVim
Sync-LazyVim
Start-Neovim
