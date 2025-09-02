#!/bin/bash

# Decentralize AI Network Deployment Script
# This script deploys the complete Decentralize AI network infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NETWORK_NAME="decentralize-ai"
CHAIN_ID=1337
RPC_PORT=8545
P2P_PORT=30303
API_PORT=8080
WS_PORT=8081
DAO_PORT=8082

# Function to print colored output
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to deploy smart contracts
deploy_contracts() {
    print_status "Deploying smart contracts..."
    
    cd contracts
    
    # Install dependencies
    npm install
    
    # Compile contracts
    npx hardhat compile
    
    # Deploy to local network
    npx hardhat run scripts/deploy.js --network localhost
    
    print_success "Smart contracts deployed"
    
    cd ..
}

# Function to start blockchain node
start_blockchain() {
    print_status "Starting blockchain node..."
    
    cd nodes
    
    # Install dependencies
    npm install
    
    # Start node
    npm start &
    NODE_PID=$!
    
    # Wait for node to start
    sleep 10
    
    # Check if node is running
    if kill -0 $NODE_PID 2>/dev/null; then
        print_success "Blockchain node started (PID: $NODE_PID)"
        echo $NODE_PID > ../data/node.pid
    else
        print_error "Failed to start blockchain node"
        exit 1
    fi
    
    cd ..
}

# Function to start AI coordinator
start_ai_coordinator() {
    print_status "Starting AI coordinator..."
    
    cd ai
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Install dependencies
    pip install -r requirements.txt
    
    # Start AI coordinator
    python3 federated_learning.py &
    AI_PID=$!
    
    # Wait for AI coordinator to start
    sleep 5
    
    # Check if AI coordinator is running
    if kill -0 $AI_PID 2>/dev/null; then
        print_success "AI coordinator started (PID: $AI_PID)"
        echo $AI_PID > ../data/ai.pid
    else
        print_error "Failed to start AI coordinator"
        exit 1
    fi
    
    deactivate
    cd ..
}

# Function to start DAO manager
start_dao_manager() {
    print_status "Starting DAO manager..."
    
    cd dao
    
    # Install dependencies
    npm install
    
    # Start DAO manager
    npm start &
    DAO_PID=$!
    
    # Wait for DAO manager to start
    sleep 5
    
    # Check if DAO manager is running
    if kill -0 $DAO_PID 2>/dev/null; then
        print_success "DAO manager started (PID: $DAO_PID)"
        echo $DAO_PID > ../data/dao.pid
    else
        print_error "Failed to start DAO manager"
        exit 1
    fi
    
    cd ..
}

# Function to start IPFS node
start_ipfs() {
    print_status "Starting IPFS node..."
    
    # Check if IPFS is installed
    if ! command_exists ipfs; then
        print_warning "IPFS not installed, skipping IPFS node"
        return
    fi
    
    # Initialize IPFS if not already initialized
    if [ ! -d ~/.ipfs ]; then
        ipfs init
    fi
    
    # Start IPFS daemon
    ipfs daemon &
    IPFS_PID=$!
    
    # Wait for IPFS to start
    sleep 5
    
    # Check if IPFS is running
    if kill -0 $IPFS_PID 2>/dev/null; then
        print_success "IPFS node started (PID: $IPFS_PID)"
        echo $IPFS_PID > data/ipfs.pid
    else
        print_error "Failed to start IPFS node"
        exit 1
    fi
}

# Function to start monitoring
start_monitoring() {
    print_status "Starting monitoring services..."
    
    # Create monitoring script
    cat > scripts/monitor.sh << 'EOF'
#!/bin/bash

# Decentralize AI Network Monitoring Script

while true; do
    echo "=== Decentralize AI Network Status ==="
    echo "Timestamp: $(date)"
    echo ""
    
    # Check blockchain node
    if [ -f data/node.pid ]; then
        NODE_PID=$(cat data/node.pid)
        if kill -0 $NODE_PID 2>/dev/null; then
            echo "Blockchain Node: Running (PID: $NODE_PID)"
        else
            echo "Blockchain Node: Stopped"
        fi
    else
        echo "Blockchain Node: Not started"
    fi
    
    # Check AI coordinator
    if [ -f data/ai.pid ]; then
        AI_PID=$(cat data/ai.pid)
        if kill -0 $AI_PID 2>/dev/null; then
            echo "AI Coordinator: Running (PID: $AI_PID)"
        else
            echo "AI Coordinator: Stopped"
        fi
    else
        echo "AI Coordinator: Not started"
    fi
    
    # Check DAO manager
    if [ -f data/dao.pid ]; then
        DAO_PID=$(cat data/dao.pid)
        if kill -0 $DAO_PID 2>/dev/null; then
            echo "DAO Manager: Running (PID: $DAO_PID)"
        else
            echo "DAO Manager: Stopped"
        fi
    else
        echo "DAO Manager: Not started"
    fi
    
    # Check IPFS
    if [ -f data/ipfs.pid ]; then
        IPFS_PID=$(cat data/ipfs.pid)
        if kill -0 $IPFS_PID 2>/dev/null; then
            echo "IPFS Node: Running (PID: $IPFS_PID)"
        else
            echo "IPFS Node: Stopped"
        fi
    else
        echo "IPFS Node: Not started"
    fi
    
    echo ""
    echo "Network Status: Active"
    echo "================================"
    
    sleep 30
done
EOF
    
    chmod +x scripts/monitor.sh
    
    # Start monitoring
    ./scripts/monitor.sh &
    MONITOR_PID=$!
    
    print_success "Monitoring started (PID: $MONITOR_PID)"
    echo $MONITOR_PID > data/monitor.pid
}

# Function to create status script
create_status_script() {
    print_status "Creating status script..."
    
    cat > scripts/status.sh << 'EOF'
#!/bin/bash

# Decentralize AI Network Status Script

echo "=== Decentralize AI Network Status ==="
echo "Timestamp: $(date)"
echo ""

# Check blockchain node
if [ -f data/node.pid ]; then
    NODE_PID=$(cat data/node.pid)
    if kill -0 $NODE_PID 2>/dev/null; then
        echo "Blockchain Node: Running (PID: $NODE_PID)"
    else
        echo "Blockchain Node: Stopped"
    fi
else
    echo "Blockchain Node: Not started"
fi

# Check AI coordinator
if [ -f data/ai.pid ]; then
    AI_PID=$(cat data/ai.pid)
    if kill -0 $AI_PID 2>/dev/null; then
        echo "AI Coordinator: Running (PID: $AI_PID)"
    else
        echo "AI Coordinator: Stopped"
    fi
else
    echo "AI Coordinator: Not started"
fi

# Check DAO manager
if [ -f data/dao.pid ]; then
    DAO_PID=$(cat data/dao.pid)
    if kill -0 $DAO_PID 2>/dev/null; then
        echo "DAO Manager: Running (PID: $DAO_PID)"
    else
        echo "DAO Manager: Stopped"
    fi
else
    echo "DAO Manager: Not started"
fi

# Check IPFS
if [ -f data/ipfs.pid ]; then
    IPFS_PID=$(cat data/ipfs.pid)
    if kill -0 $IPFS_PID 2>/dev/null; then
        echo "IPFS Node: Running (PID: $IPFS_PID)"
    else
        echo "IPFS Node: Stopped"
    fi
else
    echo "IPFS Node: Not started"
fi

echo ""
echo "Network Status: Active"
echo "================================"
EOF
    
    chmod +x scripts/status.sh
    
    print_success "Status script created"
}

# Function to create stop script
create_stop_script() {
    print_status "Creating stop script..."
    
    cat > scripts/stop.sh << 'EOF'
#!/bin/bash

# Decentralize AI Network Stop Script

echo "Stopping Decentralize AI Network..."

# Stop monitoring
if [ -f data/monitor.pid ]; then
    MONITOR_PID=$(cat data/monitor.pid)
    if kill -0 $MONITOR_PID 2>/dev/null; then
        kill $MONITOR_PID
        echo "Monitoring stopped"
    fi
    rm -f data/monitor.pid
fi

# Stop blockchain node
if [ -f data/node.pid ]; then
    NODE_PID=$(cat data/node.pid)
    if kill -0 $NODE_PID 2>/dev/null; then
        kill $NODE_PID
        echo "Blockchain node stopped"
    fi
    rm -f data/node.pid
fi

# Stop AI coordinator
if [ -f data/ai.pid ]; then
    AI_PID=$(cat data/ai.pid)
    if kill -0 $AI_PID 2>/dev/null; then
        kill $AI_PID
        echo "AI coordinator stopped"
    fi
    rm -f data/ai.pid
fi

# Stop DAO manager
if [ -f data/dao.pid ]; then
    DAO_PID=$(cat data/dao.pid)
    if kill -0 $DAO_PID 2>/dev/null; then
        kill $DAO_PID
        echo "DAO manager stopped"
    fi
    rm -f data/dao.pid
fi

# Stop IPFS
if [ -f data/ipfs.pid ]; then
    IPFS_PID=$(cat data/ipfs.pid)
    if kill -0 $IPFS_PID 2>/dev/null; then
        kill $IPFS_PID
        echo "IPFS node stopped"
    fi
    rm -f data/ipfs.pid
fi

echo "Decentralize AI Network stopped"
EOF
    
    chmod +x scripts/stop.sh
    
    print_success "Stop script created"
}

# Main deployment function
main() {
    print_status "Starting Decentralize AI Network deployment..."
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root"
        exit 1
    fi
    
    # Create data directory
    mkdir -p data
    
    # Deploy smart contracts
    deploy_contracts
    
    # Start services
    start_blockchain
    start_ai_coordinator
    start_dao_manager
    start_ipfs
    
    # Start monitoring
    start_monitoring
    
    # Create management scripts
    create_status_script
    create_stop_script
    
    print_success "Decentralize AI Network deployed successfully!"
    print_status "Services running:"
    echo "  - Blockchain Node: http://localhost:$RPC_PORT"
    echo "  - API Server: http://localhost:$API_PORT"
    echo "  - WebSocket: ws://localhost:$WS_PORT"
    echo "  - DAO Manager: http://localhost:$DAO_PORT"
    echo "  - IPFS Gateway: http://localhost:5001"
    echo ""
    print_status "Management commands:"
    echo "  - Check status: ./scripts/status.sh"
    echo "  - Stop network: ./scripts/stop.sh"
    echo "  - View logs: tail -f logs/*.log"
    echo ""
    print_status "The Decentralize AI Network is now live!"
}

# Run main function
main "$@"
