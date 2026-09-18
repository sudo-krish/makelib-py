"""Semantic versioning and branch classification engine for makelib-py."""

from __future__ import annotations

import re
from pathlib import Path

BRANCH_REGEX = (
    r"^(feat|feature|fix|patch|major|breaking|docs|chore|refactor|ci)/[a-z0-9._-]+$"
)
SEMVER_REGEX = r"^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$"


class VersionError(Exception):
    """Raised when version parsing or bumping fails."""


def is_valid_branch_name(branch: str) -> bool:
    """Validate branch name against the strict classification schema.

    Allowed prefixes:
      - feat/, feature/   (minor changes)
      - major/, breaking/ (major breaking changes)
      - fix/, patch/, docs/, chore/, refactor/, ci/ (patch changes)

    Args:
        branch: The Git branch name to validate.

    Returns:
        True if compliant, False otherwise.
    """
    if branch == "main":
        return True
    return bool(re.match(BRANCH_REGEX, branch))


def classify_branch_bump(branch: str) -> str:
    """Classify SemVer bump type based on branch prefix.

    Args:
        branch: Git branch name (e.g. 'feat/add-auth', 'major/v2').

    Returns:
        One of 'major', 'minor', or 'patch'.
    """
    clean_branch = branch.strip()
    if clean_branch.startswith(("major/", "breaking/")):
        return "major"
    if clean_branch.startswith(("feat/", "feature/")):
        return "minor"
    return "patch"


def parse_version(version_str: str) -> tuple[int, int, int]:
    """Parse a semantic version string into (major, minor, patch) integers.

    Args:
        version_str: Version string (e.g. '0.1.0' or 'v1.2.3').

    Returns:
        Tuple of (major, minor, patch).

    Raises:
        VersionError: If version string does not conform to SemVer.
    """
    match = re.match(SEMVER_REGEX, version_str.strip())
    if not match:
        raise VersionError(
            f"Invalid SemVer string '{version_str}'. Expected format: 'X.Y.Z'"
        )
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


def bump_version(version_str: str, bump_type: str) -> str:
    """Increment a semantic version by major, minor, or patch part.

    Args:
        version_str: Current version (e.g. '0.1.0').
        bump_type: One of 'major', 'minor', or 'patch'.

    Returns:
        New bumped version string (e.g. '0.2.0').

    Raises:
        VersionError: If bump_type is unknown or version is invalid.
    """
    major, minor, patch = parse_version(version_str)
    normalized = bump_type.lower().strip()

    if normalized == "major":
        return f"{major + 1}.0.0"
    if normalized == "minor":
        return f"{major}.{minor + 1}.0"
    if normalized == "patch":
        return f"{major}.{minor}.{patch + 1}"

    raise VersionError(
        f"Unknown bump type '{bump_type}'. Must be 'major', 'minor', or 'patch'."
    )


def update_project_version(
    new_version: str,
    pyproject_path: Path | str = "pyproject.toml",
    init_path: Path | str = "src/makelib/__init__.py",
) -> None:
    """Update version declarations in pyproject.toml and __init__.py.

    Args:
        new_version: New version string (e.g. '0.2.0').
        pyproject_path: Path to pyproject.toml.
        init_path: Path to __init__.py.
    """
    p_path = Path(pyproject_path)
    if p_path.is_file():
        content = p_path.read_text(encoding="utf-8")
        updated = re.sub(
            r'^version\s*=\s*".*?"',
            f'version = "{new_version}"',
            content,
            flags=re.MULTILINE,
        )
        p_path.write_text(updated, encoding="utf-8")

    i_path = Path(init_path)
    if i_path.is_file():
        content = i_path.read_text(encoding="utf-8")
        updated = re.sub(
            r'^__version__\s*=\s*".*?"',
            f'__version__ = "{new_version}"',
            content,
            flags=re.MULTILINE,
        )
        i_path.write_text(updated, encoding="utf-8")
