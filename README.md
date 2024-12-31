# Script to automatically analyze the commits from specified date range

## Usage
- Put your API_KEY in the file
- Specify the git directory you want to analyze in GIT_DIR
- Run the script `./analyze.sh`

## Generated files
- `index.html` : Files with the the list of commits with each classification and the details
- `last_run_date.txt` : Log file that write the latest date of the script got run
- `commits.html` : list of commits
- `prompt.txt` : prompt text to classify the commits
- `response.log` : file to log all LLM responses 
- `migrated.md` : list of source commits that already implemented in target 
