"""makelib - Standardized Make commands and toolchain configurations."""

from __future__ import annotations

from makelib.config import (
    get_coverage_threshold,
    get_mccabe_threshold,
    load_pyproject,
    validate_toolchain_config,
)
from makelib.version import (
    bump_version,
    classify_branch_bump,
    is_valid_branch_name,
    parse_version,
    update_project_version,
)

__version__ = "0.2.0"

__all__ = [
    "__version__",
    "bump_version",
    "classify_branch_bump",
    "get_coverage_threshold",
    "get_mccabe_threshold",
    "is_valid_branch_name",
    "load_pyproject",
    "parse_version",
    "update_project_version",
    "validate_toolchain_config",
]
