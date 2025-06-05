#!/bin/bash

# Get the directory where the script is located
script_dir="$(dirname "$(realpath "$0")")"

# Set the CSV file name (ensure this file exists and is in the same directory as the script)
csv_file="$script_dir/migration_file_paths.csv"

# Check if the CSV file exists
if [[ ! -f "$csv_file" ]]; then
    echo "CSV file not found!"
    exit 1
fi

# Read the CSV file line by line
while IFS=',' read -r file_path new_file_path; do
    # Skip the header row
    if [[ "$file_path" == "file_path" ]]; then
        continue
    fi

    # Make file paths relative to the script's directory
    abs_file_path="$script_dir/$file_path"
    abs_new_file_path="/bahmni-o3-migration/complex_obs/$new_file_path"

    # Check if the source file exists
    if [[ ! -f "$abs_file_path" ]]; then
        echo "File not found: $abs_file_path"
        continue
    fi

    # Create the target directory if it does not exist
    target_dir=$(dirname "$abs_new_file_path")
    if [[ ! -d "$target_dir" ]]; then
        echo "Target directory does not exist, creating: $target_dir"
        mkdir -p "$target_dir"
    fi

    # Move the file
    mv "$abs_file_path" "$abs_new_file_path"
    if [[ $? -eq 0 ]]; then
        echo "Moved: $abs_file_path to $abs_new_file_path"
    else
        echo "Failed to move: $abs_file_path"
    fi
done < "$csv_file"

echo "File move process completed."
