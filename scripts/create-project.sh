#!/bin/bash
# Blueprint Flow - Project Creator
# Creates a new Laravel project with full setup including blueprint-flow
#
# Usage: ./.blueprint-flow/scripts/create-project.sh <project-name>
#    OR: Run from anywhere: /path/to/create-project.sh <project-name>
#
# Example: ./create-project.sh my-todo-app

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
PROJECT_BASE="/Users/a_t/project"
VALET_DOMAIN="pizza"
STACK="tall-daisy"
BLUEPRINT_REPO="https://github.com/tatun55/blueprint-flow"

# Check arguments
if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <project-name>"
    echo "Example: $0 my-todo-app"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_PATH="$PROJECT_BASE/$PROJECT_NAME"

# Check if project already exists
if [[ -d "$PROJECT_PATH" ]]; then
    log_error "Project already exists: $PROJECT_PATH"
    exit 1
fi

log_info "Creating project: $PROJECT_NAME"
log_info "Path: $PROJECT_PATH"
echo ""

# ============================================
# Step 1: Create Laravel Project
# ============================================
log_info "Step 1: Creating Laravel project..."
cd "$PROJECT_BASE"
composer create-project laravel/laravel "$PROJECT_NAME" --quiet
cd "$PROJECT_PATH"
log_success "Laravel project created"

# ============================================
# Step 2: Install Dependencies
# ============================================
log_info "Step 2: Installing dependencies..."

# Livewire
composer require livewire/livewire --quiet
log_success "Livewire installed"

# NPM dependencies + Tailwind + daisyUI
npm install --silent
npm install -D tailwindcss postcss autoprefixer daisyui --silent
npx tailwindcss init -p
log_success "Tailwind + daisyUI installed"

# ============================================
# Step 3: Configure Environment
# ============================================
log_info "Step 3: Configuring environment..."

# Get MySQL password from ~/.my.cnf
DB_PASS=""
if [[ -f ~/.my.cnf ]]; then
    DB_PASS=$(awk -F= '/^password/ {gsub(/"/,"",$2); print $2}' ~/.my.cnf | tr -d ' ' || echo "")
fi

# Update .env
cp .env.example .env
sed -i '' "s|^APP_URL=.*|APP_URL=http://${PROJECT_NAME}.${VALET_DOMAIN}|" .env
sed -i '' "s|^DB_CONNECTION=.*|DB_CONNECTION=mysql|" .env
sed -i '' "s|^# DB_HOST=.*|DB_HOST=127.0.0.1|" .env
sed -i '' "s|^# DB_PORT=.*|DB_PORT=3306|" .env
sed -i '' "s|^# DB_DATABASE=.*|DB_DATABASE=${PROJECT_NAME}|" .env
sed -i '' "s|^# DB_USERNAME=.*|DB_USERNAME=root|" .env
sed -i '' "s|^# DB_PASSWORD=.*|DB_PASSWORD='${DB_PASS}'|" .env

# Create database
mysql -e "CREATE DATABASE IF NOT EXISTS \`${PROJECT_NAME}\`;"
log_success "Database created: ${PROJECT_NAME}"

# Generate app key
php artisan key:generate --quiet
log_success "App key generated"

# Run migrations
php artisan migrate --quiet
log_success "Migrations completed"

# ============================================
# Step 4: Configure Tailwind
# ============================================
log_info "Step 4: Configuring Tailwind..."

cat > tailwind.config.js << 'EOF'
import daisyui from 'daisyui'

/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./resources/**/*.blade.php",
    "./resources/**/*.js",
    "./app/Livewire/**/*.php",
  ],
  theme: {
    extend: {},
  },
  plugins: [daisyui],
  daisyui: {
    themes: ["light", "dark"],
  },
}
EOF

# Update resources/css/app.css
cat > resources/css/app.css << 'EOF'
@import "tailwindcss";
EOF

log_success "Tailwind configured"

# ============================================
# Step 5: Initialize Git
# ============================================
log_info "Step 5: Initializing Git..."

git init --quiet
git add -A
git commit -m "Initial commit: Laravel 12 + Livewire 4 + Tailwind 4 + daisyUI 5" --quiet
log_success "Git initialized"

# ============================================
# Step 6: Create GitHub Repository
# ============================================
log_info "Step 6: Creating GitHub repository..."

if command -v gh &> /dev/null; then
    gh repo create "$PROJECT_NAME" --private --source=. --push
    log_success "GitHub private repo created and pushed"
else
    log_warn "gh CLI not found. Skipping GitHub repo creation."
    log_warn "Run manually: gh repo create $PROJECT_NAME --private --source=. --push"
fi

# ============================================
# Step 7: Add Blueprint Flow
# ============================================
log_info "Step 7: Adding blueprint-flow..."

git submodule add "$BLUEPRINT_REPO" .blueprint-flow
log_success "blueprint-flow submodule added"

# Initialize with stack
./.blueprint-flow/scripts/init.sh "$STACK"
log_success "blueprint-flow initialized with $STACK stack"

# Initialize blueprint database
./scripts/blueprint-db-cli.sh init
log_success "Blueprint database initialized"

# Commit blueprint-flow setup
git add -A
git commit -m "Add blueprint-flow with $STACK stack" --quiet
git push --quiet 2>/dev/null || true
log_success "Blueprint setup committed"

# ============================================
# Complete!
# ============================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  Project: ${BLUE}$PROJECT_NAME${NC}"
echo -e "  Path:    ${BLUE}$PROJECT_PATH${NC}"
echo -e "  URL:     ${BLUE}http://${PROJECT_NAME}.${VALET_DOMAIN}${NC}"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "  1. cd $PROJECT_PATH"
echo -e "  2. npm run dev      # Start Vite"
echo -e "  3. /blueprint       # Create specs"
echo -e "  4. /hub             # Process specs"
echo ""
