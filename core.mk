# ==============================================================================
# makelib-py: Core Standardized Makefile for Python Projects
# ==============================================================================
# This file provides standardized, opinionated quality gates and workflow targets
# for Python repositories. Downstream projects include this file dynamically.
# ==============================================================================

SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# ------------------------------------------------------------------------------
# Extensible Project Variables
# ------------------------------------------------------------------------------
# Downstream projects can override any of these variables before including core.mk
# or on the command line (e.g., `make test MIN_COVERAGE=90`).
SRC_DIR        ?= src
TEST_DIR       ?= tests
MIN_COVERAGE   ?= 80
MAX_COMPLEXITY ?= 10

# Python environment and toolchain executables
PYTHON         ?= python3
RUFF           ?= ruff
MYPY           ?= mypy
BANDIT         ?= bandit
PIP_AUDIT      ?= pip-audit
PIP_AUDIT_FLAGS?= $(if $(wildcard requirements.txt),-r requirements.txt,.)
PYTEST         ?= pytest
PYTEST_FLAGS   ?= -v
export PYTHONPATH ?= $(SRC_DIR)

# Configuration paths
CONFIG_FILE    ?= pyproject.toml

# Resolve location of this makefile (allows locating bundled golden config)
MAKELIB_DIR    ?= $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))

# ------------------------------------------------------------------------------
# Phony Targets Declaration
# ------------------------------------------------------------------------------
.PHONY: help format lint type-check smell audit test check-all clean sync-config install-hooks

# ------------------------------------------------------------------------------
# Help Target (Self-Documenting via '##' comments)
# ------------------------------------------------------------------------------
help: ## Show this help message and target descriptions
	@echo "makelib-py: Standardized Python Workflow Targets"
	@echo ""
	@echo "Usage: make [target] [VARIABLE=value]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort
	@echo ""
	@echo "Configurable Variables:"
	@echo "  SRC_DIR        = $(SRC_DIR)"
	@echo "  TEST_DIR       = $(TEST_DIR)"
	@echo "  MIN_COVERAGE   = $(MIN_COVERAGE)%"
	@echo "  MAX_COMPLEXITY = $(MAX_COMPLEXITY)"
	@echo "  CONFIG_FILE    = $(CONFIG_FILE)"

# ------------------------------------------------------------------------------
# Code Formatting
# ------------------------------------------------------------------------------
format: ## Format code and sort imports using Ruff
	@echo "==> Formatting code with Ruff..."
	@$(RUFF) format $(SRC_DIR) $(if $(wildcard $(TEST_DIR)),$(TEST_DIR),)
	@$(RUFF) check --fix $(SRC_DIR) $(if $(wildcard $(TEST_DIR)),$(TEST_DIR),)
	@echo "==> Formatting complete."

# ------------------------------------------------------------------------------
# Linting
# ------------------------------------------------------------------------------
lint: ## Lint codebase with Ruff without modifying files
	@echo "==> Running Ruff lint checks..."
	@$(RUFF) check $(SRC_DIR) $(if $(wildcard $(TEST_DIR)),$(TEST_DIR),)
	@$(RUFF) format --check $(SRC_DIR) $(if $(wildcard $(TEST_DIR)),$(TEST_DIR),)
	@echo "==> Lint checks passed."

# ------------------------------------------------------------------------------
# Type Checking
# ------------------------------------------------------------------------------
type-check: ## Run static type analysis with Mypy in strict mode
	@echo "==> Running static type checking with Mypy..."
	@if [ -f "$(CONFIG_FILE)" ]; then \
		$(MYPY) --config-file $(CONFIG_FILE) $(SRC_DIR) $(if $(wildcard $(TEST_DIR)),$(TEST_DIR),); \
	else \
		$(MYPY) --strict $(SRC_DIR) $(if $(wildcard $(TEST_DIR)),$(TEST_DIR),); \
	fi
	@echo "==> Type checks passed."

# ------------------------------------------------------------------------------
# Code Smell & Security AST Inspection
# ------------------------------------------------------------------------------
smell: ## Inspect code smells (Ruff C901 McCabe complexity and Bandit AST security)
	@echo "==> Checking McCabe cyclomatic complexity with Ruff (threshold: $(MAX_COMPLEXITY))..."
	@$(RUFF) check --select C901 $(SRC_DIR)
	@echo "==> Running Bandit security AST scanner..."
	@if [ -f "$(CONFIG_FILE)" ]; then \
		$(BANDIT) -r $(SRC_DIR) -c $(CONFIG_FILE); \
	else \
		$(BANDIT) -r $(SRC_DIR); \
	fi
	@echo "==> Code smell and AST security checks passed."

# ------------------------------------------------------------------------------
# Dependency Vulnerability Audit
# ------------------------------------------------------------------------------
audit: ## Audit dependencies for known CVE vulnerabilities using pip-audit
	@echo "==> Auditing dependencies for CVE vulnerabilities..."
	@$(PIP_AUDIT) $(PIP_AUDIT_FLAGS)
	@echo "==> Dependency audit passed."

# ------------------------------------------------------------------------------
# Unit Testing & Coverage
# ------------------------------------------------------------------------------
test: ## Run tests and enforce code coverage threshold via Pytest
	@echo "==> Running tests with Pytest (enforcing >= $(MIN_COVERAGE)% coverage)..."
	@if [ -d "$(TEST_DIR)" ]; then \
		$(PYTEST) $(PYTEST_FLAGS) $(TEST_DIR) --cov=$(SRC_DIR) --cov-report=term-missing --cov-fail-under=$(MIN_COVERAGE); \
	else \
		echo "Warning: Test directory '$(TEST_DIR)' does not exist. Running pytest on $(SRC_DIR)..."; \
		$(PYTEST) $(PYTEST_FLAGS) $(SRC_DIR) --cov=$(SRC_DIR) --cov-report=term-missing --cov-fail-under=$(MIN_COVERAGE); \
	fi
	@echo "==> Tests and coverage passed."

# ------------------------------------------------------------------------------
# Full Quality Verification
# ------------------------------------------------------------------------------
check-all: lint type-check smell audit test ## Run all checks: lint, type-check, smell, audit, test
	@echo ""
	@echo "========================================================"
	@echo "  All quality gates passed successfully! (makelib-py)"
	@echo "========================================================"

# ------------------------------------------------------------------------------
# Configuration Syncing
# ------------------------------------------------------------------------------
sync-config: ## Copy the golden pyproject.toml from makelib into project root
	@echo "==> Syncing golden pyproject.toml from makelib-py..."
	@if [ ! -f "$(MAKELIB_DIR)/pyproject.toml" ]; then \
		echo "Error: Golden pyproject.toml not found at $(MAKELIB_DIR)/pyproject.toml"; \
		exit 1; \
	fi
	@SRC_REAL="$$(realpath $(MAKELIB_DIR)/pyproject.toml 2>/dev/null || readlink -f $(MAKELIB_DIR)/pyproject.toml)"; \
	DST_REAL="$$(realpath ./pyproject.toml 2>/dev/null || readlink -f ./pyproject.toml || echo "./pyproject.toml")"; \
	if [ -f "./pyproject.toml" ] && [ "$$SRC_REAL" = "$$DST_REAL" ]; then \
		echo "==> makelib is running within its own repository root; skipping sync."; \
	else \
		if [ -f "./pyproject.toml" ]; then \
			echo "Backing up existing pyproject.toml to pyproject.toml.bak..."; \
			cp ./pyproject.toml ./pyproject.toml.bak; \
		fi; \
		cp "$$SRC_REAL" ./pyproject.toml; \
		echo "==> Successfully synced golden pyproject.toml to ./pyproject.toml"; \
	fi

# ------------------------------------------------------------------------------
# Housekeeping
# ------------------------------------------------------------------------------
clean: ## Remove temporary build, test, and cache artifacts
	@echo "==> Cleaning cache and build artifacts..."
	@rm -rf .pytest_cache .mypy_cache .ruff_cache .coverage htmlcov/ dist/ build/ *.egg-info coverage.xml
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type f -name "*.pyo" -delete 2>/dev/null || true
	@echo "==> Clean complete."

# ------------------------------------------------------------------------------
# Git Hook Installation & Safeguards
# ------------------------------------------------------------------------------
install-hooks: ## Configure local Git hooks (pre-push check and main branch protection)
	@echo "==> Configuring Git hooks..."
	@if [ -d ".git" ]; then \
		mkdir -p .git/hooks; \
		if [ -f ".githooks/pre-push" ]; then \
			cp .githooks/pre-push .git/hooks/pre-push; \
			chmod +x .git/hooks/pre-push; \
			echo "==> Installed .githooks/pre-push to .git/hooks/pre-push"; \
		elif [ -f "$(MAKELIB_DIR)/.githooks/pre-push" ]; then \
			cp "$(MAKELIB_DIR)/.githooks/pre-push" .git/hooks/pre-push; \
			chmod +x .git/hooks/pre-push; \
			echo "==> Installed $$(MAKELIB_DIR)/.githooks/pre-push to .git/hooks/pre-push"; \
		fi; \
		git config core.hooksPath .githooks 2>/dev/null || true; \
		echo "==> Local Git hooks successfully configured!"; \
	else \
		echo "Notice: Not a Git repository; skipping hook installation."; \
	fi

