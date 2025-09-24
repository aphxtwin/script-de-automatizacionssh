#!/bin/bash
set -euo pipefail

# === Load environment variables from .env ===
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "❌ No .env file found."
  exit 1
fi

# === Variables ===
KEY_PATH="$HOME/.ssh/${SSH_KEY_NAME:-github}"
EMAIL="${GITHUB_EMAIL:-you@example.com}"
TOKEN="${GITHUB_TOKEN:-}"
USER="${GITHUB_USER:-}"

if [ -z "$TOKEN" ]; then
  echo "❌ GITHUB_TOKEN not found in .env"
  exit 1
fi

# === Step 1: Generate SSH key (if it doesn't exist) ===
if [ ! -f "$KEY_PATH" ]; then
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH" -N "" -q
  echo "✅ SSH key generated: $KEY_PATH"
else
  echo "ℹ️ SSH key already exists: $KEY_PATH"
fi

# === Step 2: Read public key ===
PUB_KEY=$(cat "${KEY_PATH}.pub")

# === Step 3: Upload to GitHub via API ===
echo "📤 Uploading public key to GitHub..."
RESPONSE=$(curl -s -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"$(hostname)-$(date +%Y%m%d)\",\"key\":\"$PUB_KEY\"}" \
  https://api.github.com/user/keys)

if echo "$RESPONSE" | grep -q '"id":'; then
  echo "🎉 Key uploaded successfully to GitHub."
else
  echo "❌ Upload failed. Response:"
  echo "$RESPONSE"
  exit 1
fi

# === Step 4: Update ssh config ===
mkdir -p ~/.ssh
chmod 700 ~/.ssh
if ! grep -q "Host github.com" ~/.ssh/config 2>/dev/null; then
  cat >> ~/.ssh/config <<EOF

Host github.com
  HostName github.com
  User git
  IdentityFile $KEY_PATH
EOF
  chmod 600 ~/.ssh/config
  echo "⚙️ Added github.com entry to ~/.ssh/config"
else
  echo "ℹ️ ~/.ssh/config already has a github.com entry"
fi

# === Step 5: Test GitHub connection ===
echo "🔑 Testing SSH connection..."
ssh -T git@github.com || true