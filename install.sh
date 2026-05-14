#!/usr/bin/env bash
set -euo pipefail

CONFIG_REPO_URL="${CONFIG_REPO_URL:-https://github.com/hase9awa/lazyvim-config.git}"
CONFIG_REPO_BRANCH="${CONFIG_REPO_BRANCH:-main}"

NVIM_CONFIG_DIR="${HOME}/.config/nvim"
MIN_NVIM_VERSION="0.11.2"

if [ -z "${BASH_VERSION:-}" ]; then
  echo "Пожалуйста, запустите скрипт через bash:"
  echo 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/hase9awa/lazyvim-setup/main/install.sh)"'
  exit 1
fi

log() {
  printf "\033[1;32m[ИНФО]\033[0m %s\n" "$1"
}

warn() {
  printf "\033[1;33m[ВНИМАНИЕ]\033[0m %s\n" "$1"
}

err() {
  printf "\033[1;31m[ОШИБКА]\033[0m %s\n" "$1" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

run_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

is_macos() {
  [ "$(uname -s)" = "Darwin" ]
}

detect_package_manager() {
  if is_macos; then
    if command_exists brew; then
      echo "brew"
    else
      echo "macos-no-brew"
    fi
  elif command_exists apt-get; then
    echo "apt"
  elif command_exists pacman; then
    echo "pacman"
  elif command_exists dnf; then
    echo "dnf"
  elif command_exists zypper; then
    echo "zypper"
  elif command_exists apk; then
    echo "apk"
  elif command_exists xbps-install; then
    echo "xbps"
  elif command_exists emerge; then
    echo "emerge"
  elif command_exists brew; then
    echo "brew"
  else
    echo "unknown"
  fi
}

install_homebrew_on_macos() {
  if command_exists brew; then
    return 0
  fi

  log "Homebrew не найден. Устанавливаю Homebrew."

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_dependencies() {
  local pm
  pm="$(detect_package_manager)"

  log "Обнаружен пакетный менеджер: ${pm}"

  case "$pm" in
  macos-no-brew)
    install_homebrew_on_macos
    brew install neovim git fzf ripgrep fd curl ca-certificates
    ;;
  brew)
    brew install neovim git fzf ripgrep fd curl ca-certificates
    ;;
  apt)
    run_sudo apt-get update
    run_sudo apt-get install -y \
      neovim git fzf ripgrep fd-find curl ca-certificates
    ;;
  pacman)
    run_sudo pacman -Syu --needed --noconfirm \
      neovim git fzf ripgrep fd curl ca-certificates
    ;;
  dnf)
    run_sudo dnf install -y \
      neovim git fzf ripgrep fd-find curl ca-certificates
    ;;
  zypper)
    run_sudo zypper --non-interactive install \
      neovim git fzf ripgrep fd curl ca-certificates
    ;;
  apk)
    run_sudo apk add --no-cache \
      neovim git fzf ripgrep fd curl ca-certificates
    ;;
  xbps)
    run_sudo xbps-install -Sy \
      neovim git fzf ripgrep fd curl ca-certificates
    ;;
  emerge)
    run_sudo emerge --ask=n \
      app-editors/neovim dev-vcs/git app-shells/fzf sys-apps/ripgrep sys-apps/fd net-misc/curl app-misc/ca-certificates
    ;;
  *)
    err "Пакетный менеджер не поддерживается."
    err "Установите зависимости вручную: neovim git fzf ripgrep fd curl ca-certificates"
    exit 1
    ;;
  esac

  if ! command_exists fd && command_exists fdfind; then
    mkdir -p "${HOME}/.local/bin"
    ln -sf "$(command -v fdfind)" "${HOME}/.local/bin/fd"
    export PATH="${HOME}/.local/bin:${PATH}"
    log "Создана ссылка: ~/.local/bin/fd -> fdfind"
  fi
}

version_ge() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

install_latest_neovim_appimage_linux() {
  local arch
  arch="$(uname -m)"

  if [ "$arch" != "x86_64" ]; then
    warn "Автоматическая установка Neovim AppImage настроена только для x86_64."
    warn "Установите Neovim >= ${MIN_NVIM_VERSION} вручную для архитектуры: ${arch}"
    return 1
  fi

  log "Устанавливаю последнюю стабильную версию Neovim AppImage в ~/.local/bin/nvim"

  mkdir -p "${HOME}/.local/bin"

  curl -L \
    "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.appimage" \
    -o "${HOME}/.local/bin/nvim"

  chmod +x "${HOME}/.local/bin/nvim"
  export PATH="${HOME}/.local/bin:${PATH}"

  log "Установлен Neovim: $(${HOME}/.local/bin/nvim --version | head -n1)"
}

ensure_neovim_version() {
  if ! command_exists nvim; then
    warn "Команда nvim не найдена после установки зависимостей."

    if is_macos; then
      err "На macOS попробуйте выполнить: brew install neovim"
      exit 1
    fi

    install_latest_neovim_appimage_linux
    return
  fi

  local current
  current="$(nvim --version | head -n1 | sed -E 's/.*v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"

  if version_ge "$current" "$MIN_NVIM_VERSION"; then
    log "Версия Neovim подходит: ${current}"
  else
    warn "Установленная версия Neovim ${current} старше требуемой ${MIN_NVIM_VERSION}."

    if is_macos; then
      log "Обновляю Neovim через Homebrew."
      brew upgrade neovim || brew install neovim
    else
      warn "Устанавливаю последнюю стабильную версию Neovim AppImage."
      install_latest_neovim_appimage_linux
    fi
  fi
}

backup_path() {
  local path="$1"

  if [ ! -e "$path" ]; then
    return 0
  fi

  local timestamp
  local backup
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup="${path}.bak-${timestamp}"

  log "Создаю бэкап: ${path} -> ${backup}"
  mv "$path" "$backup"
}

backup_neovim_files() {
  log "Проверяю существующие файлы Neovim и создаю бэкапы"

  backup_path "${HOME}/.config/nvim"
  backup_path "${HOME}/.local/share/nvim"
  backup_path "${HOME}/.local/state/nvim"
  backup_path "${HOME}/.cache/nvim"
}

install_lazyvim_config() {
  log "Клонирую конфигурацию LazyVim"
  log "Репозиторий: ${CONFIG_REPO_URL}"
  log "Ветка: ${CONFIG_REPO_BRANCH}"

  mkdir -p "${HOME}/.config"

  git clone \
    --depth 1 \
    --branch "${CONFIG_REPO_BRANCH}" \
    "${CONFIG_REPO_URL}" \
    "${NVIM_CONFIG_DIR}"

  if [ ! -f "${NVIM_CONFIG_DIR}/init.lua" ]; then
    warn "В репозитории не найден init.lua."
    warn "Для LazyVim желательно хранить полный конфиг Neovim в корне репозитория:"
    warn "  init.lua"
    warn "  lua/config/..."
    warn "  lua/plugins/..."
  fi

  log "Конфигурация установлена в ${NVIM_CONFIG_DIR}"
}

sync_lazyvim() {
  log "Запускаю Lazy sync"

  nvim --headless "+Lazy! sync" +qa || {
    warn "Не удалось выполнить Lazy sync в headless-режиме."
    warn "После открытия Neovim можно выполнить команду :Lazy sync вручную."
  }
}

start_neovim() {
  log "Запускаю Neovim"
  nvim
}

main() {
  install_dependencies
  ensure_neovim_version
  backup_neovim_files
  install_lazyvim_config
  sync_lazyvim
  start_neovim
}

main "$@"
