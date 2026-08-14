# Contribuir a OpenVist

## Desarrollo

```bash
git clone https://github.com/VECTORG99/OpenVist.git
cd OpenVist
```

### Requisitos de desarrollo

- `shellcheck` — para lint de scripts bash
- `bats` — para tests de bash
- `python3` — para validar vision_analyze.py
- `imagemagick` — para los tests de anotación

### Verificación local

```bash
# Todo en uno (lint + sintaxis Python + tests)
make check

# O por separado:
make lint       # shellcheck
make pycheck    # python3 -m py_compile
make test       # bats tests/
```

## Convenciones

- **Bash**: `set -euo pipefail`, sin `2>/dev/null` silencioso, usar `log()` para errores
- **Python**: stdlib only, sin dependencias externas, type hints en funciones públicas
- **JavaScript**: sin dependencias nuevas más allá de discord.js
- **Commits**: mensajes descriptivos en inglés, formato `type: description`
- **Branches**: `fix/*`, `feat/*`, `docs/*`, `chore/*` desde `master`

## Estructura del proyecto

```
opencode-see        — script principal (bash)
vision_analyze.py   — helper de análisis IA (python)
see-command.js      — integración Discord (node)
prompts/            — plantillas de prompt (.txt)
  default.txt       — descripción general
  errors.txt        — búsqueda de errores
  code.txt          — análisis de código
  debug.txt         — sesión de debugging
  ui.txt            — layout de UI
install.sh          — instalador
uninstall.sh        — desinstalador
config.example.json — configuración de ejemplo
Makefile            — automatización (install, test, lint, check)
tests/              — tests con bats
```

## Añadir una nueva plantilla de prompt

Las plantillas de prompt son archivos de texto plano en el directorio `prompts/`. Para añadir una nueva:

1. Crea un archivo `prompts/<nombre>.txt` con el prompt deseado (una línea, en inglés o español).
2. Añade una entrada en la lista de plantillas de `see-command.js` (`PROMPT_TEMPLATES`).
3. Añade un test en `tests/prompts.bats` verificando que el archivo existe y contiene el contenido esperado.
4. Documenta la plantilla en `README.md` (tabla de plantillas).
5. Ejecuta `make check` para verificar que todo pasa.

### Guía para prompts

- Sé específico sobre qué buscar en la pantalla.
- Indica el contexto (editor, terminal, diálogo, etc.) cuando sea relevante.
- Mantén los prompts concisos — el modelo tiene un contexto limitado.
- Para prompts en español, el modelo los entiende, pero los prompts en inglés suelen dar resultados más consistentes.

## Añadir un nuevo modelo de visión

Para soportar un nuevo modelo de visión:

1. Añádelo a la lista `RECOMMENDED_MODELS` en `opencode-see`.
2. Documenta el modelo en `README.md` (tabla de modelos) y en `config.example.json` (`_recommended_models`).
3. Verifica con `opencode-see --list-models` que aparece marcado como recomendado.
