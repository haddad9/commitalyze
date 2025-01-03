#!/bin/bash

# Define the working directory
WORK_DIR="$PWD"
OUTPUT_FILE="$WORK_DIR/index.html"
COMMITS_FILE="$WORK_DIR/commits.html"
LAST_RUN_FILE="$WORK_DIR/last_run_date.txt"
GIT_DIR_SOURCE="" # Git repository target
GIT_DIR_TARGET="" # Git repository target
API_TOKEN="" # put your LLM api token here 
PROMPT_FILE="./prompt.txt"
PROMPT=$(cat "$PROMPT_FILE")
CUSTOM_DATE='' # put your custom date to start
BRANCH_TARGET='' # branch name for target git dir (e.g 'main')
BRANCH_SOURCE='' # branch name for source git dir (e.g 'main')

# get the last run date and backup previous index.html
if [[  -s "$LAST_RUN_FILE" ]]; then
    LAST_RUN_DATE=$(cat $LAST_RUN_FILE)
    if [[ -f $OUTPUT_FILE ]]; then 
        mv $OUTPUT_FILE "$OUTPUT_FILE.$( echo $LAST_RUN_DATE | sed 's/ /_/; s/:/_/g')"
    fi

else
    if [[ -f $OUTPUT_FILE ]]; then 
        mv $OUTPUT_FILE "$OUTPUT_FILE.$( echo $(date +"%Y-%m-%d %H:%M:%S") | sed 's/ /_/; s/:/_/g')"
    fi
    LAST_RUN_DATE=$CUSTOM_DATE
fi

# Get the current date
CURRENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Prepare the output file
echo -e "<hr>" >> "$OUTPUT_FILE"
echo -e "Commits from $LAST_RUN_DATE to $CURRENT_DATE\n" >> "$OUTPUT_FILE"
echo -e "<hr>" >> "$OUTPUT_FILE"

# fetch latest commits
git -C $GIT_DIR_SOURCE fetch && git -C $GIT_DIR_SOURCE pull origin $BRANCH_SOURCE
git -C $GIT_DIR_TARGET fetch && git -C $GIT_DIR_TARGET pull origin $BRANCH_TARGET

# Fetch commits within the range
COMMITS=$(git -C $GIT_DIR_SOURCE log --since="$LAST_RUN_DATE" --until="$CURRENT_DATE" --oneline)
if [[ -z "$COMMITS" ]]; then
    echo "No commits found between $LAST_RUN_DATE and $CURRENT_DATE." >> "$OUTPUT_FILE"
    echo "No commits found between $LAST_RUN_DATE and $CURRENT_DATE."
    exit 1
else
    # Append the list of commits as clickable links
    echo "<h1>Commit List</h1>" >> "$OUTPUT_FILE"
    echo "<h1>Commit List</h1>" >> "$COMMITS_FILE"
    echo "<ul>" >> "$OUTPUT_FILE"
    echo "<ul>" >> "$COMMITS_FILE"
    echo "$COMMITS" | awk '{print $1}' | while read -r commit; do
        # Get the full commit message for the current commit
        commit_message=$(git -C $GIT_DIR_SOURCE log -1 --pretty=format:"%s" "$commit")
        # Create a clickable link with the commit ID as the anchor and the commit message as the link text
        echo "<li><a href=\"#${commit}\">${commit} ${commit_message}</a></li>" >> "$OUTPUT_FILE"
        echo "<li><a href=\"#${commit}\">${commit} ${commit_message}</a></li>" >> "$COMMITS_FILE"
    done
    echo "</ul>" >> "$OUTPUT_FILE"
    echo "</ul>" >> "$COMMITS_FILE"

    echo -e "<hr>" >> "$COMMITS_FILE"

    # Prepare the commit list to send to the LLM API for classification
    COMMIT_LIST_HTML=$(cat $COMMITS_FILE)


# Replace the placeholder with the actual commit list and escape special characters
JSON_PAYLOAD=$(jq -n --arg content "$(echo "$COMMIT_LIST_HTML" | jq -Rsa .)" --argjson prompts "$PROMPT" '
    $prompts | .messages[1].content = $content
')

    if [[ -z "$COMMIT_LIST_HTML" || -z $JSON_PAYLOAD ]]; then 
        exit 1
    fi
    # Send the commit list to the LLM API for classification
    RESPONSE=$(curl -s https://api.deepseek.com/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_TOKEN" \
        -d "$JSON_PAYLOAD")
    # Extract and append the classified commit categories from the response
    if [[ -z $RESPONSE ]]; then
        exit 1
    fi

   # log response to file txt 
    echo $CURRENT_DATE >> './response.log'
    echo '==================' >> './response.log'
    echo $RESPONSE >> 'response.log'
    echo '==================' >> 'response.log'

    CLASSIFIED_COMMITS=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')
    echo "<hr>" >> $OUTPUT_FILE
    echo "<h2>Classified Commits</h2>" >> "$OUTPUT_FILE"
    echo "<div>$CLASSIFIED_COMMITS</div>" >> "$OUTPUT_FILE"

    # Append detailed information for each commit
    echo -e "<hr>" >> "$OUTPUT_FILE"
    echo "$COMMITS" | awk '{print $1}' | while read -r commit; do
        echo "<div id=\"$commit\"></div>" >> "$OUTPUT_FILE"
        echo "<h2>$commit</h2>" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"

        # Commit message
        echo "<p><strong>Message:</strong> $(git -C $GIT_DIR_SOURCE log -1 --pretty=format:"%s" "$commit")</p>" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"

        # Commit details
        echo "<p><strong>Details:</strong></p>" >> "$OUTPUT_FILE"
        echo "<pre><code>" >> "$OUTPUT_FILE"
        git -C $GIT_DIR_SOURCE show "$commit" | while read -r line; do
            if [[ "$line" =~ ^diff\ --git ]]; then
                # Extract filenames and style them as blocks
                file_a=$(echo "$line" | awk '{print $3}')
                file_b=$(echo "$line" | awk '{print $4}')
                echo "<div style=\"background-color: #ffff00; color: #000000; display: inline-block; padding: 2px 8px; margin: 2px 4px; border-radius: 4px;\">$file_a</div>" >> "$OUTPUT_FILE"
                echo "<div style=\"background-color: #ffff00; color: #000000; display: inline-block; padding: 2px 8px; margin: 2px 4px; border-radius: 4px;\">$file_b</div>" >> "$OUTPUT_FILE"
            elif [[ "$line" =~ ^index ]]; then
                # Highlight `index` line
                echo "<span style=\"background-color: #f0f0f0; padding: 2px 8px; border-radius: 4px;\">$line</span>" >> "$OUTPUT_FILE"
            elif [[ "$line" =~ ^--- ]]; then
                # Highlight `---` line
                echo "<span style=\"background-color: #f8d7da; color: #d73a49; padding: 2px 8px; border-radius: 4px;\">$line</span>" >> "$OUTPUT_FILE"
            elif [[ "$line" =~ ^\+\+\+ ]]; then
                # Highlight `+++` line
                echo "<span style=\"background-color: #d4edda; color: #28a745; padding: 2px 8px; border-radius: 4px;\">$line</span>" >> "$OUTPUT_FILE"
            elif [[ "$line" =~ ^\+ ]]; then
                # Highlight added lines
                echo "<span style=\"background-color: #d4edda; color: #28a745;\">$line</span>" >> "$OUTPUT_FILE"
            elif [[ "$line" =~ ^- ]]; then
                # Highlight removed lines
                echo "<span style=\"background-color: #f8d7da; color: #d73a49;\">$line</span>" >> "$OUTPUT_FILE"
            else
                # Default formatting for other lines
                escaped_line=$(echo "$line" | awk '{
                    gsub(/&/, "\\&amp;");
                    gsub(/</, "\\&lt;");
                    gsub(/>/, "\\&gt;");
                    gsub(/"/, "\\&quot;");
                    gsub(/'\''/, "&#39;");
                    print
                }')
                echo "$escaped_line" >> "$OUTPUT_FILE"
            fi
        done
        echo "</code></pre>" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    done
fi

# Save the current date only after successful processing
echo "$CURRENT_DATE" > "$LAST_RUN_FILE"

echo "Commits from $LAST_RUN_DATE to $CURRENT_DATE have been processed."

set -x
echo "Anaylzing implemented commits from SOURCE to the TARGET"

# Define the file to log migrated commits
MIGRATED_FILE="$WORK_DIR/migrated.md"
echo "# Migrated Commits from Source to Target" > "$MIGRATED_FILE"
echo "Commits from $BRANCH_SOURCE (Source) already implemented in $BRANCH_TARGET (Target)" >> "$MIGRATED_FILE"
echo "Analyzing commits from $LAST_RUN_DATE to $CURRENT_DATE" >> "$MIGRATED_FILE"
echo "" >> "$MIGRATED_FILE"

# Get the commit messages from the source branch within the designated range
SOURCE_COMMIT_MESSAGES=$(git -C $GIT_DIR_SOURCE log $BRANCH_SOURCE --since="$LAST_RUN_DATE" --until="$CURRENT_DATE" --pretty=format:"%s")

# Loop through each commit message in the source branch
echo "$SOURCE_COMMIT_MESSAGES" | while read -r commit_message; do
    # Check if the commit message exists in the target branch
    if git -C $GIT_DIR_TARGET log $BRANCH_TARGET --pretty=format:"%s" | grep -Fxq "$commit_message"; then
        # Check if the commit message is already in the migrated file
        if ! grep -Fq "- $commit_message" "$MIGRATED_FILE"; then
            # Get the commit date from the source branch
            commit_date=$(git -C $GIT_DIR_SOURCE log --grep="^$commit_message$" --pretty=format:"%ad" --date=short -1)
            # Append the formatted log to the migrated file
            echo "- $commit_message ($commit_date)" >> "$MIGRATED_FILE"
        fi
    fi
done
