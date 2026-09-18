"""makelib - Standardized Make commands and toolchain configurations."""

from __future__ import annotations

from makelib.config import (
    get_coverage_threshold,
    get_mccabe_threshold,
    load_pyproject,
    validate_toolchain_config,
)

__version__ = "0.1.0"

__all__ = [
    "__version__",
    "get_coverage_threshold",
    "get_mccabe_threshold",
    "load_pyproject",
    "validate_toolchain_config",
]
