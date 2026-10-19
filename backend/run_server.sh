#!/bin/bash
echo "========================================================"
echo "KHOI DONG FASTAPI LOCAL BACKEND (PORT 5001)"
echo "========================================================"

# Get the script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

source ../../Software/.venv/bin/activate
uvicorn main:app --reload --host 0.0.0.0 --port 5001
