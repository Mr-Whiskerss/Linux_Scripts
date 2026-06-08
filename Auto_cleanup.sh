#!/usr/bin/env bash
# =============================================================================
# system_cleanup.sh — APT junk purge + Trash auto-clear
# =============================================================================
# Usage:
#   ./system_cleanup.sh              # Interactive (asks before trash clear)
#   ./system_cleanup.sh --auto       # Non-interactive / cron-safe
#   ./system_cleanup.sh --dry-run    # Preview only, no changes made
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Flags ─────────────────────────────────────────────────────────────────────
AUTO=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --auto)    AUTO=true ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo -e "${BOLD}Usage:${RESET} $0 [--auto] [--dry-run]"
      echo "  --auto      Non-interactive mode (no prompts)"
      echo "  --dry-run   Preview actions without making changes"
      exit 0 ;;
    *)
      echo -e "${RED}Unknown option:${RESET} $arg  (use --help for usage)"
      exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
log_section() { echo -e "\n${CYAN}${BOLD}══ $1 ══${RESET}"; }
log_ok()      { echo -e "  ${GREEN}✔${RESET}  $1"; }
log_info()    { echo -e "  ${YELLOW}→${RESET}  $1"; }
log_skip()    { echo -e "  ${YELLOW}⊘${RESET}  $1 ${YELLOW}(dry-run)${RESET}"; }

run() {
  # run <description> <command...>
  local desc="$1"; shift
  if $DRY_RUN; then
    log_skip "$desc"
  else
    log_info "$desc"
    if ! "$@" 2>&1 | sed 's/^/      /'; then
      echo -e "  ${RED}✘  $desc failed${RESET}"
    else
      log_ok "Done"
    fi
  fi
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${BOLD}✘  This script must be run as root (sudo).${RESET}"
    exit 1
  fi
}

human_size() {
  # Print human-readable size of a path (if it exists)
  local path="$1"
  if [[ -e "$path" ]]; then
    du -sh "$path" 2>/dev/null | awk '{print $1}'
  else
    echo "0"
  fi
}

# ── Preflight ─────────────────────────────────────────────────────────────────
require_root

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════╗"
echo "║        System Cleanup Utility        ║"
echo "╚══════════════════════════════════════╝${RESET}"
$DRY_RUN && echo -e "${YELLOW}  ⚡ DRY-RUN MODE — no changes will be made${RESET}"

# ── 1. APT Cache ──────────────────────────────────────────────────────────────
log_section "APT Cache"

APT_CACHE_SIZE=$(human_size /var/cache/apt/archives)
log_info "Current apt cache size: ${BOLD}${APT_CACHE_SIZE}${RESET}"

run "apt-get autoclean (remove stale .deb packages)" \
  apt-get autoclean -y

run "apt-get clean (remove all cached .deb packages)" \
  apt-get clean

# ── 2. Unused Dependencies ────────────────────────────────────────────────────
log_section "Unused Packages"

AUTOREMOVE_LIST=$(apt-get --dry-run autoremove 2>/dev/null | grep "^Remv" | awk '{print $2}' | head -20)
if [[ -n "$AUTOREMOVE_LIST" ]]; then
  log_info "Packages to be removed:"
  echo "$AUTOREMOVE_LIST" | sed 's/^/      /'
  run "apt-get autoremove (remove unused dependencies)" \
    apt-get autoremove -y
else
  log_ok "No unused packages found"
fi

# ── 3. Old Kernel Images ──────────────────────────────────────────────────────
log_section "Old Kernel Cleanup"

CURRENT_KERNEL=$(uname -r)
log_info "Running kernel: ${BOLD}${CURRENT_KERNEL}${RESET}"

OLD_KERNELS=$(dpkg --list 'linux-image-*' 'linux-headers-*' 2>/dev/null \
  | awk '/^ii/{print $2}' \
  | grep -v "$CURRENT_KERNEL" \
  | grep -v "linux-image-generic" \
  | grep -v "linux-headers-generic" \
  || true)

if [[ -n "$OLD_KERNELS" ]]; then
  log_info "Old kernel packages found:"
  echo "$OLD_KERNELS" | sed 's/^/      /'
  # shellcheck disable=SC2086
  run "Remove old kernel packages" \
    apt-get purge -y $OLD_KERNELS
else
  log_ok "No old kernels to remove"
fi

# ── 4. Systemd Journal Logs ───────────────────────────────────────────────────
log_section "Systemd Journal"

JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | awk '{print $NF}' || echo "unknown")
log_info "Journal disk usage: ${BOLD}${JOURNAL_SIZE}${RESET}"

run "Vacuum journal logs older than 14 days" \
  journalctl --vacuum-time=14d

run "Cap journal size to 200 MiB" \
  journalctl --vacuum-size=200M

# ── 5. Trash ──────────────────────────────────────────────────────────────────
log_section "Trash / Recycle Bin"

# Collect all trash dirs for root + all real users
TRASH_DIRS=()

# Root's own trash
[[ -d /root/.local/share/Trash ]] && TRASH_DIRS+=("/root/.local/share/Trash")

# Each regular user's trash
while IFS=: read -r _user _ uid _ _ home _; do
  if [[ "$uid" -ge 1000 && -d "$home/.local/share/Trash" ]]; then
    TRASH_DIRS+=("$home/.local/share/Trash")
  fi
done < /etc/passwd

# Per-mount .Trash-1000 directories
while IFS= read -r d; do
  TRASH_DIRS+=("$d")
done < <(find / -maxdepth 3 -name ".Trash-*" -type d 2>/dev/null || true)

if [[ ${#TRASH_DIRS[@]} -eq 0 ]]; then
  log_ok "No trash directories found"
else
  TOTAL_TRASH=$(du -sch "${TRASH_DIRS[@]}" 2>/dev/null | tail -1 | awk '{print $1}')
  log_info "Total trash size: ${BOLD}${TOTAL_TRASH}${RESET}"

  CONFIRM=y
  if ! $AUTO && ! $DRY_RUN; then
    echo -e "\n  ${YELLOW}Empty all trash? This is irreversible. [y/N]:${RESET} \c"
    read -r CONFIRM
  fi

  if [[ "${CONFIRM,,}" == "y" ]]; then
    for dir in "${TRASH_DIRS[@]}"; do
      run "Empty: $dir" \
        rm -rf "${dir:?}/files" "${dir:?}/info"
    done
  else
    log_info "Skipped trash cleanup"
  fi
fi

# ── 6. /tmp Cleanup ───────────────────────────────────────────────────────────
log_section "/tmp Cleanup"

TMP_SIZE=$(human_size /tmp)
log_info "/tmp size: ${BOLD}${TMP_SIZE}${RESET}"

run "Remove files in /tmp older than 7 days" \
  find /tmp -mindepth 1 -mtime +7 -delete

# ── 7. Thumbnail Cache ────────────────────────────────────────────────────────
log_section "Thumbnail Cache"

while IFS=: read -r _user _ uid _ _ home _; do
  if [[ "$uid" -ge 1000 && -d "$home/.cache/thumbnails" ]]; then
    THUMB_SIZE=$(human_size "$home/.cache/thumbnails")
    log_info "Thumbnail cache for $home: ${BOLD}${THUMB_SIZE}${RESET}"
    run "Clear thumbnail cache for $home" \
      rm -rf "${home}/.cache/thumbnails"
  fi
done < /etc/passwd

# ── Summary ───────────────────────────────────────────────────────────────────
echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════╗"
echo "║          Cleanup Complete ✔          ║"
echo "╚══════════════════════════════════════╝${RESET}"

if $DRY_RUN; then
  echo -e "${YELLOW}  Dry-run mode — re-run without --dry-run to apply changes.${RESET}"
fi

echo ""
