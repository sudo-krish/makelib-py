"""Toolchain configuration validator for makelib-py."""

from __future__ import annotations

from pathlib import Path
from typing import Any

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    try:
        import tomli as tomllib  # type: ignore[no-redef]
    except ModuleNotFoundError:  # pragma: no cover
        tomllib = None  # type: ignore[assignment]


class ConfigurationError(Exception):
    """Raised when pyproject.toml is missing or invalid."""


def load_pyproject(path: str | Path = "pyproject.toml") -> dict[str, Any]:
    """Load and parse a pyproject.toml file.

    Args:
        path: Path to the pyproject.toml file.

    Returns:
        Parsed TOML contents as a dictionary.

    Raises:
        ConfigurationError: If the file does not exist or TOML parsing fails.
    """
    target = Path(path)
    if not target.is_file():
        raise ConfigurationError(f"Configuration file not found: {target}")

    if tomllib is None:
        raise ConfigurationError(
            "No TOML parser available. Install 'tomli' on Python < 3.11 or use Python 3.11+."
        )

    try:
        with target.open("rb") as f:
            return tomllib.load(f)
    except Exception as exc:
        raise ConfigurationError(f"Failed to parse {target}: {exc}") from exc


def validate_toolchain_config(config: dict[str, Any]) -> list[str]:
    """Validate that required toolchain sections and parameters are defined.

    Checks for:
      - tool.ruff and required lint rules (I, B, C901)
      - tool.mypy strict mode
      - tool.pytest.ini_options testpaths
      - tool.coverage.report fail_under threshold

    Args:
        config: Parsed pyproject.toml dictionary.

    Returns:
        A list of validation warning/error messages. Empty list if fully valid.
    """
    issues: list[str] = []
    tools = config.get("tool", {})

    # 1. Ruff checks
    ruff = tools.get("ruff", {})
    lint = ruff.get("lint", {})
    rules = set(lint.get("select", []))
    required_rules = {"I", "B", "C901"}
    missing_rules = required_rules - rules
    if missing_rules:
        issues.append(f"Missing required Ruff lint rules in tool.ruff.lint.select: {sorted(missing_rules)}")

    mccabe = lint.get("mccabe", {})
    if "max-complexity" not in mccabe:
        issues.append("Missing tool.ruff.lint.mccabe.max-complexity configuration")

    # 2. Mypy checks
    mypy = tools.get("mypy", {})
    if not mypy.get("strict", False):
        issues.append("Mypy strict mode is not enabled (tool.mypy.strict must be true)")

    # 3. Pytest checks
    pytest = tools.get("pytest", {}).get("ini_options", {})
    if not pytest.get("testpaths"):
        issues.append("Pytest testpaths is not specified in tool.pytest.ini_options.testpaths")

    # 4. Coverage checks
    cov_report = tools.get("coverage", {}).get("report", {})
    if "fail_under" not in cov_report:
        issues.append("Coverage fail_under threshold is missing in tool.coverage.report.fail_under")

    return issues


def get_coverage_threshold(config: dict[str, Any], default: int = 80) -> int:
    """Retrieve the configured coverage threshold.

    Args:
        config: Parsed pyproject.toml dictionary.
        default: Default fallback threshold.

    Returns:
        Coverage threshold percentage as an integer.
    """
    cov_report = config.get("tool", {}).get("coverage", {}).get("report", {})
    val = cov_report.get("fail_under", default)
    try:
        return int(val)
    except (ValueError, TypeError):
        return default


def get_mccabe_threshold(config: dict[str, Any], default: int = 10) -> int:
    """Retrieve the configured McCabe cyclomatic complexity limit.

    Args:
        config: Parsed pyproject.toml dictionary.
        default: Default fallback complexity threshold.

    Returns:
        McCabe complexity threshold as an integer.
    """
    mccabe = config.get("tool", {}).get("ruff", {}).get("lint", {}).get("mccabe", {})
    val = mccabe.get("max-complexity", default)
    try:
        return int(val)
    except (ValueError, TypeError):
        return default
