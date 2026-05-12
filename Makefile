.PHONY: lint typecheck format test check all

all: check

lint:
	ruff check was110.plugin

format:
	ruff format was110.plugin

typecheck:
	mypy was110.plugin

check: lint typecheck

test:
	@echo "=== Syntax check ==="
	python3 -m py_compile was110.plugin
	@echo "=== Chart output test ==="
	timeout 5 python3 was110.plugin 1 2>/dev/null | head -30 || true
	@echo "=== Done ==="
