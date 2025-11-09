#!/bin/bash
# Example build task script for ga53pd01
# This is a template - modify paths and commands for your actual project

# Example: Building a project on ga53pd01
echo "=== Build Task Started ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo "Hostname: $(hostname)"
echo ""

# Navigate to your project directory (modify this path)
PROJECT_DIR="/proj/tierivemu/work/${USER}/hornet"
echo "Project directory: ${PROJECT_DIR}"

# Check if directory exists
if [ -d "${PROJECT_DIR}" ]; then
    cd "${PROJECT_DIR}"
    echo "Changed to project directory: $(pwd)"

    # Display Git information for reference
    echo ""
    echo "=== Git Information ==="
    if [ -d .git ]; then
        echo "Branch: $(git branch --show-current)"
        echo "Commit: $(git log -1 --oneline)"
        echo "Status: $(git status --porcelain | wc -l) uncommitted files"
    else
        echo "WARNING: Not a git repository"
    fi
    echo "======================="

    # Example build commands (modify as needed)
    echo ""
    echo "Running make clean..."
    make clean

    echo ""
    echo "Running make all..."
    make all

    echo ""
    echo "Build completed successfully"
else
    echo "ERROR: Project directory not found: ${PROJECT_DIR}"
    echo "Please modify the PROJECT_DIR variable in this script"
    exit 1
fi

echo ""
echo "=== Build Task Complete ==="
