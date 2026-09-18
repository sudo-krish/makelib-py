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


def test_sync_config_simulation(tmp_path: Path) -> None:
    """Simulate downstream project syncing pyproject.toml from .makelib/."""
    # Create downstream directory structure
    downstream = tmp_path / "downstream"
    downstream.mkdir()
    makelib_dir = downstream / ".makelib"
    makelib_dir.mkdir()

    # Place golden pyproject.toml in .makelib
    golden_file = ROOT_DIR / "pyproject.toml"
    shutil.copy(golden_file, makelib_dir / "pyproject.toml")

    # Initial sync
    dest_config = downstream / "pyproject.toml"
    assert not dest_config.exists()
    shutil.copy(makelib_dir / "pyproject.toml", dest_config)
    assert dest_config.exists()

    # Modify downstream pyproject.toml and perform simulated resync with backup
    dest_config.write_text("# custom edit\n", encoding="utf-8")
    backup_file = downstream / "pyproject.toml.bak"
    shutil.copy(dest_config, backup_file)
    shutil.copy(makelib_dir / "pyproject.toml", dest_config)

    assert backup_file.read_text(encoding="utf-8") == "# custom edit\n"
    assert "makelib-py" in dest_config.read_text(encoding="utf-8")
