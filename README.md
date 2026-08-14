# OpenVist

Captura de pantalla remota + análisis con IA local para Wayland/Hyprland.

**Caso de uso real:** Poder ver el escritorio de mi PC desde fuera de casa mientras codeo. Uso OpenCode vía Discord (remote-opencode bot), le pido que ejecute `opencode-see`, y el bot me envía la descripción + la imagen de la pantalla directamente al chat de Discord. Sin servicios cloud, sin enviar datos a terceros.

## Requisitos

- **Wayland** (Hyprland)
- **grim** + **slurp** — captura de pantalla
- **ImageMagick** (`magick` o `convert`) — redimensionado y anotación
- **Ollama** — servidor de modelos local
- **Python 3**

```bash
sudo pacman -S grim slurp imagemagick python hyprland
curl -fsSL https://ollama.com/install.sh | sh
```

## Instalación

```bash
git clone https://github.com/VECTORG99/OpenVist.git
cd OpenVist
chmod +x install.sh
./install.sh
```

O usando Make:

```bash
make install
```

## Uso

```bash
# Ambas pantallas
opencode-see full

# Una pantalla (mejor calidad, más detalle para texto)
LEFT_MON=DP-2 RIGHT_MON=DP-3 opencode-see left
LEFT_MON=DP-2 RIGHT_MON=DP-3 opencode-see right

# Seleccionar área
opencode-see region

# Ventana activa
opencode-see window

# Prompt personalizado
opencode-see full "Busca errores o mensajes importantes en la pantalla"

# Usar una plantilla de prompt
opencode-see --prompt-template errors left

# Anotar la captura con la descripción superpuesta
opencode-see --annotate left

# Comparar con una captura anterior
opencode-see --compare ~/Pictures/opencode-ss/ss-anterior.jpg left

# Listar modelos disponibles en Ollama
opencode-see --list-models
```

### Modelos de visión soportados

OpenVist funciona con cualquier modelo de visión compatible con Ollama. Los modelos recomendados:

| Modelo | Descripción | Comando |
|---|---|---|
| `qwen2.5vl:7b` | **Por defecto** — buen balance de velocidad y precisión | `ollama pull qwen2.5vl:7b` |
| `qwen2.5vl:3b` | Más rápido, menos preciso — ideal para chequeos rápidos | `ollama pull qwen2.5vl:3b` |
| `llama3.2-vision:11b` | Alternativa — mayor precisión, más lento | `ollama pull llama3.2-vision:11b` |

Cambia el modelo con la variable de entorno `VISION_MODEL` o en `config.json`:

```bash
VISION_MODEL=qwen2.5vl:3b opencode-see full
```

Para ver qué modelos tienes instalados:

```bash
opencode-see --list-models
```

### Plantillas de prompt

OpenVist incluye plantillas de prompt predefinidas en el directorio `prompts/` para casos de uso comunes:

| Plantilla | Descripción |
|---|---|
| `default` | Describe en detalle lo que ves en la pantalla |
| `errors` | Busca errores, advertencias y mensajes importantes |
| `code` | Analiza código visible en un editor o terminal |
| `debug` | Describe el estado de una sesión de debugging |
| `ui` | Describe el layout de la UI y elementos destacados |

```bash
opencode-see --prompt-template errors left
opencode-see --prompt-template code window
opencode-see --prompt-template debug full
```

Puedes combinar una plantilla con un prompt adicional para dar contexto extra:

```bash
opencode-see --prompt-template errors left "fíjate en el diálogo rojo"
```

### Modo anotación (`--annotate`)

Superpone la descripción de la IA directamente sobre la imagen de la captura (una barra de texto en la parte inferior). Útil para compartir capturas anotadas en Discord:

```bash
opencode-see --annotate left
# Genera: ~/Pictures/opencode-ss/ss-...-annotated.jpg
```

### Modo comparación (`--compare`)

Toma una captura nueva y le pide a la IA que la compare con una imagen anterior. Útil para responder "¿qué cambió desde la última vez?":

```bash
opencode-see --compare ~/Pictures/opencode-ss/ss-20260814-100000.jpg left
```

### Variables de entorno

| Variable | Por defecto | Descripción |
|---|---|---|
| `LEFT_MON` | — | Nombre del monitor izquierdo (`hyprctl monitors`) |
| `RIGHT_MON` | — | Nombre del monitor derecho |
| `VISION_MODEL` | `qwen2.5vl:7b` | Modelo de visión en Ollama |
| `OLLAMA_URL` | `http://127.0.0.1:11434` | URL de la API de Ollama |
| `VISION_TIMEOUT` | `120` | Timeout de la petición en segundos |
| `VISION_NUM_CTX` | `4096` | Tamaño de la ventana de contexto |
| `OPENVIST_SS_DIR` | `~/Pictures/opencode-ss` | Directorio de capturas |
| `OPENVIST_LOG_FILE` | `~/.local/share/opencode-see.log` | Archivo de log |

### Salida

El script imprime la ruta de la captura y la descripción del modelo de visión. Al final se añade un pie de página con la versión y el modelo usado:

```
---
_Analyzed by OpenVist v1.1.0 | qwen2.5vl:7b_
```

La ruta de la captura también se guarda en `/tmp/opencode-latest-ss-path` para integración con bots.

## Integración con Discord (remote-opencode)

Agregué el comando `/see` al bot `remote-opencode` para usarlo así en Discord:

```
/see mode:left
/see mode:left template:errors
/see mode:window prompt:"Busca el error en la consola"
```

El bot ejecuta `opencode-see` en mi PC, recibe la descripción del modelo de visión, y me envía tanto el texto como la imagen adjunta al chat. Todo local, nada sale de mi red.

Opciones del comando `/see`:

| Opción | Descripción |
|---|---|
| `mode` | Modo de captura (full, left, right, region, window) |
| `prompt` | Prompt personalizado para el modelo de visión |
| `template` | Plantilla de prompt (default, errors, code, debug, ui) |

El comando incluye **rate limiting**: máximo 1 uso cada 10 segundos por usuario (configurable con la variable `OPENVIST_COOLDOWN` en milisegundos).

El archivo `see-command.js` es el código de referencia para agregar el comando a cualquier bot de Discord.js.

## Limpieza automática

Las capturas se guardan en `~/Pictures/opencode-ss/`. Un timer de systemd borra archivos con más de 5 minutos:

```bash
systemctl --user status opencode-ss-clean.timer
```

## Configuración

Copia el archivo de ejemplo y edita según tus necesidades:

```bash
mkdir -p ~/.config/opencode-see
cp config.example.json ~/.config/opencode-see/config.json
```

```json
{
  "model": "qwen2.5vl:7b",
  "resize_target": "1024x1024>",
  "timeout": 120,
  "ollama_url": "http://127.0.0.1:11434",
  "num_ctx": 4096,
  "screenshot_dir": "~/Pictures/opencode-ss",
  "log_file": "~/.local/share/opencode-see.log"
}
```

Las variables de entorno tienen prioridad sobre el archivo de configuración.

## Health check

Verifica que todo esté correctamente configurado:

```bash
opencode-see --check
```

Revisa dependencias, conectividad con Ollama, disponibilidad del modelo y variables de entorno.

## Desarrollo

```bash
# Lint (shellcheck)
make lint

# Sintaxis Python
make pycheck

# Tests
make test

# Todo junto (lint + pycheck + tests)
make check
```

## Troubleshooting

| Problema | Solución |
|---|---|
| `ollama: command not found` | Instala Ollama: `curl -fsSL https://ollama.com/install.sh \| sh` |
| `model 'qwen2.5vl:7b' not found` | Descarga el modelo: `ollama pull qwen2.5vl:7b` |
| `cannot reach Ollama` | Verifica que Ollama esté corriendo: `ollama serve` |
| `grim failed to capture` | Verifica que estás en Wayland (no X11) |
| `LEFT_MON is not set` | Ejecuta `hyprctl monitors` y configura el nombre del monitor |
| `magick/convert not found` | Instala ImageMagick: `sudo pacman -S imagemagick` |
| `prompt template 'X' not found` | Revisa las plantillas disponibles: `ls prompts/` |
| Timeout en el análisis | Aumenta `timeout` en config.json o usa un modelo más pequeño (`qwen2.5vl:3b`) |
| Log de errores | Revisa `~/.local/share/opencode-see.log` |

## Desinstalación

```bash
./uninstall.sh
# o
make uninstall
```

Elimina los scripts, plantillas de prompt, config de systemd timer, y opcionalmente el directorio de capturas (`--purge`).

## Seguridad

- **100% local** — modelo de visión en Ollama (127.0.0.1:11434)
- Sin API keys, sin cuentas cloud, sin enviar imágenes a nadie
- Capturas se autoeliminan a los 5 minutos
- Ideal para debugging remoto sin exponer tu pantalla a servicios externos
