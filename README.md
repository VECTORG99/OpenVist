# OpenVist

Captura de pantalla remota + análisis con IA local para Wayland/Hyprland.

**Caso de uso real:** Poder ver el escritorio de mi PC desde fuera de casa mientras codeo. Uso OpenCode vía Discord (remote-opencode bot), le pido que ejecute `opencode-see`, y el bot me envía la descripción + la imagen de la pantalla directamente al chat de Discord. Sin servicios cloud, sin enviar datos a terceros.

## Requisitos

- **Wayland** (Hyprland)
- **grim** + **slurp** — captura de pantalla
- **ImageMagick** (`convert`) — redimensionado
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
```

### Variables de entorno

| Variable | Por defecto | Descripción |
|---|---|---|
| `LEFT_MON` | — | Nombre del monitor izquierdo (`hyprctl monitors`) |
| `RIGHT_MON` | — | Nombre del monitor derecho |
| `VISION_MODEL` | `qwen2.5vl:7b` | Modelo de visión en Ollama |

### Salida

El script imprime la ruta de la captura y la descripción del modelo de visión. La ruta también se guarda en `/tmp/opencode-latest-ss-path` para integración con bots.

## Integración con Discord (remote-opencode)

Agregué el comando `/see` al bot `remote-opencode` para usarlo así en Discord:

```
/see mode:left
```

El bot ejecuta `opencode-see` en mi PC, recibe la descripción del modelo de visión, y me envía tanto el texto como la imagen adjunta al chat. Todo local, nada sale de mi red.

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

## Troubleshooting

| Problema | Solución |
|---|---|
| `ollama: command not found` | Instala Ollama: `curl -fsSL https://ollama.com/install.sh \| sh` |
| `model 'qwen2.5vl:7b' not found` | Descarga el modelo: `ollama pull qwen2.5vl:7b` |
| `cannot reach Ollama` | Verifica que Ollama esté corriendo: `ollama serve` |
| `grim failed to capture` | Verifica que estás en Wayland (no X11) |
| `LEFT_MON is not set` | Ejecuta `hyprctl monitors` y configura el nombre del monitor |
| `magick/convert not found` | Instala ImageMagick: `sudo pacman -S imagemagick` |
| Timeout en el análisis | Aumenta `timeout` en config.json o usa un modelo más pequeño (`qwen2.5vl:3b`) |
| Log de errores | Revisa `~/.local/share/opencode-see.log` |

## Desinstalación

```bash
./uninstall.sh
```

Elimina los scripts, config de systemd timer, y opcionalmente el directorio de capturas.

## Seguridad

- **100% local** — modelo de visión en Ollama (127.0.0.1:11434)
- Sin API keys, sin cuentas cloud, sin enviar imágenes a nadie
- Capturas se autoeliminan a los 5 minutos
- Ideal para debugging remoto sin exponer tu pantalla a servicios externos
