#!/bin/bash
# Public-safe first-mile bootstrap for getting a GenWeb checkout.

set -e

GENWEB_REPO="${GENWEB_REPO:-genwebcorp/genweb}"
GENWEB_REPO_DIR="${GENWEB_REPO_DIR:-$HOME/genweb}"
HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
BASELINE_FORMULAS="gh git go-task"
HOMEBREW_BLOCK_BEGIN="# >>> GenWeb initial bootstrap Homebrew >>>"
HOMEBREW_BLOCK_END="# <<< GenWeb initial bootstrap Homebrew <<<"

OS=""

log_info() {
  printf '[INFO] %s\n' "$1"
}

log_success() {
  printf '[SUCCESS] %s\n' "$1"
}

log_error() {
  printf '[ERROR] %s\n' "$1" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

detect_os() {
  case "$(uname -s)" in
  Darwin)
    OS="mac"
    ;;
  Linux)
    OS="linux"
    ;;
  *)
    log_error "Unsupported operating system: $(uname -s)"
    exit 1
    ;;
  esac

  log_info "Detected OS: $OS"
}

expected_brew_bins() {
  if [ -n "${HOMEBREW_PREFIX:-}" ]; then
    printf '%s\n' "$HOMEBREW_PREFIX/bin/brew"
    return 0
  fi

  case "$OS" in
  mac)
    printf '%s\n' "/opt/homebrew/bin/brew" "/usr/local/bin/brew"
    ;;
  linux)
    printf '%s\n' "/home/linuxbrew/.linuxbrew/bin/brew"
    ;;
  esac
}

setup_homebrew_path() {
  local brew_bin=""
  local brew_dir=""

  if command_exists brew; then
    return 0
  fi

  while IFS= read -r brew_bin; do
    if [ -x "$brew_bin" ]; then
      brew_dir="$(dirname "$brew_bin")"
      export PATH="$brew_dir:$PATH"
      return 0
    fi
  done < <(expected_brew_bins)

  return 1
}

install_homebrew_if_missing() {
  if ! setup_homebrew_path; then
    log_info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALL_URL")"
  fi

  if ! setup_homebrew_path; then
    log_error "Homebrew installation completed, but brew is not on PATH"
    exit 1
  fi

  eval "$(brew shellenv)"
  log_success "Homebrew ready: $(brew --version | head -1)"
}

shell_startup_files() {
  case "$OS" in
  mac)
    printf '%s\n' "$HOME/.zprofile" "$HOME/.bash_profile"
    ;;
  linux)
    printf '%s\n' "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zprofile"
    ;;
  esac
}

write_homebrew_shellenv_block() {
  local file_path="$1"
  local brew_bin="$2"
  local shellenv_line=""
  local temp_file=""

  shellenv_line="eval \"\$($brew_bin shellenv)\""
  temp_file="$(mktemp)"

  mkdir -p "$(dirname "$file_path")"
  touch "$file_path"

  if grep -Fq "$HOMEBREW_BLOCK_BEGIN" "$file_path" 2>/dev/null; then
    awk \
      -v begin="$HOMEBREW_BLOCK_BEGIN" \
      -v end="$HOMEBREW_BLOCK_END" \
      -v shellenv_line="$shellenv_line" '
        $0 == begin {
          if (!printed) {
            print begin
            print shellenv_line
            print end
            printed = 1
          }
          skipping = 1
          next
        }
        $0 == end {
          skipping = 0
          next
        }
        !skipping { print }
        END {
          if (!printed) {
            print ""
            print begin
            print shellenv_line
            print end
          }
        }
      ' "$file_path" >"$temp_file"
  else
    cat "$file_path" >"$temp_file"
    {
      printf '\n'
      printf '%s\n' "$HOMEBREW_BLOCK_BEGIN"
      printf '%s\n' "$shellenv_line"
      printf '%s\n' "$HOMEBREW_BLOCK_END"
    } >>"$temp_file"
  fi

  mv "$temp_file" "$file_path"
}

configure_homebrew_shellenv() {
  local brew_bin=""
  local startup_file=""

  brew_bin="$(command -v brew)"
  while IFS= read -r startup_file; do
    write_homebrew_shellenv_block "$startup_file" "$brew_bin"
  done < <(shell_startup_files)
}

install_baseline_tools() {
  local formula=""
  local missing_formulas=""
  local cmd=""

  for formula in $BASELINE_FORMULAS; do
    if ! brew list --formula "$formula" >/dev/null 2>&1; then
      missing_formulas="$missing_formulas $formula"
    fi
  done

  if [ -n "$missing_formulas" ]; then
    log_info "Installing baseline tools:$missing_formulas"
    # shellcheck disable=SC2086
    brew install --quiet $missing_formulas
  else
    log_info "Baseline Homebrew tools already installed"
  fi

  for cmd in gh git task; do
    if ! command_exists "$cmd"; then
      log_error "Required command is still missing after Homebrew install: $cmd"
      exit 1
    fi
  done
}

ensure_github_auth() {
  if gh auth status -h github.com >/dev/null 2>&1; then
    log_info "GitHub CLI is already authenticated"
    return 0
  fi

  log_info "Starting GitHub CLI authentication..."
  gh auth login -h github.com -p https -w
}

clone_or_reuse_repo() {
  local parent_dir=""

  if [ -e "$GENWEB_REPO_DIR" ]; then
    if [ -d "$GENWEB_REPO_DIR/.git" ] || git -C "$GENWEB_REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      log_info "Using existing checkout: $GENWEB_REPO_DIR"
      return 0
    fi

    log_error "GENWEB_REPO_DIR exists but is not a git checkout: $GENWEB_REPO_DIR"
    exit 1
  fi

  parent_dir="$(dirname "$GENWEB_REPO_DIR")"
  mkdir -p "$parent_dir"
  log_info "Cloning $GENWEB_REPO into $GENWEB_REPO_DIR..."
  gh repo clone "$GENWEB_REPO" "$GENWEB_REPO_DIR"
}

run_monorepo_bootstrap() {
  log_info "Running task bootstrap in $GENWEB_REPO_DIR..."
  (
    cd "$GENWEB_REPO_DIR"
    task bootstrap
  )
}

main() {
  detect_os
  install_homebrew_if_missing
  configure_homebrew_shellenv
  install_baseline_tools
  ensure_github_auth
  clone_or_reuse_repo
  run_monorepo_bootstrap

  log_success "Initial setup complete. Next, run 'task manage' from $GENWEB_REPO_DIR."
}

main "$@"
