#!/bin/bash

script_dir="$(dirname "$(realpath "$0")")"

"$script_dir/retire_concepts.sh"
"$script_dir/retire_forms.sh"

echo "Post-migration clean-up completed successfully."
