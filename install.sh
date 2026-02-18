#!/usr/bin/env bash
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  [ok]${NC} $1"; }
warn() { echo -e "${YELLOW}  [!]${NC}  $1"; }
fail() { echo -e "${RED}  [x]${NC}  $1"; exit 1; }
info() { echo -e "      $1"; }
step() { echo -e "\n${BOLD}$1${NC}"; }

echo ""
echo -e "${BOLD}SearXNG — Claude Code Skill Installer${NC}"
echo "────────────────────────────────────────"

# ─── Helpers ──────────────────────────────────────────────────────────────────
install_homebrew() {
  warn "Homebrew no encontrado. Instalando..."

  # curl | bash pipes stdin, so there's no TTY — Homebrew can't ask for password
  if [ ! -t 0 ]; then
    echo ""
    fail "No se puede instalar Homebrew en modo no-interactivo (curl | bash).
      Corre esto en tu terminal y vuelve a intentarlo:

      curl -fsSL https://raw.githubusercontent.com/angelgalvisc/searxng-claude-skill/main/install.sh -o /tmp/install-searxng.sh && bash /tmp/install-searxng.sh"
  fi

  info "Se pedirá tu contraseña de administrador una vez."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for the rest of this script
  if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -f "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  # Persist brew in PATH for future terminal sessions
  local profile="$HOME/.zprofile"
  if ! grep -q "brew shellenv" "$profile" 2>/dev/null; then
    echo '' >> "$profile"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$profile"
    ok "Homebrew agregado al PATH permanentemente ($profile)"
  fi
  ok "Homebrew instalado"
}

install_colima() {
  warn "Docker no encontrado. Instalando Colima (runtime ligero de Docker)..."
  brew install colima docker docker-compose
  ok "Colima y Docker CLI instalados"

  info "Iniciando Colima por primera vez (descarga ~700 MB, solo la primera vez)..."
  colima start --cpu 2 --memory 2
  ok "Colima corriendo"

  # Make docker-compose work as a plugin
  mkdir -p ~/.docker/cli-plugins
  ln -sfn "$(brew --prefix)/opt/docker-compose/bin/docker-compose" \
    ~/.docker/cli-plugins/docker-compose 2>/dev/null || true
}

ensure_docker() {
  step "Verificando Docker..."

  if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    ok "Docker ya está disponible y corriendo"
    return
  fi

  # Docker command exists but daemon isn't running (Docker Desktop instalado pero cerrado)
  if command -v docker &>/dev/null; then
    warn "Docker está instalado pero no está corriendo."

    # Try to start Docker Desktop if it exists
    if [[ -d "/Applications/Docker.app" ]]; then
      info "Abriendo Docker Desktop..."
      open -a Docker
      info "Esperando que Docker arranque (hasta 60 seg)..."
      for i in $(seq 1 60); do
        if docker info &>/dev/null 2>&1; then
          ok "Docker Desktop listo"
          return
        fi
        sleep 1
      done
      fail "Docker Desktop no arrancó a tiempo. Ábrelo manualmente y vuelve a correr este script."
    fi

    # Try to start Colima if installed
    if command -v colima &>/dev/null; then
      info "Iniciando Colima..."
      colima start
      ok "Colima corriendo"
      return
    fi
  fi

  # Nothing available — install via Homebrew
  warn "Docker no está instalado."

  if ! command -v brew &>/dev/null; then
    install_homebrew
  fi

  install_colima
}

# ─── Prerequisites ────────────────────────────────────────────────────────────
step "Verificando prerequisitos..."

command -v python3 &>/dev/null || fail "python3 no encontrado. Instálalo con: brew install python3"
command -v curl    &>/dev/null || fail "curl no encontrado."
ok "python3 y curl disponibles"

command -v claude &>/dev/null || {
  warn "Claude Code no encontrado."
  info "Instalando Claude Code..."
  if command -v npm &>/dev/null; then
    npm install -g @anthropic-ai/claude-code
    ok "Claude Code instalado"
  else
    fail "npm no encontrado. Instala Node.js primero: https://nodejs.org"
  fi
}
ok "Claude Code disponible"

ensure_docker

# ─── Directories ──────────────────────────────────────────────────────────────
step "Creando estructura de archivos..."

SEARCHX="$HOME/Documents/SearchX"
SKILL="$HOME/.claude/skills/searxng"

mkdir -p "$SEARCHX/searxng"
mkdir -p "$SKILL"
ok "Directorios listos"

# ─── Generate secret key ──────────────────────────────────────────────────────
SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")

# ─── docker-compose.yml ───────────────────────────────────────────────────────
cat > "$SEARCHX/docker-compose.yml" <<'EOF'
services:
  searxng:
    image: searxng/searxng:latest
    container_name: searxng-local
    ports:
      - "8888:8080"
    volumes:
      - ./searxng:/etc/searxng:rw
      - searxng-data:/var/cache/searxng
    environment:
      - SEARXNG_BASE_URL=http://localhost:8888/
    restart: unless-stopped

volumes:
  searxng-data:
EOF
ok "docker-compose.yml creado"

# ─── settings.yml ─────────────────────────────────────────────────────────────
cat > "$SEARCHX/searxng/settings.yml" <<EOF
use_default_settings: true

server:
  secret_key: "$SECRET"
  limiter: false
  image_proxy: false
  bind_address: "0.0.0.0"
  port: 8080

search:
  formats:
    - html
    - json
EOF
ok "searxng/settings.yml creado (secret key única generada)"

# ─── start.sh ─────────────────────────────────────────────────────────────────
cat > "$SEARCHX/start.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Ensure Homebrew is in PATH (needed for colima and docker when installed via brew)
if [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# If using Colima, make sure it's running
if command -v colima &>/dev/null && ! colima status &>/dev/null 2>&1; then
  echo "Iniciando Colima..."
  colima start
fi

if docker ps --format '{{.Names}}' | grep -q '^searxng-local$'; then
  echo "SearXNG ya está corriendo."
else
  echo "Iniciando SearXNG..."
  docker compose up -d
  echo "Esperando que SearXNG esté listo..."
  for i in $(seq 1 20); do
    if curl -sf http://localhost:8888/healthz > /dev/null 2>&1; then
      echo "SearXNG listo."
      exit 0
    fi
    sleep 1
  done
  echo "SearXNG iniciado (el contenedor está corriendo)."
fi
EOF

# ─── stop.sh ──────────────────────────────────────────────────────────────────
cat > "$SEARCHX/stop.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "Deteniendo SearXNG..."
docker compose down
echo "Listo."
EOF

# ─── search.sh ────────────────────────────────────────────────────────────────
cat > "$SEARCHX/search.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Ensure Homebrew is in PATH
if [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if [ $# -eq 0 ] || [ -z "$1" ]; then
  echo "Uso: search.sh <consulta> [categoría] [idioma] [rango_tiempo] [página]"
  echo ""
  echo "  categoría   - general, images, news, science, files, it  (default: general)"
  echo "  idioma      - en, es, de, fr ...                          (default: auto)"
  echo "  rango_tiempo- day, week, month, year                      (default: ninguno)"
  echo "  página      - número de página                            (default: 1)"
  exit 1
fi

QUERY="$1"
CATEGORIES="${2:-general}"
LANGUAGE="${3:-}"
TIME_RANGE="${4:-}"
PAGENO="${5:-1}"

BASE_URL="http://localhost:8888/search"
PARAMS="q=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")&format=json&categories=${CATEGORIES}&pageno=${PAGENO}"
[ -n "$LANGUAGE" ]   && PARAMS="${PARAMS}&language=${LANGUAGE}"
[ -n "$TIME_RANGE" ] && PARAMS="${PARAMS}&time_range=${TIME_RANGE}"

RESPONSE=$(curl -sf "${BASE_URL}?${PARAMS}" 2>&1) || {
  echo "Error: No se pudo conectar a SearXNG en localhost:8888"
  echo "Corre ~/Documents/SearchX/start.sh para iniciar el contenedor."
  exit 1
}

echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
if not results:
    print('Sin resultados.')
    sys.exit(0)
print(f'Se encontraron {len(results)} resultados:\n')
for i, r in enumerate(results[:20], 1):
    print(f'{i}. {r.get(\"title\", \"Sin título\")}')
    print(f'   URL: {r.get(\"url\", \"\")}')
    if r.get('content'):
        print(f'   {r[\"content\"]}')
    if r.get('engines'):
        engines = ', '.join(r['engines'])
        print(f'   [motores: {engines}]')
    print()
"
EOF

chmod +x "$SEARCHX/start.sh" "$SEARCHX/stop.sh" "$SEARCHX/search.sh"
ok "Scripts creados y marcados como ejecutables"

# ─── Claude skill: SKILL.md ───────────────────────────────────────────────────
cat > "$SKILL/SKILL.md" <<'EOF'
---
name: searxng
description: Search the web using local SearXNG metasearch engine. Useful when WebSearch/WebFetch fail due to SSL issues, CAPTCHAs, or limited indexing.
argument-hint: <search query>
allowed-tools: Bash, Read, WebFetch
---

The user wants to search for: $ARGUMENTS

Follow these steps:

1. **Check if SearXNG is running:**
   ```
   docker ps --filter name=searxng-local --format '{{.Status}}'
   ```

2. **If not running, start it:**
   ```
   bash ~/Documents/SearchX/start.sh
   ```

3. **Execute the search** using the search script:
   ```
   bash ~/Documents/SearchX/search.sh "$ARGUMENTS"
   ```

   For more specific searches, you can pass extra parameters:
   - `bash ~/Documents/SearchX/search.sh "query" "categories"` (general, images, news, science, files, it)
   - `bash ~/Documents/SearchX/search.sh "query" "general" "es"` (language filter)
   - `bash ~/Documents/SearchX/search.sh "query" "general" "" "week"` (time range: day, week, month, year)

4. **Present the results** to the user in a clean, readable format. Highlight the most relevant results.

5. **If the user wants to read a specific result**, use `WebFetch` on the URL. If WebFetch fails, fall back to:
   ```
   curl -sL -k "URL" | python3 -c "
   import sys
   from html.parser import HTMLParser
   class T(HTMLParser):
       def __init__(self):
           super().__init__()
           self.text = []
           self.skip = False
       def handle_starttag(self, tag, attrs):
           if tag in ('script', 'style', 'nav', 'footer', 'header'):
               self.skip = True
       def handle_endtag(self, tag):
           if tag in ('script', 'style', 'nav', 'footer', 'header'):
               self.skip = False
       def handle_data(self, data):
           if not self.skip:
               self.text.append(data.strip())
   t = T()
   t.feed(sys.stdin.read())
   print('\n'.join(line for line in t.text if line)[:8000])
   "
   ```
EOF
ok "Claude skill creado en ~/.claude/skills/searxng/SKILL.md"

# ─── Start SearXNG ────────────────────────────────────────────────────────────
step "Iniciando SearXNG por primera vez..."
info "(La primera vez descarga la imagen Docker, puede tardar 1-2 minutos)"
bash "$SEARCHX/start.sh"

step "Haciendo búsqueda de prueba..."
bash "$SEARCHX/search.sh" "test" "general" "" "" 1 | head -10

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────"
echo -e "${GREEN}${BOLD}Instalacion completa!${NC}"
echo ""
echo "  Uso en Claude Code:"
echo -e "  ${BOLD}/searxng tu busqueda aqui${NC}"
echo ""
echo "  Comandos utiles:"
echo "    Iniciar:  bash ~/Documents/SearchX/start.sh"
echo "    Detener:  bash ~/Documents/SearchX/stop.sh"
echo "    Buscar:   bash ~/Documents/SearchX/search.sh \"consulta\" [categoria] [idioma] [tiempo]"
echo ""
