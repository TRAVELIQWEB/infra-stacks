#!/usr/bin/env bash
set -e

APP_NAME="wallet-frontend"
ENVIRONMENT="dev"
IMAGE="ghcr.io/TRAVELIQWEB/${APP_NAME}:${ENVIRONMENT}"

echo "🚀 Deploying ${APP_NAME} (${ENVIRONMENT})..."

cd "$(dirname "$0")"

echo "📥 Pulling latest image: $IMAGE"
docker pull "$IMAGE"

echo "🧹 Stopping old containers..."
docker compose down --remove-orphans

echo "📦 Starting new containers..."
docker compose up -d

echo "✅ Deployment completed for ${APP_NAME} (${ENVIRONMENT})"
echo "📋 Running containers:"
docker ps --filter "name=${APP_NAME}" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
