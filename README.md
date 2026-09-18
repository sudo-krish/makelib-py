# makelib-py

[![CI](https://github.com/sudo-krish/makelib-py/actions/workflows/ci.yml/badge.svg)](https://github.com/sudo-krish/makelib-py/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.14-blue.svg)](https://www.python.org/)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)
[![Checked with mypy](https://www.mypy-lang.org/static/mypy_badge.svg)](https://mypy-lang.org/)

A centralized, drop-in Make library and toolchain configuration for Python projects.

`makelib-py` eliminates boilerplate and eliminates quality drift across Python repositories by centralizing modern quality gates into a lightweight, dynamic include file (`core.mk`) paired with a golden `pyproject.toml`.

---

## Key Features

- **Blazing Fast Toolchain**:
  - **[Ruff](https://github.com/astral-sh/ruff)** for lightning-fast formatting, linting, import sorting (`isort`), and cyclomatic complexity checking (`C901`).
  - **[Mypy](https://mypy-lang.org/)** configured with strict type checks.
  - **[Bandit](https://github.com/PyCQA/bandit)** for AST-level security scanning.
  - **[pip-audit](https://github.com/pypa/pip-audit)** for auditing dependency CVE vulnerabilities.
  - **[Pytest](https://docs.pytest.org/)** with strict test discovery and minimum coverage thresholds.
- **Zero-Copy Dynamic Inclusion**: Downstream repositories don't clone and maintain duplicate Makefiles. They include `.makelib/core.mk` directly with auto-cloning and one-command updates.
- **Golden Configuration Sync**: Distribute and sync strict, standardized `pyproject.toml` configurations into downstream projects with automated backup handling.
- **Extensible & Configurable**: Easily override source paths, coverage targets, or binary flags via standard Make variables.
- **Branch Protection & CI/CD Guardrails**: Enforced pull request workflows, automated matrix tests, and local Git hooks preventing direct pushes to `main`.

---

## Toolchain Overview

| Tool | Quality Gate | Primary Target |
| :--- | :--- | :--- |
| **Ruff** | Code Formatting & Import Sorting (`isort`) | `make format` |
| **Ruff** | Linting & Bug Detection (`flake8-bugbear`, `pyflakes`) | `make lint` |
| **Ruff (C901)** | McCabe Cyclomatic Complexity Analysis | `make smell` |
| **Bandit** | Static AST Security Vulnerability Scanning | `make smell` |
| **Mypy** | Strict Static Type Checking | `make type-check` |
| **pip-audit** | Known CVE Vulnerability Auditing for Dependencies | `make audit` |
| **detect-secrets** | Deep Scanning for Leaked Credentials & API Tokens | `make secret-scan` |
| **pip-licenses** | Open-Source Dependency License Compliance Audit | `make license-check` |
| **Pytest** | Unit Testing and Minimum Coverage Enforcement | `make test` |
| **All Above** | Complete CI/CD Quality Gate Pipeline | `make check-all` |

---

## Adoption Guide for Downstream Projects

Adopting `makelib-py` in a new or existing Python repository takes less than 60 seconds:

### Step 1: Add the Boilerplate to your `Makefile`

In your downstream repository, create or open `Makefile` and paste the contents of [`downstream_template.mk`](downstream_template.mk):

```makefile
# ==============================================================================
# makelib-py: Downstream Makefile Integration Template
# ==============================================================================
MAKELIB_REPO ?= https://github.com/sudo-krish/makelib-py.git
MAKELIB_DIR  ?= .makelib
MAKELIB_REF  ?= main

# Project-specific overrides (uncomment and adjust as needed)
# SRC_DIR      ?= src
# TEST_DIR     ?= tests
# MIN_COVERAGE ?= 80

.PHONY: init-makelib update-makelib

$(MAKELIB_DIR):
	@echo "==> Cloning makelib-py ($(MAKELIB_REF)) into $(MAKELIB_DIR)..."
	@git clone --depth 1 --branch $(MAKELIB_REF) $(MAKELIB_REPO) $(MAKELIB_DIR)

init-makelib: $(MAKELIB_DIR) ## Clone makelib and sync golden pyproject.toml into project root
	@echo "==> Initializing makelib-py..."
	@if [ -f "pyproject.toml" ]; then \
		echo "Backing up existing pyproject.toml to pyproject.toml.bak..."; \
		cp pyproject.toml pyproject.toml.bak; \
	fi
	@cp $(MAKELIB_DIR)/pyproject.toml pyproject.toml
	@echo "==> Successfully installed golden pyproject.toml into project root."
	@echo "==> makelib-py initialized! Run 'make help' to inspect available targets."

update-makelib: $(MAKELIB_DIR) ## Fetch and fast-forward latest makelib-py changes
	@echo "==> Updating $(MAKELIB_DIR)..."
	@cd $(MAKELIB_DIR) && git fetch origin $(MAKELIB_REF) && git checkout $(MAKELIB_REF) && git pull origin $(MAKELIB_REF)
	@echo "==> makelib-py updated. Run 'make sync-config' to refresh pyproject.toml if desired."

-include $(MAKELIB_DIR)/core.mk

ifeq ($(wildcard $(MAKELIB_DIR)/core.mk),)
help:
	@echo "makelib-py is not initialized in this project."
	@echo "Run 'make init-makelib' to clone the toolchain and sync configuration."
endif
```

### Step 2: Initialize makelib-py

Run the initialization target:

```bash
make init-makelib
```

This will:
1. Shallow clone `makelib-py` into `.makelib/`.
2. Back up any existing `pyproject.toml` to `pyproject.toml.bak`.
3. Copy the golden `pyproject.toml` into your project root.

### Step 3: Update `.gitignore`

Add the hidden `.makelib/` folder to your project's `.gitignore`:

```bash
echo ".makelib/" >> .gitignore
```

### Step 4: Verify Installation & Configure Hooks

Run the self-documenting help command and configure local hooks:

```bash
make help
make install-hooks
```

---

## Available Make Targets

| Target | Description |
| :--- | :--- |
| `make help` | Show colorized target list with descriptions and current variable values. |
| `make format` | Automatically reformat code and sort imports using Ruff. |
| `make lint` | Run Ruff format checks and linter rules without mutating source files. |
| `make type-check` | Perform strict static type checking with Mypy. |
| `make smell` | Run Ruff McCabe complexity analysis (`C901`) and Bandit security AST scanner. |
| `make audit` | Audit dependencies against CVE databases using `pip-audit`. |
| `make secret-scan` | Scan repository for hardcoded secrets, private keys, and API tokens. |
| `make license-check` | Audit installed dependency licenses for open-source compliance. |
| `make test` | Run Pytest test suite and enforce minimum code coverage (`MIN_COVERAGE`). |
| `make check-all` | Execute all quality gates in sequence: `lint`, `type-check`, `smell`, `audit`, `secret-scan`, `license-check`, `test`. |
| `make sync-config` | Re-sync the golden `pyproject.toml` from `.makelib/` into the project root. |
| `make update-makelib` | Fetch and update `.makelib` to the latest commit/tag. |
| `make clean` | Remove build caches, test caches, coverage outputs, and bytecode files. |
| `make install-hooks` | Configure local Git hooks (pre-push check and direct push blocker). |

---

## Branch Protection & Development Workflow

To uphold professional software engineering standards, direct pushes to `main` are strictly restricted, ensuring all changes are verified through tests and code review.

### 1. Server-Side GitHub Ruleset (Configured on GitHub)

The repository enforces a GitHub Ruleset with the following settings:
- **Target branch**: `main`
- **Require a pull request before merging**: Enabled (restricts direct pushes).
- **Require status checks to pass before merging**: Enabled.
  - Required checks: `Quality Gate (Python 3.10)`, `Quality Gate (Python 3.11)`, `Quality Gate (Python 3.12)`, and `CI Check Status`.

### 2. Client-Side Git Safeguards (`make install-hooks`)

To prevent accidental local push attempts to `main`, run:

```bash
make install-hooks
```

This activates `.githooks/pre-push`, which:
1. Rejects any `git push origin main` command with a helpful message directing you to create a feature branch.
2. Automatically executes `make check-all` before pushing feature branches, preventing broken commits from reaching remote CI.

### 3. Developer Workflow Standard

```bash
# 1. Create a feature branch
git checkout -b feature/my-enhancement

# 2. Develop and verify changes locally
make check-all

# 3. Commit and push
git commit -am "feat: implement enhancement"
git push origin feature/my-enhancement

# 4. Open a Pull Request
# CI will run all quality gates automatically. Merge once checks pass!
```

---

## CI/CD Pipeline (GitHub Actions)

`makelib-py` includes an automated GitHub Actions pipeline in [`.github/workflows/ci.yml`](.github/workflows/ci.yml) that executes across a multi-version Python matrix (`3.10`, `3.11`, `3.12`) on every push to `main` and all pull requests:

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  quality-gate:
    strategy:
      matrix:
        python-version: ["3.14"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
          allow-prereleases: true
          cache: "pip"
      - run: pip install ruff mypy bandit pip-audit pytest pytest-cov && pip install -e .
      - run: make check-all MIN_COVERAGE=80
```

---

## Configuration & Extensibility

All variables in `core.mk` use conditional assignment (`?=`), allowing you to override them directly in your downstream `Makefile` or via the CLI:

### 1. Custom Paths and Thresholds in `Makefile`

```makefile
# Customize settings BEFORE including core.mk
SRC_DIR        = my_package
TEST_DIR       = tests/unit
MIN_COVERAGE   = 90
MAX_COMPLEXITY = 8

# Inherit makelib targets
-include $(MAKELIB_DIR)/core.mk
```

### 2. Command-Line Overrides

```bash
# Run tests with a stricter coverage threshold
make test MIN_COVERAGE=95

# Point to an alternate source folder
make lint SRC_DIR=lib

# Specify a virtualenv Python binary
make type-check PYTHON=.venv/bin/python MYPY=.venv/bin/mypy
```

### 3. Pinning Makelib Versions

In your `Makefile`, pin `MAKELIB_REF` to any git tag, branch, or SHA:

```makefile
MAKELIB_REF ?= v1.2.0
```

---

## Repository Structure

```
makelib-py/
├── .github/
│   ├── workflows/
│   │   └── ci.yml               # Multi-version matrix CI workflow
│   └── pull_request_template.md # PR quality gate checklist
├── .githooks/
│   └── pre-push                 # Local hook preventing direct pushes to main
├── src/
│   └── makelib/
│       ├── __init__.py          # Package initialization
│       └── config.py            # Configuration loader and validator
├── tests/
│   ├── __init__.py
│   ├── test_config.py           # Tests for configuration validation
│   └── test_makefile.py         # Tests for Makefile targets and sync logic
├── core.mk                      # Core reusable Makefile targets and quality gates
├── pyproject.toml               # Golden toolchain configuration (Ruff, Mypy, Pytest, Bandit)
├── downstream_template.mk       # Copy-paste bootstrap template for downstream projects
├── Makefile                     # Self-hosting Makefile including core.mk
├── .gitignore                   # Standard Python and makelib ignore rules
├── LICENSE                      # MIT License file
└── README.md                    # Documentation and adoption guide
```

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
