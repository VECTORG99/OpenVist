# Makefile — OpenVist build/install/test automation.
#
# Targets:
#   install    Run install.sh
#   uninstall  Run uninstall.sh
#   test       Run bats test suite
#   lint       Run shellcheck on all bash scripts
#   check      Run lint + python syntax check + tests (full CI-equivalent)
#   clean      Remove build/test artifacts
#

SHELL := /bin/bash

# Scripts to lint with shellcheck.
SH_SCRIPTS := opencode-see install.sh uninstall.sh opencode-see-completion.bash ollama-check.sh

# Python files to syntax-check.
PY_FILES := vision_analyze.py

# Bats binary (fall back to PATH lookup).
BATS ?= bats

.PHONY: install uninstall test lint check clean

install:
	./install.sh

uninstall:
	./uninstall.sh

test:
	$(BATS) tests/

lint:
	shellcheck $(SH_SCRIPTS)

check: lint pycheck test

pycheck:
	python3 -m py_compile $(PY_FILES)

clean:
	rm -f tests/*.tmp
	rm -f *.pyc
	find . -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
