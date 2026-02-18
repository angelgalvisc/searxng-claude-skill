#!/usr/bin/env bash
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  [ok]${NC} $1"; }
warn() { echo -e "${YELLOW}  [!]${NC}  $1"; }
fail() { echo -e "${RED}  [x]${NC}  $1"; exit 1; }
info() { echo -e "      $1"; }

echo ""
echo -e "${BOLD}SearXNG — Claude Code Skill Installer${NC}"
echo "────────────────────────────────────────"
echo ""

# ─── Prerequisites ────────────────────────────────────────────────────────────
echo -e "${BOLD}Checking prerequisites...${NC}"

command -v docker  &>/dev/null || fail "Docker not found. Install Docker Desktop first: https://www.docker.com/products/docker-desktop"
command -v python3 &>/dev/null || fail "python3 not found. Install it with: brew install python3"
command -v curl    &>/dev/null || fail "curl not found."
command -v claude  &>/dev/null || fail "Claude Code not found. Install it with: npm install -g @anthropic-ai/claude-code"

ok "docker, python3, curl, claude — all found"

docker info &>/dev/null || fail "Docker is not running. Please open Docker Desktop and try again."
ok "Docker is running"

echo ""

# ─── Directories ──────────────────────────────────────────────────────────────
SEARCHX="$HOME/Documents/SearchX"
SKILL="$HOME/.claude/skills/searxng"

mkdir -p "$SEARCHX/searxng"
mkdir -p "$SKILL"
ok "Directories ready"

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
ok "docker-compose.yml created"

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
ok "searxng/settings.yml created (unique secret key generated)"

# ─── start.sh ─────────────────────────────────────────────────────────────────
cat > "$SEARCHX/start.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if docker ps --format '{{.Names}}' | grep -q '^searxng-local$'; then
  echo "SearXNG is already running."
else
  echo "Starting SearXNG..."
  docker compose up -d
  echo "Waiting for SearXNG to be ready..."
  for i in $(seq 1 15); do
    if curl -sf http://localhost:8888/healthz > /dev/null 2>&1; then
      echo "SearXNG is ready."
      exit 0
    fi
    sleep 1
  done
  echo "SearXNG started (health check timed out, but container is running)."
fi
EOF

# ─── stop.sh ──────────────────────────────────────────────────────────────────
cat > "$SEARCHX/stop.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "Stopping SearXNG..."
docker compose down
echo "Done."
EOF

# ─── search.sh ────────────────────────────────────────────────────────────────
cat > "$SEARCHX/search.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ] || [ -z "$1" ]; then
  echo "Usage: search.sh <query> [categories] [language] [time_range] [pageno]"
  echo ""
  echo "  categories  - general, images, news, science, files, it  (default: general)"
  echo "  language    - en, es, de, fr ...                          (default: auto)"
  echo "  time_range  - day, week, month, year                      (default: none)"
  echo "  pageno      - page number                                  (default: 1)"
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
  echo "Error: Could not connect to SearXNG at localhost:8888"
  echo "Run ~/Documents/SearchX/start.sh to start the container."
  exit 1
}

echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
if not results:
    print('No results found.')
    sys.exit(0)
print(f'Found {len(results)} results:\n')
for i, r in enumerate(results[:20], 1):
    print(f'{i}. {r.get(\"title\", \"No title\")}')
    print(f'   URL: {r.get(\"url\", \"\")}')
    if r.get('content'):
        print(f'   {r[\"content\"]}')
    if r.get('engines'):
        print(f'   [engines: {', '.join(r[\"engines\"])}]')
    print()
"
EOF

chmod +x "$SEARCHX/start.sh" "$SEARCHX/stop.sh" "$SEARCHX/search.sh"
ok "Scripts created and made executable"

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
ok "Claude skill created at ~/.claude/skills/searxng/SKILL.md"

# ─── Quick test ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Starting SearXNG for the first time...${NC}"
info "(This may take a minute to download the Docker image)"
bash "$SEARCHX/start.sh"

echo ""
echo -e "${BOLD}Running a quick test search...${NC}"
bash "$SEARCHX/search.sh" "test" "general" "" "" 1 | head -10

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────"
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo "  Usage in Claude Code:"
echo -e "  ${BOLD}/searxng tu busqueda aqui${NC}"
echo ""
echo "  Other commands:"
echo "    Start:  bash ~/Documents/SearchX/start.sh"
echo "    Stop:   bash ~/Documents/SearchX/stop.sh"
echo "    Search: bash ~/Documents/SearchX/search.sh \"query\" [category] [lang] [time]"
echo ""
