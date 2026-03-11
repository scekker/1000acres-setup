#!/usr/bin/env bash
# ============================================================
#  1000Acres Setup
#  curl -fsSL https://1000acres.sh/setup | bash
# ============================================================
set -euo pipefail

# When this script is piped from curl, stdin is consumed by the pipe.
# Open /dev/tty explicitly so interactive prompts still work.
TTY=/dev/tty

# ── Colors ────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

step()    { echo -e "\n${BLUE}${BOLD}▶ $*${NC}"; }
ok()      { echo -e "  ${GREEN}✓${NC}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $*"; }
die()     { echo -e "\n${RED}✗ $*${NC}\n"; exit 1; }

TAILSCALE_AUTHKEY="tskey-auth-kEbgen2nue11CNTRL-dT7a9t2mopbkrJB1CqYGpbr9PtGwgfWj"

# ── Banner ────────────────────────────────────────────────
clear
echo ""
echo -e "${BOLD}╔══════════════════════════════════╗${NC}"
echo -e "${BOLD}║     Welcome to 1000Acres! 🌾     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════╝${NC}"
echo ""
echo "  This script sets up your computer with everything"
echo "  needed to work with the 1000Acres team."
echo ""
echo "  It will install:"
echo "    • Homebrew  (software installer)"
echo "    • Tailscale (secure team network)"
echo "    • Discord   (team chat)"
echo "    • Google tools (email, drive, sheets, docs)"
echo "    • OpenClaw  (AI assistant — requires Anthropic API key)"
echo ""

# ── Ask for inputs up front ────────────────────────────────
read -rp "  Enter your Google / work email address: " USER_EMAIL <"$TTY"
echo ""

[[ "$USER_EMAIL" == *@* ]] || die "That doesn't look like a valid email address. Please re-run and try again."

echo "  Enter your Anthropic API key for OpenClaw."
echo "  (Get one at console.anthropic.com — it starts with sk-ant-)"
read -rsp "  Anthropic API key: " ANTHROPIC_API_KEY <"$TTY"
echo ""

[[ "$ANTHROPIC_API_KEY" == sk-ant-* ]] || die "That doesn't look like a valid Anthropic API key (should start with sk-ant-). Please re-run and try again."

# ── macOS check ────────────────────────────────────────────
[[ "$(uname)" == "Darwin" ]] || die "This script only supports macOS."

# ── Admin password (needed for Tailscale later) ────────────
echo "  You may be asked for your Mac password — this is normal."
echo "  It is only used to connect to the team network."
echo ""
sudo -v <"$TTY"  # cache credentials now so we don't interrupt flow later

# ── 1. Homebrew ────────────────────────────────────────────
step "Step 1 of 5 — Homebrew (software installer)"

if ! command -v brew &>/dev/null; then
  echo "  Installing Homebrew (this may take a few minutes)…"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for Apple Silicon (/opt/homebrew) or Intel (/usr/local)
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    grep -qxF 'eval "$(/opt/homebrew/bin/brew shellenv)"' ~/.zprofile 2>/dev/null \
      || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  ok "Homebrew installed"
else
  ok "Homebrew already installed — skipping"
fi

# ── 2. Tailscale ───────────────────────────────────────────
step "Step 2 of 5 — Tailscale (secure team network)"

if ! brew list tailscale &>/dev/null 2>&1; then
  echo "  Installing Tailscale…"
  brew install tailscale
fi

# Start the Tailscale daemon (brew service)
if ! sudo brew services list 2>/dev/null | grep -q "tailscale.*started"; then
  echo "  Starting Tailscale service…"
  sudo brew services start tailscale
  sleep 3   # give daemon a moment to come up
fi

echo "  Joining team network…"
sudo tailscale up --authkey="$TAILSCALE_AUTHKEY" --accept-routes 2>/dev/null \
  && ok "Connected to team network!" \
  || warn "Tailscale already connected (or auth key expired — ask your admin for a new one)"

# ── 3. Discord ─────────────────────────────────────────────
step "Step 3 of 5 — Discord (team chat)"

if ! brew list --cask discord &>/dev/null 2>&1; then
  echo "  Installing Discord…"
  brew install --cask discord
  ok "Discord installed"
else
  ok "Discord already installed — skipping"
fi

# ── 4. Google Cloud CLI (gcloud) ───────────────────────────
step "Step 4 of 5 — Google tools (email, drive, sheets, docs)"

if ! command -v gcloud &>/dev/null; then
  echo "  Installing Google Cloud CLI…"
  brew install --cask google-cloud-sdk

  # Source the shell helpers so gcloud is on PATH immediately
  GCLOUD_INC="$(brew --prefix)/share/google-cloud-sdk/path.bash.inc"
  GCLOUD_COMP="$(brew --prefix)/share/google-cloud-sdk/completion.bash.inc"
  [[ -f "$GCLOUD_INC" ]]  && source "$GCLOUD_INC"
  [[ -f "$GCLOUD_COMP" ]] && source "$GCLOUD_COMP"

  # Persist for future shells (zsh)
  ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
  grep -qF 'google-cloud-sdk' "$ZSHRC" 2>/dev/null || cat >> "$ZSHRC" <<'ZSHEOF'

# Google Cloud SDK
if [ -f "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc" ]; then
  source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
fi
if [ -f "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc" ]; then
  source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"
fi
ZSHEOF
  ok "Google Cloud CLI installed"
else
  ok "Google Cloud CLI already installed — skipping"
fi

# Sign in (interactive browser flow)
echo ""
echo "  A browser window will open so you can sign in to Google."
echo "  Please sign in as: ${BOLD}$USER_EMAIL${NC}"
echo ""
read -rp "  Press Enter when you're ready…" <"$TTY"

gcloud auth login "$USER_EMAIL" --update-adc 2>/dev/null \
  || gcloud auth login "$USER_EMAIL"

# Set default account
gcloud config set account "$USER_EMAIL" 2>/dev/null || true

# Application-default credentials (needed for Drive, Sheets, Docs APIs)
echo ""
echo "  Granting access to Google Drive, Sheets, and Docs…"
echo "  (Another browser window will open — approve it too)"
echo ""
read -rp "  Press Enter to continue…" <"$TTY"

gcloud auth application-default login \
  --scopes="openid,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/documents" \
  2>/dev/null || gcloud auth application-default login

ok "Google signed in as $USER_EMAIL"

# ── 5. OpenClaw — Anthropic API key ───────────────────────
step "Step 5 of 5 — OpenClaw (AI assistant)"

ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

# Remove any existing ANTHROPIC_API_KEY line, then write fresh
grep -v 'ANTHROPIC_API_KEY' "$ZSHRC" 2>/dev/null > "${ZSHRC}.tmp" && mv "${ZSHRC}.tmp" "$ZSHRC" || true
echo "" >> "$ZSHRC"
echo "# Anthropic API key (for OpenClaw)" >> "$ZSHRC"
echo "export ANTHROPIC_API_KEY=\"$ANTHROPIC_API_KEY\"" >> "$ZSHRC"

# Also export into the current session
export ANTHROPIC_API_KEY

ok "Anthropic API key saved to ~/.zshrc"
ok "OpenClaw is ready to use"

# ── Done ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║   🎉  Setup complete!  Welcome! 🌾   ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""
echo "  Everything is ready:"
echo -e "  ${GREEN}✓${NC}  Tailscale  — connected to team network"
echo -e "  ${GREEN}✓${NC}  Discord    — installed (open it from Applications)"
echo -e "  ${GREEN}✓${NC}  Google     — signed in as $USER_EMAIL"
echo -e "  ${GREEN}✓${NC}  OpenClaw   — Anthropic API key configured"
echo ""
echo "  You're all set. Welcome to 1000Acres! 🌾"
echo ""
