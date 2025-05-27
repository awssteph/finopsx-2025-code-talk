#!/bin/bash

# Script to run the profile code test with monitoring

echo "Starting Bedrock API test with 100 iterations"
echo "=============================================="
echo "Started at: $(date)"
echo "=============================================="

# Run the Python script
python3 profile_code_100_runs.py

echo "=============================================="
echo "Completed at: $(date)"
echo "=============================================="