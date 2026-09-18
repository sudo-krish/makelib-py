"""Unit tests for makelib.config module."""

from __future__ import annotations

from pathlib import Path

import pytest

from makelib.config import (
    ConfigurationError,
    get_coverage_threshold,
    get_mccabe_threshold,
    load_pyproject,
    validate_toolchain_config,
)


def test_load_real_pyproject() -> None:
    """Ensure the repository's own pyproject.toml loads without errors."""
    config = load_pyproject("pyproject.toml")
    assert isinstance(config, dict)
    assert "tool" in config
    assert "ruff" in config["tool"]


def test_load_nonexistent_pyproject(tmp_path: Path) -> None:
    """Ensure ConfigurationError is raised when file does not exist."""
    missing = tmp_path / "nonexistent.toml"
    with pytest.raises(ConfigurationError, match="Configuration file not found"):
        load_pyproject(missing)


def test_load_invalid_toml(tmp_path: Path) -> None:
    """Ensure ConfigurationError is raised on invalid TOML syntax."""
    bad_toml = tmp_path / "bad.toml"
    bad_toml.write_text("[section\ninvalid = ", encoding="utf-8")
    with pytest.raises(ConfigurationError, match="Failed to parse"):
        load_pyproject(bad_toml)


def test_validate_golden_pyproject() -> None:
    """Verify that the golden pyproject.toml passes all toolchain checks."""
    config = load_pyproject("pyproject.toml")
    issues = validate_toolchain_config(config)
    assert issues == [], f"Golden pyproject.toml had validation issues: {issues}"


def test_validate_missing_sections() -> None:
    """Verify that validate_toolchain_config detects missing requirements."""
    empty_config: dict[str, object] = {}
    issues = validate_toolchain_config(empty_config)
    assert any("Ruff lint rules" in issue for issue in issues)
    assert any("mccabe.max-complexity" in issue for issue in issues)
    assert any("Mypy strict mode" in issue for issue in issues)
    assert any("Pytest testpaths" in issue for issue in issues)
    assert any("Coverage fail_under" in issue for issue in issues)


def test_validate_partial_ruff_rules() -> None:
    """Verify detection of missing individual rules in Ruff select list."""
    config = {
        "tool": {
            "ruff": {"lint": {"select": ["E", "W", "F"], "mccabe": {"max-complexity": 10}}},
            "mypy": {"strict": True},
            "pytest": {"ini_options": {"testpaths": ["tests"]}},
            "coverage": {"report": {"fail_under": 80}},
        }
    }
    issues = validate_toolchain_config(config)
    assert len(issues) == 1
    assert "Missing required Ruff lint rules" in issues[0]


def test_get_thresholds() -> None:
    """Verify extraction of numeric thresholds and fallbacks."""
    config = {
        "tool": {
            "coverage": {"report": {"fail_under": 85}},
            "ruff": {"lint": {"mccabe": {"max-complexity": 12}}},
        }
    }
    assert get_coverage_threshold(config) == 85
    assert get_mccabe_threshold(config) == 12

    # Test fallbacks with invalid values
    bad_config = {
        "tool": {
            "coverage": {"report": {"fail_under": "not-an-int"}},
            "ruff": {"lint": {"mccabe": {"max-complexity": None}}},
        }
    }
    assert get_coverage_threshold(bad_config, default=75) == 75
    assert get_mccabe_threshold(bad_config, default=15) == 15
