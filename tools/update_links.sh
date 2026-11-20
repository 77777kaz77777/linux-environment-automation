#!/bin/bash

# Base GitHub Blob URL for the linux-environment-automation repository
BASE_URL="https://github.com/77777kaz77777/linux-environment-automation/blob/main"

echo "Scanning Markdown files for relative script/config links..."

# Find all .md files and update links inline
# - (?!http) ignores links that are already absolute web URLs
# - (?:\./)? optionally matches and removes leading "./" for cleaner URLs
# - Targets .sh, .py, .yaml, .yml, .conf, and .toml files
find . -type f -name "*.md" -exec perl -pi -e \
  's|\]\((?!http)(?:\./)?([^)]+\.(sh|py|yaml|yml|conf|toml))\)|\]('"$BASE_URL"'/$1)|g' {} +

echo "Link conversion complete. Verify changes with 'git diff'."
