# makelib-py

[![CI](https://github.com/sudo-krish/makelib-py/actions/workflows/ci.yml/badge.svg)](https://github.com/sudo-krish/makelib-py/actions)
[![License](https://img.shields.io/badge/license-apache-blue.svg)](LICENSE)
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

| Tool                     | Quality Gate                                               | Primary Target         |
| :----------------------- | :--------------------------------------------------------- | :--------------------- |
| **Ruff**           | Code Formatting & Import Sorting (`isort`)               | `make format`        |
| **Ruff**           | Linting & Bug Detection (`flake8-bugbear`, `pyflakes`) | `make lint`          |
| **Ruff (C901)**    | McCabe Cyclomatic Complexity Analysis                      | `make smell`         |
| **Bandit**         | Static AST Security Vulnerability Scanning                 | `make smell`         |
| **Mypy**           | Strict Static Type Checking                                | `make type-check`    |
| **pip-audit**      | Known CVE Vulnerability Auditing for Dependencies          | `make audit`         |
| **detect-secrets** | Deep Scanning for Leaked Credentials & API Tokens          | `make secret-scan`   |
| **pip-licenses**   | Open-Source Dependency License Compliance Audit            | `make license-check` |
| **Pytest**         | Unit Testing and Minimum Coverage Enforcement              | `make test`          |
| **All Above**      | Complete CI/CD Quality Gate Pipeline                       | `make check-all`     |

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

| Target                  | Description                                                                                                                         |
| :---------------------- | :---------------------------------------------------------------------------------------------------------------------------------- |
| `make help`           | Show colorized target list with descriptions and current variable values.                                                           |
| `make format`         | Automatically reformat code and sort imports using Ruff.                                                                            |
| `make lint`           | Run Ruff format checks and linter rules without mutating source files.                                                              |
| `make type-check`     | Perform strict static type checking with Mypy.                                                                                      |
| `make smell`          | Run Ruff McCabe complexity analysis (`C901`) and Bandit security AST scanner.                                                     |
| `make audit`          | Audit dependencies against CVE databases using`pip-audit`.                                                                        |
| `make secret-scan`    | Scan repository for hardcoded secrets, private keys, and API tokens.                                                                |
| `make license-check`  | Audit installed dependency licenses for open-source compliance.                                                                     |
| `make test`           | Run Pytest test suite and enforce minimum code coverage (`MIN_COVERAGE`).                                                         |
| `make check-all`      | Execute all quality gates in sequence:`lint`, `type-check`, `smell`, `audit`, `secret-scan`, `license-check`, `test`. |
| `make build`          | Build source distribution and wheel packages in`dist/`.                                                                           |
| `make bump-patch`     | Increment semantic patch version (e.g.`0.1.0` -> `0.1.1`).                                                                      |
| `make bump-minor`     | Increment semantic minor version (e.g.`0.1.0` -> `0.2.0`).                                                                      |
| `make bump-major`     | Increment semantic major version (e.g.`0.1.0` -> `1.0.0`).                                                                      |
| `make sync-config`    | Re-sync the golden`pyproject.toml` from `.makelib/` into the project root.                                                      |
| `make update-makelib` | Fetch and update`.makelib` to the latest commit/tag.                                                                              |
| `make clean`          | Remove build caches, test caches, coverage outputs, and bytecode files.                                                             |
| `make install-hooks`  | Configure local Git hooks & Lefthook (`pre-commit` branch naming validation and `pre-push` quality gates).                      |

---

### Branch Naming Policy & SemVer Release Mapping

To enable fully automated, deterministic releases, `makelib-py` enforces a strict **Branch Naming Policy**. Branch prefixes directly classify the semantic scope of changes and determine how version numbers are bumped when code merges into `main`:

| Branch Prefix                                        | SemVer Level    | Target Release | Usage & Scope                                                                    |
| :--------------------------------------------------- | :-------------- | :------------- | :------------------------------------------------------------------------------- |
| `major/<name>`, `breaking/<name>`                | **MAJOR** | `X.0.0`      | Breaking API changes, signature removals, architectural rewrites                 |
| `feat/<name>`, `feature/<name>`                  | **MINOR** | `0.X.0`      | New user-facing features, additional Make targets, backward-compatible additions |
| `fix/<name>`, `patch/<name>`                     | **PATCH** | `0.0.X`      | Bug fixes, security patches, incorrect behavior corrections                      |
| `docs/<name>`                                      | **PATCH** | `0.0.X`      | Documentation improvements, README updates, guides                               |
| `chore/<name>`, `refactor/<name>`, `ci/<name>` | **PATCH** | `0.0.X`      | Toolchain updates, internal refactorings, CI/CD workflow adjustments             |

### Enforced Branch Regex Pattern

Branch names must strictly match the following regular expression:

```
^(feat|feature|fix|patch|major|breaking|docs|chore|refactor|ci)/[a-z0-9._-]+$
```

- Allowed prefixes: `feat/`, `feature/`, `fix/`, `patch/`, `major/`, `breaking/`, `docs/`, `chore/`, `refactor/`, `ci/`.
- Allowed branch characters after prefix: lowercase alphanumeric (`a-z0-9`), dots (`.`), underscores (`_`), and dashes (`-`).

---

## Left Hook & Git Hook Enforcement

Branch naming rules and quality standards are enforced both locally and in remote CI:

### 1. Left Hook / Pre-Commit Hook (`.githooks/pre-commit` & `lefthook.yml`)

- **Fails on Commit**: The branch naming policy is embedded in the **pre-commit** hook (Left Hook). If you attempt to make a commit on an unclassified branch (e.g. `test`, `dev`, `my-feature`) or directly on `main`, **the commit fails immediately**.
- **Clear Diagnostic Instructions**: When a commit fails, the hook prints actionable instructions and suggests the exact command to rename your branch:
  ```bash
  git branch -m feat/<your-branch-name>
  ```

### 2. Pre-Push Hook (`.githooks/pre-push` & `lefthook.yml`)

- Prevents direct pushes to `main`.
- Re-verifies branch naming compliance.
- Automatically executes all quality gates (`make check-all`) before allowing code to be pushed to remote.

### 3. Activating Hooks

To install both native Git hooks and Lefthook:

```bash
make install-hooks
```

This target:

1. Detects if [Lefthook](https://github.com/evilmartians/lefthook) is installed and runs `lefthook install`.
2. Copies `.githooks/pre-commit` and `.githooks/pre-push` into `.git/hooks/` and marks them executable.
3. Sets `git config core.hooksPath .githooks` as an active fallback.

---

## Automated Version Release Workflow

`makelib-py` features an automated continuous release pipeline defined in [`.github/workflows/release.yml`](.github/workflows/release.yml).

### Mandatory Release on Merge to `main`

Whenever new pull requests or changes land on `main`, the release pipeline runs **mandatorily**:

1. **Branch Classification & SemVer Calculation**: Evaluates the merged PR's source branch and commit history using `makelib.version` to determine whether to apply a **MAJOR**, **MINOR**, or **PATCH** bump.
2. **Quality Verification**: Executes `make check-all` on Python 3.14. If any gate fails, release publication is aborted immediately.
3. **Automated Tagging**: Updates `pyproject.toml`, commits the bumped version, tags the release (e.g., `v0.2.0`), and pushes the tag to GitHub.
4. **Artifact Packaging**: Builds source archives (`.tar.gz`) and wheels (`.whl`) via PEP 517 (`python -m build`).
5. **Cryptographic Checksums**: Computes `SHA256SUMS.txt` for package integrity verification.
6. **GitHub Release Publication**: Uses `softprops/action-gh-release` to create the release, compile release notes, and attach the built artifacts and checksums.

### Manual Semantic Version Bumping

Developers can also bump versions locally using the dedicated Make targets:

```bash
make bump-patch  # e.g. 0.1.0 -> 0.1.1
make bump-minor  # e.g. 0.1.0 -> 0.2.0
make bump-major  # e.g. 0.1.0 -> 1.0.0
```

### Consuming Pinned Releases in Downstream Projects

Downstream projects can pin to specific releases by updating `MAKELIB_REF` in their `Makefile`:

```makefile
# Pin to a tagged release for immutable, reproducible builds
MAKELIB_REF ?= v0.2.0

# Include core targets
-include $(MAKELIB_DIR)/core.mk
```

---

## Developer Workflow Standard

```bash
# 1. Create a properly classified feature branch
git checkout -b feat/my-enhancement

# 2. Develop and verify changes locally
make check-all

# 3. Commit (Left hook / pre-commit will validate branch name)
git commit -am "feat: implement enhancement"

# 4. Push (Pre-push hook will run check-all and verify branch name)
git push origin feat/my-enhancement

# 5. Open a Pull Request targeting main
# Remote CI validates branch-name-lint and quality gates.
# When merged, release.yml automatically releases the new version!
```

---

## CI/CD Pipeline (GitHub Actions)

`makelib-py` includes an automated GitHub Actions pipeline in [`.github/workflows/ci.yml`](.github/workflows/ci.yml) that executes across Python 3.14 on every push to `main` and all pull requests:

- **`branch-name-lint`**: Verifies that PR head branches follow the semantic naming convention (`^(feat|feature|fix|patch|major|breaking|docs|chore|refactor|ci)/[a-z0-9._-]+$`).
- **`quality-gate`**: Executes the full suite of checks (`make check-all`) on Python 3.14 with minimum test coverage enforced at 80%.

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
│   │   ├── ci.yml               # Branch-name linting and matrix quality gates
│   │   └── release.yml          # Automated SemVer release and distribution workflow
│   └── pull_request_template.md # PR quality gate checklist
├── .githooks/
│   ├── pre-commit               # Left hook enforcing branch naming policy on commit
│   └── pre-push                 # Hook preventing direct pushes and running check-all
├── src/
│   └── makelib/
│       ├── __init__.py          # Package initialization exposing config & version APIs
│       ├── config.py            # Configuration loader and validator (tomllib)
│       └── version.py           # Branch validation, SemVer parsing, and bump logic
├── tests/
│   ├── __init__.py
│   ├── test_config.py           # Tests for configuration validation
│   ├── test_makefile.py         # Tests for Makefile targets, sync, and hooks
│   └── test_version.py          # Tests for SemVer bumping and branch naming regex
├── core.mk                      # Core reusable Makefile targets and quality gates
├── pyproject.toml               # Golden toolchain configuration (Python 3.14)
├── downstream_template.mk       # Copy-paste bootstrap template for downstream projects
├── Makefile                     # Self-hosting Makefile including core.mk
├── lefthook.yml                 # Lefthook Git hook configuration
├── .gitignore                   # Standard Python and makelib ignore rules
├── LICENSE                      # Apache 2.0 License file
└── README.md                    # Comprehensive documentation and adoption guide
```

---

## License

This project is licensed under the apache License. See [LICENSE](LICENSE) for details.
