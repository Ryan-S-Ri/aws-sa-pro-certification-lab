#!/bin/bash

# rename-variables.sh - Utility to rename Terraform variables across multiple files
# Usage: ./rename-variables.sh [options] file1.tf file2.tf file3.tf ...
# Options:
#   -d, --dry-run    Show what would be changed without making changes
#   -b, --backup     Create backup files before making changes
#   -h, --help       Show help message

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
DRY_RUN=false
CREATE_BACKUP=false
FILES=()

# Variable mappings (old_name:new_name)
# Add or modify these mappings as needed
declare -A VARIABLE_MAPPINGS=(
    ["aws_region"]="primary_region"
    # Add more mappings here as needed, for example:
    # ["old_var_name"]="new_var_name"
)

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [options] file1.tf file2.tf file3.tf ...

Options:
    -d, --dry-run    Show what would be changed without making changes
    -b, --backup     Create backup files before making changes
    -h, --help       Show this help message
    -m, --mapping    Add custom mapping (format: old_name:new_name)

Examples:
    # Dry run to see what would change
    $0 --dry-run *.tf

    # Rename variables and create backups
    $0 --backup main.tf variables.tf compute.tf

    # Add custom mapping
    $0 -m "my_old_var:my_new_var" -b *.tf

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -b|--backup)
            CREATE_BACKUP=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -m|--mapping)
            if [[ -z "${2:-}" ]] || [[ ! "$2" =~ ^[^:]+:[^:]+$ ]]; then
                echo -e "${RED}Error: --mapping requires format 'old_name:new_name'${NC}"
                exit 1
            fi
            IFS=':' read -r old_name new_name <<< "$2"
            VARIABLE_MAPPINGS["$old_name"]="$new_name"
            shift 2
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
        *)
            FILES+=("$1")
            shift
            ;;
    esac
done

# Check if files were provided
if [ ${#FILES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No files specified${NC}"
    show_usage
    exit 1
fi

# Function to check if a file exists
check_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: File '$file' not found${NC}"
        return 1
    fi
    return 0
}

# Function to create backup
create_backup() {
    local file=$1
    local backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$file" "$backup_file"
    echo -e "${GREEN}Created backup: $backup_file${NC}"
}

# Function to rename variables in a file
rename_variables() {
    local file=$1
    local temp_file="${file}.tmp"
    local changes_made=false
    
    echo -e "\n${BLUE}Processing: $file${NC}"
    
    # Create a copy of the file to work with
    cp "$file" "$temp_file"
    
    # Process each variable mapping
    for old_var in "${!VARIABLE_MAPPINGS[@]}"; do
        new_var="${VARIABLE_MAPPINGS[$old_var]}"
        
        # Count occurrences before replacement
        count_before=$(grep -c "var\.$old_var\b" "$temp_file" 2>/dev/null || true)
        
        if [ "$count_before" -gt 0 ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "  ${YELLOW}Would rename: var.$old_var -> var.$new_var (${count_before} occurrences)${NC}"
                # Show context of changes
                grep -n "var\.$old_var\b" "$file" | head -5 | while IFS= read -r line; do
                    echo "    Line $line"
                done
                if [ "$count_before" -gt 5 ]; then
                    echo "    ... and $((count_before - 5)) more"
                fi
            else
                # Perform the replacement
                sed -i.sed_backup "s/var\.$old_var\b/var.$new_var/g" "$temp_file"
                echo -e "  ${GREEN}Renamed: var.$old_var -> var.$new_var (${count_before} occurrences)${NC}"
                changes_made=true
            fi
        fi
        
        # Also check for variable declarations (in variables.tf)
        count_var_decl=$(grep -c "^variable \"$old_var\"" "$temp_file" 2>/dev/null || true)
        if [ "$count_var_decl" -gt 0 ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "  ${YELLOW}Would rename variable declaration: $old_var -> $new_var${NC}"
            else
                sed -i.sed_backup "s/^variable \"$old_var\"/variable \"$new_var\"/g" "$temp_file"
                echo -e "  ${GREEN}Renamed variable declaration: $old_var -> $new_var${NC}"
                changes_made=true
            fi
        fi
    done
    
    # Clean up sed backup files
    rm -f "${temp_file}.sed_backup"
    
    # If not dry run and changes were made, replace the original file
    if [ "$DRY_RUN" = false ] && [ "$changes_made" = true ]; then
        mv "$temp_file" "$file"
        echo -e "  ${GREEN}File updated successfully${NC}"
    else
        rm -f "$temp_file"
        if [ "$changes_made" = false ]; then
            echo -e "  ${BLUE}No changes needed${NC}"
        fi
    fi
}

# Main execution
echo -e "${BLUE}=== Terraform Variable Renamer ===${NC}"
echo -e "${BLUE}Variable mappings:${NC}"
for old_var in "${!VARIABLE_MAPPINGS[@]}"; do
    echo -e "  $old_var -> ${VARIABLE_MAPPINGS[$old_var]}"
done

if [ "$DRY_RUN" = true ]; then
    echo -e "\n${YELLOW}DRY RUN MODE - No files will be modified${NC}"
fi

# Process each file
for file in "${FILES[@]}"; do
    if check_file "$file"; then
        if [ "$CREATE_BACKUP" = true ] && [ "$DRY_RUN" = false ]; then
            create_backup "$file"
        fi
        rename_variables "$file"
    fi
done

echo -e "\n${GREEN}Processing complete!${NC}"

# Summary
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}This was a dry run. To apply changes, run without --dry-run${NC}"
else
    echo -e "${GREEN}All files have been processed.${NC}"
    if [ "$CREATE_BACKUP" = true ]; then
        echo -e "${BLUE}Backup files created with .backup.<timestamp> extension${NC}"
    fi
fi
