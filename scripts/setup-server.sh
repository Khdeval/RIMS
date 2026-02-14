#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  RIMS Production Server Setup Script
#  Run this ONCE on a fresh Ubuntu/Debian VPS
# ═══════════════════════════════════════════════════════════
set -euo pipefail

APP_DIR="/opt/rims"
REPO="https://github.com/Khdeval/RIMS.git"

echo "╔══════════════════════════════════════╗"
echo "║  RIMS Server Setup                   ║"
echo "╚══════════════════════════════════════╝"

# ── 1. Install Docker ──────────────────────────────────────
if ! command -v docker &>/dev/null; then
  echo "→ Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  echo "  ✅ Docker installed"
else
  echo "  ✅ Docker already installed"
fi

# ── 2. Install Docker Compose plugin ──────────────────────
if ! docker compose version &>/dev/null; then
  echo "→ Installing Docker Compose..."
  sudo apt-get update -qq
  sudo apt-get install -y docker-compose-plugin
  echo "  ✅ Docker Compose installed"
else
  echo "  ✅ Docker Compose already installed"
fi

# ── 3. Clone or update repo ──────────────────────────────
if [ ! -d "$APP_DIR" ]; then
  echo "→ Cloning RIMS repo..."
  sudo mkdir -p "$APP_DIR"
  sudo chown "$USER:$USER" "$APP_DIR"
  git clone "$REPO" "$APP_DIR"
else
  echo "→ Updating RIMS repo..."
  cd "$APP_DIR" && git pull origin main
fi

cd "$APP_DIR"

# ── 4. Create .env file if missing ───────────────────────
if [ ! -f .env ]; then
  echo "→ Creating .env from .env.example..."
  cp .env.example .env
  sed -i 's/NODE_ENV="development"/NODE_ENV="production"/' .env
  echo "  ⚠️  Edit .env with your production settings: nano $APP_DIR/.env"
fi

# ── 5. Start services ───────────────────────────────────
echo ""
echo "→ Starting RIMS in production mode..."
docker compose -f docker-compose.prod.yml up -d --pull always

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  ✅ RIMS is running!                 ║"
echo "║                                      ║"
echo "║  Dashboard:  http://YOUR_IP          ║"
echo "║  API:        http://YOUR_IP:3000     ║"
echo "║  Health:     http://YOUR_IP:3000/health ║"
echo "║                                      ║"
echo "║  Logs:  docker compose -f            ║"
echo "║    docker-compose.prod.yml logs -f   ║"
echo "╚══════════════════════════════════════╝"
