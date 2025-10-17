#!/usr/bin/env bash
set -euo pipefail

# install-and-run-ubuntu.sh
# Headless-friendly installer for Ubuntu servers (no GUI)
# Usage:
#   ./install-and-run-ubuntu.sh         # interactive: prints instructions when admin rights needed
#   sudo ./install-and-run-ubuntu.sh --auto  # will attempt to install required packages (docker, docker-compose, npm) automatically

AUTO_INSTALL="no"
if [ "${1-}" = "--auto" ] || [ "${AUTO-}" = "yes" ]; then
  AUTO_INSTALL="yes"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status(){ echo -e "${GREEN}✅ $1${NC}"; }
print_warning(){ echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error(){ echo -e "${RED}❌ $1${NC}"; }
print_info(){ echo -e "${BLUE}ℹ️  $1${NC}"; }
print_step(){ echo -e "${PURPLE}🔄 $1${NC}"; }

# Ensure running on Linux
if [ "$(uname -s)" != "Linux" ]; then
  print_error "Este script está pensado para Ubuntu/Debian (Linux)."
  exit 1
fi

print_step "Comprobando Docker..."
if ! command -v docker >/dev/null 2>&1; then
  print_warning "Docker no está instalado."
  if [ "$AUTO_INSTALL" = "yes" ]; then
    print_info "Instalando Docker (modo automático)..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y --no-install-recommends ca-certificates curl gnupg lsb-release
    # Install docker.io as a safe default
    apt-get install -y --no-install-recommends docker.io docker-compose
    systemctl enable --now docker || true
    print_status "Docker instalado y arrancado (intenta ejecutar sin sudo si añadiste al grupo docker)."
  else
    print_info "Instálalo con: sudo apt update && sudo apt install -y docker.io docker-compose"
    print_info "Habilita y arranca el servicio: sudo systemctl enable --now docker"
    print_info "Para permitir usar Docker sin sudo: sudo usermod -aG docker $USER (cierra sesión y vuelve a entrar)"
    exit 1
  fi
fi

# Ensure docker daemon running
if ! docker info >/dev/null 2>&1; then
  print_warning "El daemon de Docker no está corriendo. Intentando arrancarlo..."
  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl start docker || true
  else
    sudo service docker start || true
  fi
  sleep 2
  if ! docker info >/dev/null 2>&1; then
    print_error "No se pudo arrancar Docker. Habilítalo manualmente: sudo systemctl enable --now docker"
    exit 1
  fi
fi
print_status "Docker listo"

# Node.js check
print_step "Comprobando Node.js y npm..."
if ! command -v node >/dev/null 2>&1; then
  print_warning "Node.js no encontrado."
  if [ "$AUTO_INSTALL" = "yes" ]; then
    print_info "Instalando Node.js (lts)..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    print_status "Node.js instalado"
  else
    print_info "Instálalo siguiendo: https://nodejs.org/ (se recomienda Node 18+)"
    exit 1
  fi
fi
print_status "Node.js $(node --version) disponible"

# Supabase CLI check
print_step "Comprobando Supabase CLI..."
if ! command -v supabase >/dev/null 2>&1; then
  print_warning "Supabase CLI no está instalado. Intentando instalar con npm..."
  if [ "$AUTO_INSTALL" = "yes" ]; then
    npm install -g supabase
    print_status "Supabase CLI instalado"
  else
    print_info "Instálalo con: npm install -g supabase"
    exit 1
  fi
else
  print_status "Supabase CLI encontrado"
fi

# Ensure in project root (package.json exists)
if [ ! -f "package.json" ]; then
  print_error "No se encontró package.json. Ejecuta este script desde la raíz del proyecto."
  exit 1
fi

mkdir -p logs

print_step "Instalando dependencias Node.js..."
npm install
print_status "Dependencias instaladas"

print_step "Limpiando contenedores Docker antiguos (si existen)..."
docker stop $(docker ps -q) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
print_status "Contenedores limpiados"

print_step "Iniciando Supabase local (logs en logs/supabase-start.log)..."
supabase stop 2>/dev/null || true
supabase start > logs/supabase-start.log 2>&1 &
SUPABASE_START_PID=$!
sleep 5
if ps -p $SUPABASE_START_PID >/dev/null 2>&1; then
  print_status "Supabase arrancado (PID $SUPABASE_START_PID). Revisa logs/supabase-start.log"
else
  print_error "Error al arrancar Supabase; revisa logs/supabase-start.log"
  tail -n 200 logs/supabase-start.log || true
  exit 1
fi

print_step "Iniciando Edge Functions (logs en logs/functions.log)..."
cd supabase/functions || { print_error "No existe supabase/functions"; exit 1; }
supabase functions serve --no-verify-jwt --env-file .env > ../../logs/functions.log 2>&1 &
FUNCTIONS_PID=$!
cd - >/dev/null
sleep 3
if ps -p $FUNCTIONS_PID >/dev/null 2>&1; then
  print_status "Edge Functions iniciadas (PID $FUNCTIONS_PID)"
else
  print_error "Error iniciando Edge Functions. Revisa logs/functions.log"
  tail -n 200 logs/functions.log || true
  exit 1
fi

print_status "Instalación y arranque completados."
print_info "URLs: Frontend http://localhost:5173 | Supabase Studio http://localhost:54323 | API http://localhost:54321"

echo
print_info "Si ejecutaste con --auto y añadiste el usuario al grupo docker, cierra sesión y vuelve a entrar para aplicar los permisos sin sudo."
