# SearXNG — Claude Code Skill

Instala un motor de búsqueda local (SearXNG) y lo conecta como skill de Claude Code.
Permite buscar en internet directamente desde la terminal con `/searxng tu consulta`.

## Requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop) instalado y corriendo
- [Claude Code](https://claude.ai/code) instalado (`npm install -g @anthropic-ai/claude-code`)
- `python3` y `curl` (vienen por defecto en macOS)

## Instalación (una sola línea)

```bash
curl -fsSL https://raw.githubusercontent.com/TU_USUARIO/searxng-claude-skill/main/install.sh | bash
```

El script instala y configura todo automáticamente:
- Crea `~/Documents/SearchX/` con los scripts y configuración de Docker
- Genera una `secret_key` única para tu instancia
- Crea el skill en `~/.claude/skills/searxng/`
- Arranca SearXNG y hace una búsqueda de prueba

## Uso

En cualquier sesión de Claude Code:

```
/searxng Colombia noticias hoy
/searxng Decreto 134 de 2025 sitio:suin-juriscol.gov.co
/searxng python asyncio tutorial general en week
```

### Parámetros avanzados (desde terminal)

```bash
bash ~/Documents/SearchX/search.sh "query" [categoría] [idioma] [rango_tiempo]

# Ejemplos:
bash ~/Documents/SearchX/search.sh "inteligencia artificial" "news" "es" "week"
bash ~/Documents/SearchX/search.sh "docker tutorial" "it" "en"
```

Categorías disponibles: `general`, `images`, `news`, `science`, `files`, `it`

## Comandos útiles

```bash
# Iniciar SearXNG
bash ~/Documents/SearchX/start.sh

# Detener SearXNG
bash ~/Documents/SearchX/stop.sh

# Verificar que está corriendo
docker ps --filter name=searxng-local
```

## Cómo funciona

SearXNG es un metabuscador open source que agrega resultados de Google, Bing, DuckDuckGo y otros motores, sin rastreo ni publicidad. Corre localmente en Docker en el puerto `8888`.

El skill de Claude Code detecta automáticamente si el contenedor está corriendo y lo inicia si es necesario.
