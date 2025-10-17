#!/bin/bash

# 🚀 SCRIPT DE INSTALACIÓN COMPLETA - FLAMENCO FUSION HUB
# Este script instala todo lo necesario y ejecuta la aplicación

echo "🎭 ==============================================="
echo "🎭    FLAMENCO FUSION HUB - INSTALACIÓN COMPLETA"
echo "🎭 ==============================================="
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_step() {
    echo -e "${PURPLE}🔄 $1${NC}"
}

# Verificar que estamos en el directorio correcto
if [ ! -f "package.json" ]; then
    print_error "No se encontró package.json. Asegúrate de estar en el directorio raíz del proyecto."
    exit 1
fi

print_info "Verificando requisitos del sistema..."

# PASO 1: Verificar Docker
print_step "PASO 1: Verificando Docker..."
if ! command -v docker &> /dev/null; then
    print_error "Docker no está instalado."
    OS_NAME="$(uname -s)"
    if [ "$OS_NAME" = "Linux" ]; then
        print_info "En Ubuntu/Debian instala Docker Engine: https://docs.docker.com/engine/install/ubuntu/"
        print_info "Ejemplo: sudo apt update; sudo apt install -y docker.io docker-compose"
    else
        print_info "Por favor instala Docker Desktop desde: https://www.docker.com/products/docker-desktop/"
    fi
    print_info "Después de instalar Docker, reinicia este script."
    exit 1
fi

# Verificar que el daemon de Docker está activo. En servidores Linux sin GUI intentamos arrancarlo automáticamente con systemctl/service.
if ! docker info &> /dev/null; then
    OS_NAME="$(uname -s)"
    if [ "$OS_NAME" = "Linux" ]; then
        print_warning "Docker no está ejecutándose. Intentando iniciar el daemon con systemctl (se requerirá sudo)..."
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl start docker || true
            sleep 2
        else
            sudo service docker start || true
            sleep 2
        fi

        if ! docker info &> /dev/null; then
            print_error "Docker daemon sigue sin ejecutarse."
            print_info "Asegúrate de que Docker Engine esté instalado y habilitado en este servidor."
            print_info "Habilita y arranca el servicio: sudo systemctl enable --now docker"
            print_info "Si no quieres usar sudo en cada comando, añade tu usuario al grupo docker: sudo usermod -aG docker \$USER" 
            print_info "Luego cierra sesión y vuelve a entrar o ejecuta: newgrp docker"
            exit 1
        fi
    else
        print_error "Docker no está ejecutándose."
        print_info "Por favor inicia Docker Desktop y vuelve a ejecutar este script."
        exit 1
    fi
fi
print_status "Docker está instalado y funcionando"

# PASO 2: Verificar Node.js
print_step "PASO 2: Verificando Node.js..."
if ! command -v node &> /dev/null; then
    print_error "Node.js no está instalado."
    print_info "Por favor instala Node.js 18+ desde: https://nodejs.org/"
    exit 1
fi

NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    print_error "Node.js versión $NODE_VERSION detectada. Se requiere versión 18 o superior."
    print_info "Por favor actualiza Node.js desde: https://nodejs.org/"
    exit 1
fi
print_status "Node.js $(node --version) está instalado"

# PASO 3: Instalar Supabase CLI si no está
print_step "PASO 3: Verificando Supabase CLI..."
SUPABASE_CMD=""
print_info "Buscando Supabase CLI local en node_modules/.bin..."
if [ -x "./node_modules/.bin/supabase" ]; then
    SUPABASE_CMD="./node_modules/.bin/supabase"
    print_status "Supabase CLI encontrado en ./node_modules/.bin"
elif command -v supabase &> /dev/null; then
    SUPABASE_CMD="supabase"
    print_status "Supabase CLI global disponible"
else
    print_warning "Supabase CLI no está instalado globalmente ni localmente. Intentando instalar globalmente..."
    npm install -g supabase
    if [ $? -eq 0 ]; then
        SUPABASE_CMD="supabase"
        print_status "Supabase CLI instalado globalmente"
    else
        print_error "Error al instalar Supabase CLI globalmente. Si prefieres instalar localmente ejecuta: npm install supabase y vuelve a ejecutar este script con bash (o usa npx)."
        exit 1
    fi
fi

# PASO 4: Crear archivo .env si no existe
print_step "PASO 4: Configurando variables de entorno..."
if [ ! -f "supabase/functions/.env" ]; then
    print_warning "Archivo .env no encontrado. Creando archivo de configuración..."
    cat > supabase/functions/.env << EOF
# Configuración de APIs externas
# Reemplaza estos valores con tus propias API keys

# WooCommerce API
WOOCOMMERCE_URL=https://tu-tienda.com
WOOCOMMERCE_CONSUMER_KEY=ck_tu_consumer_key
WOOCOMMERCE_CONSUMER_SECRET=cs_tu_consumer_secret

# Holded API
HOLDED_API_KEY=tu_holded_api_key

# Twilio (para SMS/WhatsApp)
TWILIO_ACCOUNT_SID=tu_twilio_sid
TWILIO_AUTH_TOKEN=tu_twilio_token
TWILIO_PHONE_NUMBER=+1234567890

# Email (opcional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=tu_email@gmail.com
SMTP_PASS=tu_password
EOF
    print_status "Archivo .env creado con valores de ejemplo"
    print_warning "IMPORTANTE: Edita supabase/functions/.env con tus API keys reales"
else
    print_status "Archivo .env ya existe"
fi

# PASO 5: Instalar dependencias
print_step "PASO 5: Instalando dependencias de Node.js..."
npm install
if [ $? -eq 0 ]; then
    print_status "Dependencias instaladas"
else
    print_error "Error al instalar dependencias"
    exit 1
fi

# PASO 6: Limpiar y configurar Docker
print_step "PASO 6: Configurando Docker..."
docker stop $(docker ps -q) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
print_status "Docker configurado"

# PASO 7: Iniciar Supabase
print_step "PASO 7: Iniciando Supabase..."
mkdir -p logs
${SUPABASE_CMD} stop 2>/dev/null || true
print_info "Iniciando supabase y registrando salida en logs/supabase-start.log"
${SUPABASE_CMD} start > logs/supabase-start.log 2>&1 &
SUPABASE_START_PID=$!
sleep 5
if ps -p $SUPABASE_START_PID > /dev/null 2>&1; then
    print_status "Supabase (proceso $SUPABASE_START_PID) iniciado (ver logs/supabase-start.log para detalles)"
else
    print_error "Error al iniciar Supabase. Revisa logs/supabase-start.log"
    echo "----- CONTENIDO DE logs/supabase-start.log -----"
    cat logs/supabase-start.log || true
    exit 1
fi

# PASO 8: Iniciar Edge Functions
print_step "PASO 8: Iniciando Edge Functions..."
pkill -f "supabase functions" 2>/dev/null || true
sleep 2
cd supabase/functions
print_info "Iniciando supabase functions y registrando en ../../logs/functions.log"
${SUPABASE_CMD} functions serve --no-verify-jwt --env-file .env > ../../logs/functions.log 2>&1 &
FUNCTIONS_PID=$!
cd ../..
sleep 3
if ps -p $FUNCTIONS_PID > /dev/null 2>&1; then
    print_status "Edge Functions iniciadas (proceso $FUNCTIONS_PID) — ver logs/functions.log para detalles"
else
    print_error "Error iniciando Edge Functions. Revisa logs/functions.log"
    echo "----- CONTENIDO DE logs/functions.log -----"
    cat logs/functions.log || true
    exit 1
fi

# PASO 9: Mostrar información final
echo ""
echo "🎉 ==============================================="
echo "🎉        ¡INSTALACIÓN COMPLETADA!"
echo "🎉 ==============================================="
echo ""
print_info "URLs disponibles:"
echo -e "  🌐 ${CYAN}Aplicación Frontend:${NC} http://localhost:5173"
echo -e "  🗄️  ${CYAN}Supabase Studio:${NC} http://localhost:54323"
echo -e "  🔌 ${CYAN}API REST:${NC} http://localhost:54321"
echo -e "  📧 ${CYAN}Mailpit:${NC} http://localhost:54324"
echo ""
print_info "Credenciales de prueba:"
echo -e "  👤 ${CYAN}Admin:${NC} admin@flamenca.com / admin123"
echo ""
print_info "Para iniciar la aplicación frontend:"
echo -e "  ${YELLOW}npm run dev${NC}"
echo ""
print_info "Para parar todos los servicios:"
echo -e "  ${YELLOW}./stop-app.sh${NC}"
echo ""
print_warning "IMPORTANTE: Si quieres usar APIs externas (WooCommerce, Holded, etc.),"
print_warning "edita el archivo supabase/functions/.env con tus API keys reales."
echo ""
print_status "¡Instalación completada! Ejecuta 'npm run dev' para iniciar la aplicación."
