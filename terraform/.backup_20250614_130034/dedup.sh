#!/bin/bash

# dedup-variables.sh - Remove duplicate variable declarations from Terraform files
# Usage: ./dedup-variables.sh variables.tf

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if file is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No file specified${NC}"
    echo "Usage: $0 <terraform-file>"
    exit 1
fi

FILE="$1"

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo -e "${RED}Error: File '$FILE' not found${NC}"
    exit 1
fi

echo -e "${BLUE}=== Terraform Variable Deduplication Tool ===${NC}"
echo -e "${BLUE}Processing: $FILE${NC}\n"

# Create backup
BACKUP="${FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$FILE" "$BACKUP"
echo -e "${GREEN}Created backup: $BACKUP${NC}\n"

# Create temporary file
TEMP_FILE="${FILE}.dedup.tmp"
SEEN_VARS_FILE="${FILE}.seen_vars.tmp"

# Track seen variables
> "$SEEN_VARS_FILE"

# Process the file
echo -e "${YELLOW}Scanning for duplicate variables...${NC}"

# Variables to track state
in_variable_block=false
current_var_name=""
current_var_content=""
line_number=0
duplicates_found=0

# Read file line by line
while IFS= read -r line || [ -n "$line" ]; do
    ((line_number++))
    
    # Check if this is a variable declaration start
    if [[ "$line" =~ ^variable[[:space:]]+\"([^\"]+)\" ]]; then
        var_name="${BASH_REMATCH[1]}"
        
        # If we were already in a variable block, we need to close it
        if [ "$in_variable_block" = true ]; then
            # This shouldn't happen in well-formed Terraform, but let's handle it
            echo -e "${RED}Warning: Unclosed variable block at line $line_number${NC}"
        fi
        
        # Check if we've seen this variable before
        if grep -q "^${var_name}$" "$SEEN_VARS_FILE"; then
            echo -e "${RED}Found duplicate: variable \"$var_name\" at line $line_number${NC}"
            ((duplicates_found++))
            in_variable_block=true
            current_var_name="$var_name"
            current_var_content="$line"
        else
            # First occurrence - mark as seen and keep it
            echo "$var_name" >> "$SEEN_VARS_FILE"
            echo "$line" >> "$TEMP_FILE"
            in_variable_block=true
            current_var_name="$var_name"
            current_var_content="$line"
        fi
    elif [ "$in_variable_block" = true ]; then
        # We're inside a variable block
        if [[ "$line" =~ ^[[:space:]]*}[[:space:]]*$ ]]; then
            # End of variable block
            if ! grep -q "^${current_var_name}$" "$SEEN_VARS_FILE" || [ "$duplicates_found" -eq 0 ]; then
                echo "$line" >> "$TEMP_FILE"
            fi
            in_variable_block=false
            current_var_name=""
            current_var_content=""
        else
            # Continue building the variable content
            current_var_content+=$'\n'"$line"
            if ! grep -q "^${current_var_name}$" "$SEEN_VARS_FILE" || [ "$duplicates_found" -eq 0 ]; then
                echo "$line" >> "$TEMP_FILE"
            fi
        fi
    else
        # Not in a variable block, just copy the line
        echo "$line" >> "$TEMP_FILE"
    fi
done < "$FILE"

# Clean up temporary seen vars file
rm -f "$SEEN_VARS_FILE"

echo -e "\n${BLUE}Summary:${NC}"
echo -e "Total lines processed: $line_number"
echo -e "Duplicate variables found: $duplicates_found"

if [ "$duplicates_found" -gt 0 ]; then
    # Show differences
    echo -e "\n${YELLOW}Changes to be made:${NC}"
    diff -u "$FILE" "$TEMP_FILE" || true
    
    # Ask for confirmation
    echo -e "\n${YELLOW}Do you want to apply these changes? (y/n)${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        mv "$TEMP_FILE" "$FILE"
        echo -e "${GREEN}File updated successfully!${NC}"
        echo -e "${BLUE}Original file backed up as: $BACKUP${NC}"
    else
        rm -f "$TEMP_FILE"
        echo -e "${YELLOW}Changes discarded. Original file unchanged.${NC}"
    fi
else
    rm -f "$TEMP_FILE"
    echo -e "${GREEN}No duplicate variables found!${NC}"
fi
