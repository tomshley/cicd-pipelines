#!/usr/bin/env bash
# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Creates a temp git repo for testing toolbox scripts.
# Prints the path to the test repo root.
# The repo has:
#   - A VERSION file containing "0.4.20"
#   - An initial commit on main
#   - A develop branch off main
#   - A bare clone at <repo>-remote.git (used as "origin" for push testing)
set -euo pipefail

TEST_DIR=$(mktemp -d)
REPO_DIR="${TEST_DIR}/repo"
REMOTE_DIR="${TEST_DIR}/repo-remote.git"

# Create the bare remote first
git init --bare "$REMOTE_DIR" >/dev/null 2>&1

# Create the working repo
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git init >/dev/null 2>&1
git config user.email "test@tomshley.com"
git config user.name "Test Runner"

# Initial commit on main
echo "0.4.20" > VERSION
git add VERSION
git commit -m "initial commit" >/dev/null 2>&1

# Rename default branch to main (in case git defaults to master)
git branch -M main

# Add the bare clone as origin and push
git remote add origin "$REMOTE_DIR"
git push origin main >/dev/null 2>&1

# Create develop branch
git checkout -b develop >/dev/null 2>&1
git push origin develop >/dev/null 2>&1

# Print the repo path for the caller
echo "$REPO_DIR"
