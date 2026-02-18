# SearXNG — Claude Code Skill

Instala un motor de búsqueda local (SearXNG) y lo conecta como skill de Claude Code.
Permite buscar en internet directamente desde la terminal con `/searxng tu consulta`.

## Requisitos

- macOS con terminal
- `python3` y `curl` (vienen por defecto en macOS)
- Lo demás (Homebrew, Docker/Colima, Claude Code) se instala automáticamente si no está

## Instalación

```bash
curl -fsSL https://raw.githubusercontent.com/angelgalvisc/searxng-claude-skill/main/install.sh -o /tmp/install-searxng.sh && bash /tmp/install-searxng.sh
```

> No usar `curl ... | bash` directo — el script necesita una terminal real para pedir
> la contraseña cuando instala Homebrew o Docker.

El script instala y configura todo automáticamente:
- Detecta si tienes Docker/Colima y lo instala si es necesario
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
