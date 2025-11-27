#!/usr/bin/env bash
set -e

echo "🚀 Deploying Wallet Frontend (DEV)..."

# Navigate to compose folder
cd "$(dirname "$0")"

# Pull latest dev image from GHCR
docker pull ghcr.io/TRAVELIQWEB/wallet-frontend:dev

# Run compose
docker compose down
docker compose up -d

echo "✅ Deployment completed for Wallet Frontend (DEV)"
docker ps | grep wallet-frontend
