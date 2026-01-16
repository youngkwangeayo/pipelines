#!/bin/bash
set -euo pipefail

# Convert key-value env file to JSON array format for ECS environment variables

# =============== 유효성 검사 시작 ===============
# Read filename from stdin or argument
if [ $# -eq 1 ]; then
    filename="$1"
else
    read -r filename
fi

# Validate file existence
if [ ! -f "$filename" ]; then
    echo "Error: File '$filename' not found" >&2
    exit 1
fi
# =============== 유효성 검사 종료 ===============


# Begin JSON array
echo "["

first_line=true
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    # Match KEY=VALUE pairs
    if [[ "$line" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"

        # Trim key
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Add comma if not first
        if [ "$first_line" = true ]; then
            first_line=false
        else
            echo ","
        fi

        # Escape double quotes in value
        escaped_value=$(echo "$value" | sed 's/"/\\"/g')
        printf '  { "name": "%s", "value": "%s" }' "$key" "$escaped_value"
    fi
done < "$filename"

# Close array
echo ""
echo "]"
