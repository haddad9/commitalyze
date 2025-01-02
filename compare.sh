WORK_DIR="$PWD"
COMPARED_FILE="$WORK_DIR/compared.md"
LAST_RUN_FILE="$WORK_DIR/last_run_date.txt"
TEMP_FILE="$WORK_DIR/temp_compared.md"
CURRENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")
GIT_DIR_SOURCE="/home/dat/work/rflow/"
GIT_DIR_TARGET="/home/dat/work/v2/"
BRANCH_SOURCE="main"
BRANCH_TARGET="dev"
CUSTOM_DATE='2024-12-31 10:00:00'
set -x

# Initialize compared.md if not present
if [[ ! -f "$COMPARED_FILE" ]]; then
    echo -e "## IMPLEMENTED\n\n## NOT IMPLEMENTED\n" > "$COMPARED_FILE"
fi

LAST_RUN_DATE="$CUSTOM_DATE"

# Fetch commits from the source repo
SOURCE_COMMITS=$(git -C "$GIT_DIR_SOURCE" log "$BRANCH_SOURCE" --since="$LAST_RUN_DATE" --until="$CURRENT_DATE" --pretty=format:"%H|%s|%ad" --date=short)

# Prepare temporary files for new commits
TEMP_IMPLEMENTED="$WORK_DIR/temp_implemented.md"
TEMP_NOT_IMPLEMENTED="$WORK_DIR/temp_not_implemented.md"
> "$TEMP_IMPLEMENTED"
> "$TEMP_NOT_IMPLEMENTED"

# Process each commit
while IFS='|' read -r commit_hash commit_message commit_date; do
    if git -C "$GIT_DIR_TARGET" log "$BRANCH_TARGET" --pretty=format:"%s" | grep -Fxq "$commit_message"; then
        if ! grep -Fq "- $commit_message: <$commit_hash> $commit_date" "$COMPARED_FILE"; then
            echo "- $commit_message: <$commit_hash> $commit_date" >> "$TEMP_IMPLEMENTED"
        fi
    else
        if ! grep -Fq "- $commit_message: <$commit_hash> $commit_date" "$COMPARED_FILE"; then
            echo "- $commit_message: <$commit_hash> $commit_date" >> "$TEMP_NOT_IMPLEMENTED"
        fi
    fi
done <<< "$SOURCE_COMMITS"

# Append new commits under their respective sections
awk -v implemented="$(cat "$TEMP_IMPLEMENTED")" \
    -v not_implemented="$(cat "$TEMP_NOT_IMPLEMENTED")" \
    'BEGIN { output = ""; in_section = ""; }
     /^## IMPLEMENTED$/ { in_section = "implemented"; output = output $0 "\n" implemented "\n"; next }
     /^## NOT IMPLEMENTED$/ { in_section = "not_implemented"; output = output $0 "\n" not_implemented "\n"; next }
     { if (in_section == "") output = output $0 "\n"; } 
     END { print output }' "$COMPARED_FILE" > "$TEMP_FILE"

mv "$TEMP_FILE" "$COMPARED_FILE"

# Save the current run date
echo "$CURRENT_DATE" > "$LAST_RUN_FILE"

# Clean up temporary files
rm -f "$TEMP_IMPLEMENTED" "$TEMP_NOT_IMPLEMENTED"
