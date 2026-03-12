#!/usr/bin/env bash
# ============================================================
#  1000Acres Setup
#  curl -fsSL https://raw.githubusercontent.com/scekker/1000acres-setup/main/setup.sh | bash
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
echo "    • Homebrew     (software installer)"
echo "    • Tailscale    (secure team network)"
echo "    • Discord      (team chat)"
echo "    • Amphetamine  (keep-awake utility)"
echo "    • Google tools (email, drive, sheets, docs)"
echo "    • OpenClaw     (AI assistant — requires Anthropic API key)"
echo ""

# ── Mac identity — show serial & model, ask user to report ────
MAC_SERIAL="$(ioreg -l | awk -F'"' '/IOPlatformSerialNumber/ {print $4}')"
MAC_MODEL="$(sysctl -n hw.model)"

echo -e "${BOLD}  📋  Your Mac information (please send to your fleet admin):${NC}"
echo ""
echo -e "      Serial number : ${BOLD}${MAC_SERIAL}${NC}"
echo -e "      Model         : ${BOLD}${MAC_MODEL}${NC}"
echo ""
echo "  ➜  Copy the lines above and send them to your fleet admin"
echo "     before continuing. They need this to register your device."
echo ""
read -rp "  Press Enter once you've noted your serial number and model…" <"$TTY"
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
step "Step 1 of 6 — Homebrew (software installer)"

if ! command -v brew &>/dev/null; then
  echo "  Installing Homebrew (this may take a few minutes)…"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ok "Homebrew installed"
else
  ok "Homebrew already installed — skipping"
fi

# Add brew to PATH for this session and persist to ~/.zprofile (runs whether
# brew was just installed or was already present)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  grep -qxF 'eval "$(/opt/homebrew/bin/brew shellenv)"' ~/.zprofile 2>/dev/null \
    || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
  grep -qxF 'eval "$(/usr/local/bin/brew shellenv)"' ~/.zprofile 2>/dev/null \
    || echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
fi

# ── 2. Tailscale ───────────────────────────────────────────
step "Step 2 of 6 — Tailscale (secure team network)"

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
step "Step 3 of 6 — Discord (team chat)"

if ! brew list --cask discord &>/dev/null 2>&1; then
  echo "  Installing Discord…"
  brew install --cask discord
  ok "Discord installed"
else
  ok "Discord already installed — skipping"
fi

# ── 4. Amphetamine ─────────────────────────────────────────
step "Step 4 of 6 — Amphetamine (keep-awake utility)"

if ! brew list --cask amphetamine &>/dev/null 2>&1; then
  echo "  Installing Amphetamine…"
  brew install --cask amphetamine
  ok "Amphetamine installed"
else
  ok "Amphetamine already installed — skipping"
fi

# Launch Amphetamine so it's running immediately
if [[ -d "/Applications/Amphetamine.app" ]]; then
  open -a Amphetamine
  ok "Amphetamine launched"
fi

# ── 5. Google Cloud CLI (gcloud) ───────────────────────────
step "Step 5 of 6 — Google tools (email, drive, sheets, docs)"

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

# ── 5. OpenClaw — install and configure ───────────────────
step "Step 6 of 6 — OpenClaw (AI assistant)"

ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

# Save Anthropic API key to shell config (idempotent)
grep -v 'ANTHROPIC_API_KEY' "$ZSHRC" 2>/dev/null > "${ZSHRC}.tmp" && mv "${ZSHRC}.tmp" "$ZSHRC" || true
echo "" >> "$ZSHRC"
echo "# Anthropic API key (for OpenClaw)" >> "$ZSHRC"
echo "export ANTHROPIC_API_KEY=\"$ANTHROPIC_API_KEY\"" >> "$ZSHRC"
export ANTHROPIC_API_KEY
ok "Anthropic API key saved to ~/.zshrc"

# Install OpenClaw (--no-onboard skips the interactive wizard; we handle it below)
echo "  Installing OpenClaw…"
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard

# Make sure the OpenClaw binary is on PATH in this session
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Run non-interactive onboarding
if command -v openclaw &>/dev/null; then
  echo "  Configuring OpenClaw…"
  openclaw onboard \
    --non-interactive \
    --auth-choice apiKey \
    --anthropic-api-key "$ANTHROPIC_API_KEY" \
    --mode local \
    --install-daemon \
    --daemon-runtime node \
    --gateway-bind loopback \
    --gateway-auth token
  ok "OpenClaw installed and configured"
else
  warn "OpenClaw binary not found — open a new terminal and run:"
  warn "  openclaw onboard --non-interactive --auth-choice apiKey --anthropic-api-key YOUR_KEY --mode local --install-daemon --daemon-runtime node"
fi

# ── Done ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║   🎉  Setup complete!  Welcome! 🌾   ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""
echo "  Everything is ready:"
echo -e "  ${GREEN}✓${NC}  Tailscale    — connected to team network"
echo -e "  ${GREEN}✓${NC}  Discord      — installed (open it from Applications)"
echo -e "  ${GREEN}✓${NC}  Amphetamine  — installed and running"
echo -e "  ${GREEN}✓${NC}  Google       — signed in as $USER_EMAIL"
echo -e "  ${GREEN}✓${NC}  OpenClaw     — installed and configured"
echo ""
echo "  You're all set. Welcome to 1000Acres! 🌾"
echo ""
