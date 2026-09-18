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
DETECT_SECRETS ?= detect-secrets
PIP_LICENSES   ?= pip-licenses
PIP_LICENSES_FLAGS ?= --summary
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
.PHONY: help format lint type-check smell audit secret-scan license-check test check-all clean build bump-patch bump-minor bump-major sync-config install-hooks

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
# Secret Scanning
# ------------------------------------------------------------------------------
secret-scan: ## Scan repository for hardcoded secrets and credentials
	@echo "==> Scanning repository for hardcoded secrets and credentials..."
	@$(PYTHON) -c 'import subprocess, json, sys; out = subprocess.check_output(["$(DETECT_SECRETS)", "scan"]); res = json.loads(out).get("results", {}); (print("ERROR: Hardcoded secrets detected:\n", json.dumps(res, indent=2)) or sys.exit(1)) if res else print("==> Zero secrets detected.")'
	@echo "==> Secret scan passed."

# ------------------------------------------------------------------------------
# Dependency License Compliance
# ------------------------------------------------------------------------------
license-check: ## Audit dependency licenses for compliance
	@echo "==> Auditing dependency licenses..."
	@$(PIP_LICENSES) $(PIP_LICENSES_FLAGS)
	@echo "==> License compliance check passed."

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
check-all: lint type-check smell audit secret-scan license-check test ## Run all checks: lint, type-check, smell, audit, secret-scan, license-check, test
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
# Packaging & Distribution
# ------------------------------------------------------------------------------
build: clean ## Build source distribution and wheel packages in dist/
	@echo "==> Building distribution packages with PEP 517 build..."
	@$(PYTHON) -m build
	@echo "==> Distribution packages created in dist/:"
	@ls -la dist/

# ------------------------------------------------------------------------------
# Semantic Version Management
# ------------------------------------------------------------------------------
bump-patch: ## Increment semantic patch version (e.g. 0.1.0 -> 0.1.1)
	@echo "==> Bumping patch version..."
	@$(PYTHON) -c 'from makelib.version import bump_version, update_project_version; from makelib.config import load_pyproject; cur = load_pyproject()["project"]["version"]; nxt = bump_version(cur, "patch"); update_project_version(nxt); print(f"==> Successfully bumped version: {cur} -> {nxt}")'

bump-minor: ## Increment semantic minor version (e.g. 0.1.0 -> 0.2.0)
	@echo "==> Bumping minor version..."
	@$(PYTHON) -c 'from makelib.version import bump_version, update_project_version; from makelib.config import load_pyproject; cur = load_pyproject()["project"]["version"]; nxt = bump_version(cur, "minor"); update_project_version(nxt); print(f"==> Successfully bumped version: {cur} -> {nxt}")'

bump-major: ## Increment semantic major version (e.g. 0.1.0 -> 1.0.0)
	@echo "==> Bumping major version..."
	@$(PYTHON) -c 'from makelib.version import bump_version, update_project_version; from makelib.config import load_pyproject; cur = load_pyproject()["project"]["version"]; nxt = bump_version(cur, "major"); update_project_version(nxt); print(f"==> Successfully bumped version: {cur} -> {nxt}")'

# ------------------------------------------------------------------------------
# Git Hook Installation & Safeguards
# ------------------------------------------------------------------------------
install-hooks: ## Configure local Git hooks / Lefthook (pre-commit branch check and pre-push quality gates)
	@echo "==> Configuring Git hooks / Lefthook..."
	@if command -v lefthook >/dev/null 2>&1; then \
		lefthook install; \
		echo "==> Lefthook installed successfully."; \
	fi
	@if [ -d ".git" ]; then \
		mkdir -p .git/hooks; \
		for hook in pre-commit pre-push; do \
			if [ -f ".githooks/$$hook" ]; then \
				cp ".githooks/$$hook" ".git/hooks/$$hook"; \
				chmod +x ".git/hooks/$$hook"; \
				echo "==> Installed .githooks/$$hook to .git/hooks/$$hook"; \
			elif [ -f "$(MAKELIB_DIR)/.githooks/$$hook" ]; then \
				cp "$(MAKELIB_DIR)/.githooks/$$hook" ".git/hooks/$$hook"; \
				chmod +x ".git/hooks/$$hook"; \
				echo "==> Installed $$(MAKELIB_DIR)/.githooks/$$hook to .git/hooks/$$hook"; \
			fi; \
		done; \
		git config core.hooksPath .githooks 2>/dev/null || true; \
		echo "==> Local Git hooks successfully configured!"; \
	else \
		echo "Notice: Not a Git repository; skipping hook installation."; \
	fi

