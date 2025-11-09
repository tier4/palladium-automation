#!/bin/bash
# Test script for verifying SSH connection to ga53pd01
# This script is executed remotely on ga53pd01 via claude_to_ga53pd01.sh

echo "=== Connection Test Started ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo "Hostname: $(hostname)"
echo ""
echo "Working directory: $(pwd)"
echo "Test calculation: 10 + 20 = $((10 + 20))"
echo ""
echo "=== Connection Test Complete ==="
