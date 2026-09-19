# ==============================================================================
# makelib-py: Downstream Makefile Integration Template
# ==============================================================================
# Paste the following snippet into your downstream project's Makefile.
# It bootstraps makelib-py, pulls standardized toolchain targets, and syncs configs.
# ==============================================================================

# Repository location and local target directory
MAKELIB_REPO ?= https://github.com/sudo-krish/makelib-py.git
MAKELIB_DIR  ?= .makelib
MAKELIB_REF  ?= main

# Project-specific overrides (uncomment and adjust as needed)
# SRC_DIR      ?= src
# TEST_DIR     ?= tests
# MIN_COVERAGE ?= 80

.PHONY: init-makelib update-makelib

# Target to clone makelib-py into .makelib/
$(MAKELIB_DIR):
	@echo "==> Cloning makelib-py ($(MAKELIB_REF)) into $(MAKELIB_DIR)..."
	@git clone --depth 1 --branch $(MAKELIB_REF) $(MAKELIB_REPO) $(MAKELIB_DIR)

# Initialize makelib-py and bootstrap template pyproject.toml if not already present
init-makelib: $(MAKELIB_DIR) ## Clone makelib and bootstrap template pyproject.toml
	@echo "==> Initializing makelib-py..."
	@if [ ! -f "pyproject.toml" ]; then \
		cp $(MAKELIB_DIR)/template_pyproject.toml pyproject.toml; \
		echo "==> Installed uv template pyproject.toml into project root."; \
	else \
		echo "==> Existing pyproject.toml detected; preserving project metadata."; \
	fi
	@if command -v uv >/dev/null 2>&1; then \
		echo "==> Syncing virtual environment with uv..."; \
		uv sync || true; \
	fi
	@echo "==> makelib-py initialized! Run 'make help' to inspect available targets."

# Pull latest changes from makelib-py repository
update-makelib: $(MAKELIB_DIR) ## Fetch and fast-forward latest makelib-py changes
	@echo "==> Updating $(MAKELIB_DIR)..."
	@cd $(MAKELIB_DIR) && git fetch origin $(MAKELIB_REF) && git checkout $(MAKELIB_REF) && git pull origin $(MAKELIB_REF)
	@echo "==> makelib-py updated. Run 'make sync-config' to refresh pyproject.toml if desired."

# Inherit all standardized targets (-include suppresses errors if not yet cloned)
-include $(MAKELIB_DIR)/core.mk

# Friendly guidance when make is run before initializing makelib
ifeq ($(wildcard $(MAKELIB_DIR)/core.mk),)
help:
	@echo "makelib-py is not initialized in this project."
	@echo "Run 'make init-makelib' to clone the toolchain and sync configuration."
endif
