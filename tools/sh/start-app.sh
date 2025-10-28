#!/bin/bash

# Delivery App - Start Everything
# One command to start the entire application

cd "$(dirname "$0")/../.."

# Start Flutter in Chrome
cd frontend && flutter run -d chrome
