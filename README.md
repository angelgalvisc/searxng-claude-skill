# SearXNG — Claude Code Skill

Motor de búsqueda local ([SearXNG](https://github.com/searxng/searxng)) conectado como skill de [Claude Code](https://docs.anthropic.com/en/docs/claude-code).
Busca en internet directamente desde la terminal con `/searxng tu consulta`.

SearXNG agrega resultados de Google, Bing, DuckDuckGo y otros motores sin rastreo ni publicidad.

## Compatibilidad

- macOS Apple Silicon (M1/M2/M3/M4) y macOS Intel
- `python3` y `curl` (vienen por defecto en macOS)
- Todo lo demás se instala automáticamente si no está (Homebrew, Docker/Colima, Claude Code)

## Instalación

```bash
curl -fsSL https://raw.githubusercontent.com/angelgalvisc/searxng-claude-skill/main/install.sh -o /tmp/install-searxng.sh && bash /tmp/install-searxng.sh
```

> **Importante:** No usar `curl ... | bash` — el script necesita una terminal interactiva para pedir la contraseña si instala Homebrew.

### Qué instala

El script detecta qué tienes y solo instala lo que falta:

| Componente | Se instala si falta | Método |
|---|---|---|
| Homebrew | Sí | Installer oficial de Homebrew |
| Docker runtime | Sí | [Colima](https://github.com/abiosoft/colima) via Homebrew (ligero, sin GUI) |
| Docker CLI + Compose | Sí | Homebrew |
| Claude Code | Sí | npm |
| SearXNG | Siempre | Imagen Docker (`searxng/searxng:latest`) |

Archivos creados:
- `~/Documents/SearchX/` — scripts y configuración de Docker
- `~/.claude/skills/searxng/` — skill de Claude Code

## Uso

En cualquier sesión de Claude Code:

```
/searxng Decreto 134 de 2025 Colombia
/searxng noticias inteligencia artificial hoy
/searxng React Server Components tutorial
```

Claude interpreta tu consulta, ejecuta la búsqueda y presenta los resultados. Si quieres leer una página específica de los resultados, solo pídelo.

### Uso directo desde terminal

```bash
bash ~/Documents/SearchX/search.sh "consulta" [categoría] [idioma] [rango_tiempo]
```

| Parámetro | Valores | Default |
|---|---|---|
| categoría | `general`, `images`, `news`, `science`, `files`, `it` | `general` |
| idioma | `es`, `en`, `de`, `fr`, etc. | auto |
| rango_tiempo | `day`, `week`, `month`, `year` | sin límite |

Ejemplos:

```bash
bash ~/Documents/SearchX/search.sh "inteligencia artificial" "news" "es" "week"
bash ~/Documents/SearchX/search.sh "docker tutorial" "it" "en"
```

## Comandos útiles

```bash
# Iniciar SearXNG (también inicia Colima si es necesario)
bash ~/Documents/SearchX/start.sh

# Detener SearXNG
bash ~/Documents/SearchX/stop.sh
```

## Troubleshooting

**`docker: command not found` al usar el skill**
Cierra y abre la terminal para que cargue el PATH de Homebrew, o corre:
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

**SearXNG no responde**
```bash
bash ~/Documents/SearchX/start.sh
```
El script inicia Colima y SearXNG automáticamente.

**Re-instalar sin perder configuración**
Corre el mismo comando de instalación. El script conserva tu `secret_key` existente y sobreescribe solo los scripts.

## Desinstalar

```bash
# Detener y eliminar el contenedor
bash ~/Documents/SearchX/stop.sh
docker rmi searxng/searxng:latest

# Eliminar archivos
rm -rf ~/Documents/SearchX
rm -rf ~/.claude/skills/searxng
```

## Licencia

Este installer es de uso libre. SearXNG tiene licencia [AGPL-3.0](https://github.com/searxng/searxng/blob/master/LICENSE).
