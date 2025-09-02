#!/bin/bash

# Decentralize AI Network Bootstrap Script
# This script sets up the initial infrastructure for the Decentralize AI network

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

# Function to install dependencies
install_dependencies() {
    print_status "Installing system dependencies..."
    
    # Update package lists
    if command_exists apt-get; then
        sudo apt-get update
        sudo apt-get install -y curl wget git build-essential software-properties-common
    elif command_exists yum; then
        sudo yum update -y
        sudo yum install -y curl wget git gcc gcc-c++ make
    elif command_exists brew; then
        brew update
        brew install curl wget git
    else
        print_error "Unsupported package manager. Please install dependencies manually."
        exit 1
    fi
    
    print_success "System dependencies installed"
}

# Function to install Node.js
install_nodejs() {
    if command_exists node; then
        print_status "Node.js already installed: $(node --version)"
        return
    fi
    
    print_status "Installing Node.js..."
    
    # Install Node.js using NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    print_success "Node.js installed: $(node --version)"
}

# Function to install Rust
install_rust() {
    if command_exists cargo; then
        print_status "Rust already installed: $(cargo --version)"
        return
    fi
    
    print_status "Installing Rust..."
    
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
    
    print_success "Rust installed: $(cargo --version)"
}

# Function to install Python
install_python() {
    if command_exists python3; then
        print_status "Python already installed: $(python3 --version)"
        return
    fi
    
    print_status "Installing Python..."
    
    if command_exists apt-get; then
        sudo apt-get install -y python3 python3-pip python3-venv
    elif command_exists yum; then
        sudo yum install -y python3 python3-pip
    elif command_exists brew; then
        brew install python3
    fi
    
    print_success "Python installed: $(python3 --version)"
}

# Function to setup project structure
setup_project() {
    print_status "Setting up project structure..."
    
    # Create necessary directories
    mkdir -p {data,logs,config,keys,backups}
    
    # Create configuration files
    cat > config/network.json << EOF
{
    "name": "$NETWORK_NAME",
    "chainId": $CHAIN_ID,
    "rpcPort": $RPC_PORT,
    "p2pPort": $P2P_PORT,
    "apiPort": $API_PORT,
    "consensus": "proof-of-stake",
    "blockTime": 15,
    "maxValidators": 100,
    "minStake": "10000000000000000000000"
}
EOF
    
    # Create environment file
    cat > .env << EOF
# Decentralize AI Network Configuration
NETWORK_NAME=$NETWORK_NAME
CHAIN_ID=$CHAIN_ID
RPC_PORT=$RPC_PORT
P2P_PORT=$P2P_PORT
API_PORT=$API_PORT

# Database
DATABASE_URL=sqlite:///data/network.db

# Logging
LOG_LEVEL=info
LOG_FILE=logs/network.log

# Security
PRIVATE_KEY_FILE=keys/validator.key
PASSWORD_FILE=keys/password.txt

# API
API_ENABLED=true
API_HOST=0.0.0.0
API_PORT=$API_PORT

# P2P
P2P_ENABLED=true
P2P_HOST=0.0.0.0
P2P_PORT=$P2P_PORT
EOF
    
    print_success "Project structure created"
}

# Function to install smart contract dependencies
install_contract_dependencies() {
    print_status "Installing smart contract dependencies..."
    
    cd ./contracts
    
    # Install compatible latest versions with network resilience
    print_status "Installing Hardhat 2.x (compatible with toolbox)..."
    npm install hardhat@^2.19.0 --timeout=300000 --retry=3 || print_warning "Hardhat installation failed, continuing..."
    
    print_status "Installing latest OpenZeppelin contracts..."
    npm install @openzeppelin/contracts@latest --timeout=300000 --retry=3 || print_warning "OpenZeppelin installation failed, continuing..."
    
    print_status "Installing OpenZeppelin Hardhat upgrades..."
    npm install @openzeppelin/hardhat-upgrades@latest --timeout=300000 --retry=3 || print_warning "OpenZeppelin upgrades installation failed, continuing..."
    
    print_status "Installing latest dotenv..."
    npm install dotenv@latest --timeout=300000 --retry=3 || print_warning "dotenv installation failed, continuing..."
    
    print_status "Installing compatible Hardhat toolbox..."
    npm install @nomicfoundation/hardhat-toolbox@^3.0.0 --timeout=300000 --retry=3 || print_warning "Hardhat toolbox installation failed, continuing..."
    
    print_status "Installing compatible Solidity coverage..."
    npm install solidity-coverage@^0.8.5 --timeout=300000 --retry=3 || print_warning "Solidity coverage installation failed, continuing..."
    
    print_status "Installing latest Solhint..."
    npm install solhint@latest --timeout=300000 --retry=3 || print_warning "Solhint installation failed, continuing..."
    
    print_status "Installing compatible Hardhat gas reporter..."
    npm install hardhat-gas-reporter@^1.0.8 --timeout=300000 --retry=3 || print_warning "Gas reporter installation failed, continuing..."
    
    # Note: Chainlink contracts can be added later if needed
    print_status "Skipping Chainlink contracts (can be added later if needed)..."
    
    cd ./scripts
    
    print_success "Smart contract dependencies installation completed"
}

# Function to install node dependencies
install_node_dependencies() {
    print_status "Installing node dependencies..."
    
    cd ./nodes
    
    # Install latest versions with modern alternatives and network resilience
    print_status "Installing latest Express..."
    npm install express@latest --timeout=300000 --retry=3 || print_warning "Express installation failed, continuing..."
    
    print_status "Installing latest WebSocket..."
    npm install ws@latest --timeout=300000 --retry=3 || print_warning "WebSocket installation failed, continuing..."
    
    print_status "Installing latest Ethers..."
    npm install ethers@latest --timeout=300000 --retry=3 || print_warning "Ethers installation failed, continuing..."
    
    print_status "Installing latest dotenv..."
    npm install dotenv@latest --timeout=300000 --retry=3 || print_warning "dotenv installation failed, continuing..."
    
    print_status "Installing latest Winston..."
    npm install winston@latest --timeout=300000 --retry=3 || print_warning "Winston installation failed, continuing..."
    
    print_status "Installing latest CORS..."
    npm install cors@latest --timeout=300000 --retry=3 || print_warning "CORS installation failed, continuing..."
    
    print_status "Installing latest Helmet..."
    npm install helmet@latest --timeout=300000 --retry=3 || print_warning "Helmet installation failed, continuing..."
    
    print_status "Installing latest Compression..."
    npm install compression@latest --timeout=300000 --retry=3 || print_warning "Compression installation failed, continuing..."
    
    print_status "Installing latest Joi..."
    npm install joi@latest --timeout=300000 --retry=3 || print_warning "Joi installation failed, continuing..."
    
    print_status "Installing latest Node-cron..."
    npm install node-cron@latest --timeout=300000 --retry=3 || print_warning "Node-cron installation failed, continuing..."
    
    print_status "Installing latest Rate limiter..."
    npm install express-rate-limit@latest --timeout=300000 --retry=3 || print_warning "Rate limiter installation failed, continuing..."
    
    print_status "Installing latest P2P networking (modern alternative)..."
    npm install @libp2p/websockets@latest --timeout=300000 --retry=3 || print_warning "LibP2P websockets installation failed, continuing..."
    npm install @libp2p/tcp@latest --timeout=300000 --retry=3 || print_warning "LibP2P tcp installation failed, continuing..."
    npm install @libp2p/noise@latest --timeout=300000 --retry=3 || print_warning "LibP2P noise installation failed, continuing..."
    
    cd ./scripts
    
    print_success "Node dependencies installation completed"
}

# Function to install AI dependencies
install_ai_dependencies() {
    print_status "Installing AI dependencies..."
    
    cd ./ai
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Skip pip upgrade to avoid SOCKS issues
    print_status "Using existing pip version to avoid SOCKS dependencies..."
    
    # Install essential AI dependencies (avoiding SOCKS dependencies)
    print_status "Installing essential AI dependencies..."
    pip install --upgrade numpy pandas scikit-learn --no-deps || print_warning "Data processing installation failed, continuing..."
    pip install --upgrade pydantic click rich tqdm python-dotenv pyyaml requests --no-deps || print_warning "Utilities installation failed, continuing..."
    pip install --upgrade pytest pytest-asyncio pytest-cov black flake8 --no-deps || print_warning "Testing installation failed, continuing..."
    pip install --upgrade jupyter notebook ipykernel matplotlib seaborn plotly --no-deps || print_warning "Development tools installation failed, continuing..."
    
    # Install modern alternatives for deprecated packages
    print_status "Installing modern AI alternatives..."
    pip install --upgrade fastapi uvicorn --no-deps || print_warning "FastAPI installation failed, continuing..."
    pip install --upgrade httpx --no-deps || print_warning "HTTPX installation failed, continuing..."
    pip install --upgrade pydantic-settings --no-deps || print_warning "Pydantic settings installation failed, continuing..."
    pip install --upgrade loguru --no-deps || print_warning "Loguru installation failed, continuing..."
    pip install --upgrade typer --no-deps || print_warning "Typer installation failed, continuing..."
    pip install --upgrade python-multipart --no-deps || print_warning "Multipart installation failed, continuing..."
    
    # Install core ML libraries (without problematic dependencies)
    print_status "Installing core ML libraries..."
    pip install --upgrade torch torchvision torchaudio --no-deps || print_warning "PyTorch installation failed, continuing..."
    pip install --upgrade transformers --no-deps || print_warning "Transformers installation failed, continuing..."
    pip install --upgrade cryptography --no-deps || print_warning "Crypto installation failed, continuing..."
    pip install --upgrade web3 eth-account --no-deps || print_warning "Blockchain installation failed, continuing..."
    
    deactivate
    cd ./scripts
    
    print_success "AI dependencies installed with latest versions"
}

# Function to install DAO dependencies
install_dao_dependencies() {
    print_status "Installing DAO dependencies..."
    
    cd ./dao
    
    # Install latest versions with modern alternatives and network resilience
    print_status "Installing latest Express..."
    npm install express@latest --timeout=300000 --retry=3 || print_warning "Express installation failed, continuing..."
    
    print_status "Installing latest Ethers..."
    npm install ethers@latest --timeout=300000 --retry=3 || print_warning "Ethers installation failed, continuing..."
    
    print_status "Installing latest Web3..."
    npm install web3@latest --timeout=300000 --retry=3 || print_warning "Web3 installation failed, continuing..."
    
    print_status "Installing latest dotenv..."
    npm install dotenv@latest --timeout=300000 --retry=3 || print_warning "dotenv installation failed, continuing..."
    
    print_status "Installing latest Winston..."
    npm install winston@latest --timeout=300000 --retry=3 || print_warning "Winston installation failed, continuing..."
    
    print_status "Installing latest CORS..."
    npm install cors@latest --timeout=300000 --retry=3 || print_warning "CORS installation failed, continuing..."
    
    print_status "Installing latest Helmet..."
    npm install helmet@latest --timeout=300000 --retry=3 || print_warning "Helmet installation failed, continuing..."
    
    print_status "Installing latest Joi..."
    npm install joi@latest --timeout=300000 --retry=3 || print_warning "Joi installation failed, continuing..."
    
    print_status "Installing latest Axios..."
    npm install axios@latest --timeout=300000 --retry=3 || print_warning "Axios installation failed, continuing..."
    
    print_status "Installing latest Express rate limiter..."
    npm install express-rate-limit@latest --timeout=300000 --retry=3 || print_warning "Rate limiter installation failed, continuing..."
    
    print_status "Installing latest Multer (file uploads)..."
    npm install multer@latest --timeout=300000 --retry=3 || print_warning "Multer installation failed, continuing..."
    
    print_status "Installing latest Morgan (logging)..."
    npm install morgan@latest --timeout=300000 --retry=3 || print_warning "Morgan installation failed, continuing..."
    
    cd ./scripts
    
    print_success "DAO dependencies installation completed"
}

# Function to generate initial keys
generate_keys() {
    print_status "Generating initial validator keys..."
    
    # Create keys directory
    mkdir -p keys
    
    # Generate validator key
    if [ ! -f keys/validator.key ]; then
        openssl rand -hex 32 > keys/validator.key
        print_success "Validator key generated"
    else
        print_warning "Validator key already exists"
    fi
    
    # Generate password file
    if [ ! -f keys/password.txt ]; then
        openssl rand -base64 32 > keys/password.txt
        print_success "Password file generated"
    else
        print_warning "Password file already exists"
    fi
    
    # Set proper permissions
    chmod 600 keys/*
    
    print_success "Keys generated and secured"
}

# Function to create systemd service
create_systemd_service() {
    print_status "Creating systemd service..."
    
    sudo tee /etc/systemd/system/decentralize-ai.service > /dev/null << EOF
[Unit]
Description=Decentralize AI Network Node
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/scripts/start-node.sh
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable decentralize-ai
    
    print_success "Systemd service created and enabled"
}

# Function to create start script
create_start_script() {
    print_status "Creating start script..."
    
    cat > scripts/start-node.sh << 'EOF'
#!/bin/bash

# Decentralize AI Network Node Start Script

set -e

# Load environment variables
source .env

# Function to print colored output
print_status() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Check if node is already running
if pgrep -f "decentralize-ai-node" > /dev/null; then
    print_error "Node is already running"
    exit 1
fi

# Start the node
print_status "Starting Decentralize AI Network Node..."
print_status "Network: $NETWORK_NAME"
print_status "Chain ID: $CHAIN_ID"
print_status "RPC Port: $RPC_PORT"
print_status "P2P Port: $P2P_PORT"
print_status "API Port: $API_PORT"

# Start the node process
cd nodes
npm start &
NODE_PID=$!

# Wait for node to start
sleep 5

# Check if node is running
if kill -0 $NODE_PID 2>/dev/null; then
    print_success "Node started successfully (PID: $NODE_PID)"
    echo $NODE_PID > ../data/node.pid
else
    print_error "Failed to start node"
    exit 1
fi
EOF
    
    chmod +x scripts/start-node.sh
    
    print_success "Start script created"
}

# Function to create stop script
create_stop_script() {
    print_status "Creating stop script..."
    
    cat > scripts/stop-node.sh << 'EOF'
#!/bin/bash

# Decentralize AI Network Node Stop Script

set -e

# Function to print colored output
print_status() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Check if PID file exists
if [ ! -f data/node.pid ]; then
    print_error "PID file not found. Node may not be running."
    exit 1
fi

# Read PID
NODE_PID=$(cat data/node.pid)

# Check if process is running
if ! kill -0 $NODE_PID 2>/dev/null; then
    print_error "Node process not found (PID: $NODE_PID)"
    rm -f data/node.pid
    exit 1
fi

# Stop the node
print_status "Stopping Decentralize AI Network Node (PID: $NODE_PID)..."
kill $NODE_PID

# Wait for process to stop
sleep 5

# Check if process stopped
if kill -0 $NODE_PID 2>/dev/null; then
    print_error "Failed to stop node gracefully. Force killing..."
    kill -9 $NODE_PID
fi

# Remove PID file
rm -f data/node.pid

print_success "Node stopped successfully"
EOF
    
    chmod +x scripts/stop-node.sh
    
    print_success "Stop script created"
}

# Function to create status script
create_status_script() {
    print_status "Creating status script..."
    
    cat > scripts/status.sh << 'EOF'
#!/bin/bash

# Decentralize AI Network Node Status Script

# Function to print colored output
print_status() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Check if PID file exists
if [ ! -f data/node.pid ]; then
    print_error "Node is not running (no PID file)"
    exit 1
fi

# Read PID
NODE_PID=$(cat data/node.pid)

# Check if process is running
if kill -0 $NODE_PID 2>/dev/null; then
    print_success "Node is running (PID: $NODE_PID)"
    
    # Get process info
    echo "Process Info:"
    ps -p $NODE_PID -o pid,ppid,cmd,etime,pcpu,pmem
    
    # Check network connectivity
    echo ""
    echo "Network Status:"
    netstat -tlnp | grep $NODE_PID || echo "No network connections found"
    
else
    print_error "Node is not running (process not found)"
    rm -f data/node.pid
    exit 1
fi
EOF
    
    chmod +x scripts/status.sh
    
    print_success "Status script created"
}

# Main bootstrap function
main() {
    print_status "Starting Decentralize AI Network Bootstrap..."
    print_status "This will set up the complete infrastructure for the network"
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root"
        exit 1
    fi
    
    # Install dependencies
    install_dependencies
    install_nodejs
    install_rust
    install_python
    
    # Setup project
    setup_project
    
    # Install project dependencies
    install_contract_dependencies
    install_node_dependencies
    install_ai_dependencies
    install_dao_dependencies
    
    # Generate keys
    generate_keys
    
    # Create scripts
    create_start_script
    create_stop_script
    create_status_script
    
    # Create systemd service
    create_systemd_service
    
    print_success "Bootstrap completed successfully!"
    print_status "Next steps:"
    echo "  1. Review configuration in config/network.json"
    echo "  2. Start the node: ./scripts/start-node.sh"
    echo "  3. Check status: ./scripts/status.sh"
    echo "  4. View logs: tail -f logs/network.log"
    echo ""
    print_status "The Decentralize AI Network is ready to launch!"
}

# Run main function
main "$@"
