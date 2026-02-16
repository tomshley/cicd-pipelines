#!/usr/bin/env python3
"""
Canonical reference implementation for CI/CD version composition in Python.

This module provides utilities to read a VERSION file and compose the version
with a CI build revision identifier, following PEP 440 normalization rules.

Contract:
- Walk up directory tree from current working directory to find VERSION file
- Read TOMSHLEY_CICD_BUILD_REVISION from environment
- Normalize suffixes for PEP 440 compatibility (-SNAPSHOT → .dev0, -rc.N → rcN)
- Compose version with local version identifier if revision is non-empty
- Provide both importable API and CLI interface

@see https://gitlab.com/tomshley/tomshley-oss-dependencies/-/tree/main/cicd-pipelines/common/adapter-specs/
"""

import os
import sys
import re
from pathlib import Path
from typing import Optional


def find_version_file(start_dir: Optional[Path] = None) -> Optional[Path]:
    """
    Find VERSION file by walking up directory tree.
    
    Args:
        start_dir: Directory to start searching from (defaults to current working directory)
        
    Returns:
        Path to VERSION file, or None if not found
    """
    if start_dir is None:
        start_dir = Path.cwd()
    
    current_dir = start_dir.resolve()
    
    while current_dir != current_dir.parent:
        version_path = current_dir / 'VERSION'
        if version_path.exists():
            return version_path
        current_dir = current_dir.parent
    
    # Check root directory one last time
    version_path = current_dir / 'VERSION'
    if version_path.exists():
        return version_path
    
    return None


def normalize_version(version: str) -> str:
    """
    Normalize version suffix for PEP 440 compatibility.
    
    Args:
        version: Raw version string
        
    Returns:
        Normalized version string
        
    Examples:
        "1.2.3-SNAPSHOT" → "1.2.3.dev0"
        "1.2.3-rc.1" → "1.2.3rc1"
        "1.2.3" → "1.2.3"
    """
    version = version.strip()
    
    # Convert -SNAPSHOT to .dev0 for PEP 440
    if version.endswith('-SNAPSHOT'):
        version = version[:-len('-SNAPSHOT')] + '.dev0'
    
    # Convert -rc.N to rcN for PEP 440
    rc_match = re.search(r'-rc\.(\d+)$', version)
    if rc_match:
        rc_num = rc_match.group(1)
        version = version[:rc_match.start()] + f'rc{rc_num}'
    
    return version


def compose_version(base_version: str, revision: Optional[str] = None) -> str:
    """
    Compose version with revision identifier.
    
    Args:
        base_version: Base version from VERSION file
        revision: Revision from TOMSHLEY_CICD_BUILD_REVISION
        
    Returns:
        Composed version string
        
    Examples:
        base_version="1.2.3", revision=None → "1.2.3.dev0" (if -SNAPSHOT)
        base_version="1.2.3", revision="develop-abc1234" → "1.2.3.dev0+develop.abc1234"
        base_version="1.2.3", revision="" → "1.2.3"
    """
    normalized_base = normalize_version(base_version)
    
    if not revision or not revision.strip():
        return normalized_base
    
    # PEP 440 local version identifier uses + separator
    # Replace hyphens in revision with dots for PEP 440 compatibility
    revision_normalized = revision.strip().replace('-', '.')
    
    return f"{normalized_base}+{revision_normalized}"


def resolve_version(start_dir: Optional[Path] = None) -> str:
    """
    Resolve version from VERSION file and environment.
    
    Args:
        start_dir: Directory to start searching from (defaults to current working directory)
        
    Returns:
        Composed version string
        
    Raises:
        FileNotFoundError: If VERSION file is not found
    """
    version_file = find_version_file(start_dir)
    
    if not version_file:
        raise FileNotFoundError("VERSION file not found")
    
    base_version = version_file.read_text().strip()
    revision = os.environ.get('TOMSHLEY_CICD_BUILD_REVISION', '')
    
    return compose_version(base_version, revision)


def main():
    """CLI interface."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Resolve version from VERSION file and CI environment')
    parser.add_argument('--start-dir', type=Path, help='Directory to start searching from')
    parser.add_argument('--base-only', action='store_true', help='Only return base version (no revision)')
    
    args = parser.parse_args()
    
    try:
        version_file = find_version_file(args.start_dir)
        
        if not version_file:
            print(f"Error: VERSION file not found", file=sys.stderr)
            sys.exit(1)
        
        base_version = version_file.read_text().strip()
        
        if args.base_only:
            print(normalize_version(base_version))
        else:
            revision = os.environ.get('TOMSHLEY_CICD_BUILD_REVISION', '')
            composed = compose_version(base_version, revision)
            print(composed)
    
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
