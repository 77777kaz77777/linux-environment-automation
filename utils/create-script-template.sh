#!/usr/bin/env bash
# Interactive generator that scaffolds a new, executable Bash script with standard headers and strict error handling flags.

set -euo pipefail

# Prompt user for the filename
read -rp "Enter desired script name (e.g. system-cleanup): " raw_filename

# Sanitize input: replace spaces with hyphens, remove invalid characters, strip trailing .sh
base_name=$(echo "${raw_filename%.sh}" | tr -s ' ' '-' | tr -cd '[:alnum:]_-')

# Check if input resulted in an empty string after sanitization
if [[ -z "$base_name" ]]; then
  echo "Error: Filename cannot be empty or contain only invalid characters." >&2
  exit 1
fi

filename="${base_name}.sh"

# Check if the file already exists
if [[ -f "$filename" ]]; then
  read -rp "File '$filename' already exists. Overwrite? (y/N): " overwrite
  if [[ ! "$overwrite" =~ ^[yY]$ ]]; then
    echo "Operation canceled. Exiting."
    exit 0
  fi
fi

# Write shebang and production-grade script header
# Using unquoted EOF to inject variables during creation, escaping runtime variables like \$EUID
cat <<EOF >"$filename"
#!/usr/bin/env bash
# ==============================================================================
# Script Name:  $filename
# Description:  
# Created:      $(date +%Y-%m-%d)
# ==============================================================================

# Exit immediately on error, unset variable, or piped command failure
set -euo pipefail

# Require root privileges (Uncomment if needed)
# if [[ "\$EUID" -ne 0 ]]; then
#   echo "Error: This script must be run as root or via sudo." >&2
#   exit 1
# fi

EOF

# Make the new script executable
chmod +x "$filename"

echo "--------------------------------------------------"
echo "Success: Created executable script '$filename'"
echo "Path: $(pwd)/$filename"
echo "--------------------------------------------------"

# Automatically open the generated script
if command -v subl &>/dev/null; then
  subl "$filename"
elif [[ -n "${EDITOR:-}" ]]; then
  "$EDITOR" "$filename"
fi
