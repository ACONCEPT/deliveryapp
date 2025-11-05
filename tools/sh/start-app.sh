#!/bin/bash

# Delivery App - Start Everything
# One command to start the entire application

cd "$(dirname "$0")/../.."

# Create user-owned temp directory if TMPDIR has permission issues
if [ ! -w "$TMPDIR" ]; then
    export TMPDIR="$HOME/.flutter-tmp"
    mkdir -p "$TMPDIR"
fi

# Start Flutter in Chrome
cd frontend && flutter run -d chrome
