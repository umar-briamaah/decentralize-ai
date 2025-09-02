#!/bin/bash

# Decentralize AI Network - Node Startup Script
# This script starts the Decentralize AI network node

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

print_status "Starting Decentralize AI Network Node..."

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    print_warning "Node modules not found. Running bootstrap first..."
    ./scripts/bootstrap.sh
fi

# Start the node
print_status "Starting node server..."
cd nodes
npm start

print_success "Node started successfully!"
