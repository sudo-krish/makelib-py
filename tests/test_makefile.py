"""Tests validating Makefiles, targets, and configuration syncing."""

from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent


def test_required_files_exist() -> None:
    """Verify that all core makelib deliverables exist in the repository root."""
    expected_files = [
        "core.mk",
        "pyproject.toml",
        "template_pyproject.toml",
        "downstream_template.mk",
        "Makefile",
        "README.md",
        ".gitignore",
    ]
    for filename in expected_files:
        path = ROOT_DIR / filename
        assert path.is_file(), f"Expected file {filename} does not exist at {path}"


def test_core_mk_contains_required_targets() -> None:
    """Verify core.mk defines all mandatory targets and self-documenting comments."""
    core_mk = (ROOT_DIR / "core.mk").read_text(encoding="utf-8")

    required_targets = [
        "help",
        "sync",
        "format",
        "lint",
        "type-check",
        "smell",
        "audit",
        "secret-scan",
        "license-check",
        "test",
        "check-all",
        "clean",
        "build",
        "bump-patch",
        "bump-minor",
        "bump-major",
        "sync-config",
        "install-hooks",
    ]

    for target in required_targets:
        pattern = rf"^{target}:.*?##\s+(.+)$"
        match = re.search(pattern, core_mk, re.MULTILINE)
        assert match is not None, (
            f"Target '{target}' missing or not self-documented in core.mk"
        )


def test_core_mk_extensible_variables() -> None:
    """Verify core.mk exposes configurable variables with ?= assignment."""
    core_mk = (ROOT_DIR / "core.mk").read_text(encoding="utf-8")
    expected_vars = [
        "SRC_DIR",
        "TEST_DIR",
        "MIN_COVERAGE",
        "MAX_COMPLEXITY",
        "PYTHON",
        "UV",
        "RUFF",
        "MYPY",
        "BANDIT",
        "PIP_AUDIT",
        "DETECT_SECRETS",
        "PIP_LICENSES",
        "PYTEST",
        "CONFIG_FILE",
    ]
    for var in expected_vars:
        assert re.search(rf"^{var}\s*\?=", core_mk, re.MULTILINE) is not None, (
            f"Variable {var} not conditionally assigned in core.mk"
        )


def test_downstream_template_contains_boilerplate() -> None:
    """Verify downstream_template.mk contains bootstrap variables & targets."""
    template = (ROOT_DIR / "downstream_template.mk").read_text(encoding="utf-8")
    assert "MAKELIB_REPO ?=" in template
    assert "MAKELIB_DIR  ?=" in template
    assert "init-makelib:" in template
    assert "update-makelib:" in template
    assert "-include $(MAKELIB_DIR)/core.mk" in template
    assert '[ ! -f "pyproject.toml" ]' in template
    assert "template_pyproject.toml" in template
    assert "preserving project metadata" in template


def test_init_makelib_simulation(tmp_path: Path) -> None:
    """Simulate init-makelib behavior: bootstrapping template vs preserving config."""
    downstream = tmp_path / "downstream"
    downstream.mkdir()
    makelib_dir = downstream / ".makelib"
    makelib_dir.mkdir()

    # Place template_pyproject.toml in .makelib
    template_file = ROOT_DIR / "template_pyproject.toml"
    shutil.copy(template_file, makelib_dir / "template_pyproject.toml")

    # Case 1: Fresh project without pyproject.toml -> bootstraps template config
    dest_config = downstream / "pyproject.toml"
    assert not dest_config.exists()
    if not dest_config.is_file():
        shutil.copy(makelib_dir / "template_pyproject.toml", dest_config)
    assert dest_config.exists()
    assert "my-service" in dest_config.read_text(encoding="utf-8")
    assert "dependency-groups" in dest_config.read_text(encoding="utf-8")

    # Case 2: Project already has pyproject.toml -> preserves existing metadata
    custom_content = '[project]\nname = "my-custom-service"\nversion = "1.0.0"\n'
    dest_config.write_text(custom_content, encoding="utf-8")
    if not dest_config.is_file():
        shutil.copy(makelib_dir / "template_pyproject.toml", dest_config)
    assert dest_config.read_text(encoding="utf-8") == custom_content


def test_sync_config_simulation(tmp_path: Path) -> None:
    """Simulate downstream safe sync-config: never damage existing pyproject.toml."""
    downstream = tmp_path / "downstream"
    downstream.mkdir()
    makelib_dir = downstream / ".makelib"
    makelib_dir.mkdir()

    # Place template_pyproject.toml in .makelib
    template_file = ROOT_DIR / "template_pyproject.toml"
    shutil.copy(template_file, makelib_dir / "template_pyproject.toml")

    # If pyproject.toml does not exist, installs template
    dest_config = downstream / "pyproject.toml"
    assert not dest_config.exists()
    if not dest_config.is_file():
        shutil.copy(makelib_dir / "template_pyproject.toml", dest_config)
    assert dest_config.exists()

    # If pyproject.toml exists with custom content, sync-config preserves it
    custom_content = '[project]\nname = "custom-app"\ndependencies = ["requests"]\n'
    dest_config.write_text(custom_content, encoding="utf-8")

    # Simulated safe sync-config: only install if not exists
    if not dest_config.is_file():
        shutil.copy(makelib_dir / "template_pyproject.toml", dest_config)
    assert dest_config.read_text(encoding="utf-8") == custom_content


def test_hooks_and_lefthook_contain_branch_validation() -> None:
    """Verify that both native git hooks and lefthook enforce branch naming."""
    pre_commit = (ROOT_DIR / ".githooks" / "pre-commit").read_text(encoding="utf-8")
    assert "BRANCH_REGEX" in pre_commit
    assert 'PROTECTED_BRANCH="main"' in pre_commit
    assert "major|breaking" in pre_commit

    pre_push = (ROOT_DIR / ".githooks" / "pre-push").read_text(encoding="utf-8")
    assert "BRANCH_REGEX" in pre_push
    assert "check-all" in pre_push

    lefthook_yml = (ROOT_DIR / "lefthook.yml").read_text(encoding="utf-8")
    assert "pre-commit:" in lefthook_yml
    assert "branch-name-lint:" in lefthook_yml
    assert "pre-push:" in lefthook_yml
