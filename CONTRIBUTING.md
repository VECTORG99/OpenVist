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

### Verificación local

```bash
# Lint bash
shellcheck opencode-see install.sh uninstall.sh

# Sintaxis Python
python3 -m py_compile vision_analyze.py

# Tests
bats tests/
```

## Convenciones

- **Bash**: `set -euo pipefail`, sin `2>/dev/null` silencioso, usar `log()` para errores
- **Python**: stdlib only, sin dependencias externas, type hints en funciones públicas
- **Commits**: mensajes descriptivos en inglés, formato `type: description`
- **Branches**: `fix/*`, `feat/*`, `docs/*`, `chore/*` desde `master`

## Estructura del proyecto

```
opencode-see        — script principal (bash)
vision_analyze.py   — helper de análisis IA (python)
see-command.js      — integración Discord (node)
install.sh          — instalador
uninstall.sh        — desinstalador
config.example.json — configuración de ejemplo
tests/              — tests con bats
```
