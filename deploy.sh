#!/bin/bash

# Decentralize AI Network - Deployment Script
# This script deploys the complete Decentralize AI Network application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

print_header() {
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}🚀 Decentralize AI Network - Deployment Script${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

print_header

print_status "Starting Decentralize AI Network deployment..."

# Check system requirements
print_status "Checking system requirements..."

# Check Node.js
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js 18+ first."
    exit 1
fi

NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    print_error "Node.js version 18+ is required. Current version: $(node --version)"
    exit 1
fi

print_success "Node.js $(node --version) is installed"

# Check npm
if ! command -v npm &> /dev/null; then
    print_error "npm is not installed. Please install npm first."
    exit 1
fi

print_success "npm $(npm --version) is installed"

# Install dependencies
print_status "Installing application dependencies..."
npm install

if [ $? -eq 0 ]; then
    print_success "Dependencies installed successfully"
else
    print_error "Failed to install dependencies"
    exit 1
fi

# Create necessary directories
print_status "Creating application directories..."
mkdir -p public/css
mkdir -p public/js
mkdir -p public/images
mkdir -p logs
mkdir -p data

print_success "Directories created"

# Set up environment
print_status "Setting up environment configuration..."

if [ ! -f ".env" ]; then
    cat > .env << EOF
# Decentralize AI Network Configuration
NODE_ENV=production
PORT=3000
WS_PORT=8080

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=decentralize_ai
DB_USER=postgres
DB_PASSWORD=your_password_here

# Blockchain Configuration
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/your_project_id
POLYGON_RPC_URL=https://polygon-mainnet.infura.io/v3/your_project_id
PRIVATE_KEY=your_private_key_here

# AI Configuration
AI_MODEL_PATH=./ai/models
FEDERATED_LEARNING_ENABLED=true
PRIVACY_LEVEL=high

# Governance Configuration
GOVERNANCE_CONTRACT_ADDRESS=0x...
STAKING_CONTRACT_ADDRESS=0x...
TOKEN_CONTRACT_ADDRESS=0x...

# Security
JWT_SECRET=your_jwt_secret_here
ENCRYPTION_KEY=your_encryption_key_here
EOF
    print_warning "Created .env file. Please update with your actual configuration values."
else
    print_success "Environment file already exists"
fi

# Compile smart contracts
print_status "Compiling smart contracts..."
cd contracts
if [ -f "package.json" ]; then
    npm install
    npx hardhat compile
    if [ $? -eq 0 ]; then
        print_success "Smart contracts compiled successfully"
    else
        print_warning "Smart contract compilation failed, but continuing..."
    fi
else
    print_warning "No contracts directory found, skipping contract compilation"
fi
cd ..

# Compile Circom circuits
print_status "Compiling zero-knowledge circuits..."
if [ -d "contracts/circuits" ]; then
    cd contracts/circuits
    if [ -f "compile_circuits.js" ]; then
        node compile_circuits.js
        if [ $? -eq 0 ]; then
            print_success "Zero-knowledge circuits compiled successfully"
        else
            print_warning "Circuit compilation failed, but continuing..."
        fi
    fi
    cd ../..
else
    print_warning "No circuits directory found, skipping circuit compilation"
fi

# Set up AI environment
print_status "Setting up AI module..."
if [ -d "ai" ]; then
    cd ai
    if [ -f "requirements.txt" ]; then
        if command -v python3 &> /dev/null; then
            python3 -m venv venv
            source venv/bin/activate
            pip install -r requirements.txt
            if [ $? -eq 0 ]; then
                print_success "AI module dependencies installed"
            else
                print_warning "AI module installation failed, but continuing..."
            fi
            deactivate
        else
            print_warning "Python3 not found, skipping AI module setup"
        fi
    fi
    cd ..
else
    print_warning "No AI directory found, skipping AI module setup"
fi

# Create systemd service file
print_status "Creating systemd service file..."
sudo tee /etc/systemd/system/decentralize-ai.service > /dev/null << EOF
[Unit]
Description=Decentralize AI Network
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/node app.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
EOF

print_success "Systemd service file created"

# Create startup script
print_status "Creating startup script..."
cat > start.sh << 'EOF'
#!/bin/bash
# Decentralize AI Network Startup Script

echo "🚀 Starting Decentralize AI Network..."

# Check if already running
if pgrep -f "node app.js" > /dev/null; then
    echo "⚠️  Application is already running"
    echo "   To restart, run: ./restart.sh"
    exit 1
fi

# Start the application
nohup node app.js > logs/app.log 2>&1 &
PID=$!

echo "✅ Application started with PID: $PID"
echo "🌐 Web Interface: http://localhost:3000"
echo "🔌 WebSocket: ws://localhost:8080"
echo "📊 API Base: http://localhost:3000/api"
echo ""
echo "📝 Logs: tail -f logs/app.log"
echo "🛑 Stop: ./stop.sh"
echo "🔄 Restart: ./restart.sh"

# Save PID
echo $PID > .app.pid
EOF

chmod +x start.sh

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash
# Decentralize AI Network Stop Script

echo "🛑 Stopping Decentralize AI Network..."

if [ -f .app.pid ]; then
    PID=$(cat .app.pid)
    if kill -0 $PID 2>/dev/null; then
        kill $PID
        echo "✅ Application stopped (PID: $PID)"
        rm .app.pid
    else
        echo "⚠️  Application was not running"
        rm .app.pid
    fi
else
    echo "⚠️  No PID file found, trying to kill by process name..."
    pkill -f "node app.js" && echo "✅ Application stopped" || echo "⚠️  No running application found"
fi
EOF

chmod +x stop.sh

# Create restart script
cat > restart.sh << 'EOF'
#!/bin/bash
# Decentralize AI Network Restart Script

echo "🔄 Restarting Decentralize AI Network..."

./stop.sh
sleep 2
./start.sh
EOF

chmod +x restart.sh

print_success "Startup scripts created"

# Create nginx configuration
print_status "Creating nginx configuration..."
sudo tee /etc/nginx/sites-available/decentralize-ai > /dev/null << EOF
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    location /ws {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

print_success "Nginx configuration created (update server_name with your domain)"

# Create SSL certificate script
cat > setup-ssl.sh << 'EOF'
#!/bin/bash
# SSL Certificate Setup Script

echo "🔒 Setting up SSL certificate..."

# Install certbot if not installed
if ! command -v certbot &> /dev/null; then
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
fi

# Get domain from user
read -p "Enter your domain name: " DOMAIN

# Generate SSL certificate
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN

echo "✅ SSL certificate setup complete"
echo "🔒 Your site is now available at: https://$DOMAIN"
EOF

chmod +x setup-ssl.sh

# Create monitoring script
cat > monitor.sh << 'EOF'
#!/bin/bash
# Decentralize AI Network Monitoring Script

echo "📊 Decentralize AI Network Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if application is running
if pgrep -f "node app.js" > /dev/null; then
    echo "✅ Application Status: RUNNING"
    PID=$(pgrep -f "node app.js")
    echo "   PID: $PID"
    
    # Get memory usage
    MEMORY=$(ps -o pid,vsz,rss,comm -p $PID | tail -1 | awk '{print $2, $3}')
    echo "   Memory Usage: $MEMORY KB"
    
    # Get CPU usage
    CPU=$(ps -o pid,pcpu,comm -p $PID | tail -1 | awk '{print $2}')
    echo "   CPU Usage: $CPU%"
else
    echo "❌ Application Status: NOT RUNNING"
fi

echo ""

# Check web interface
if curl -s http://localhost:3000/health > /dev/null; then
    echo "✅ Web Interface: ACCESSIBLE"
else
    echo "❌ Web Interface: NOT ACCESSIBLE"
fi

# Check WebSocket
if nc -z localhost 8080 2>/dev/null; then
    echo "✅ WebSocket: ACCESSIBLE"
else
    echo "❌ WebSocket: NOT ACCESSIBLE"
fi

echo ""

# Show recent logs
echo "📝 Recent Logs (last 10 lines):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "logs/app.log" ]; then
    tail -10 logs/app.log
else
    echo "No log file found"
fi
EOF

chmod +x monitor.sh

print_success "Monitoring script created"

# Final setup
print_status "Performing final setup..."

# Set proper permissions
chmod 755 .
chmod 644 .env
chmod 755 scripts/
chmod 755 public/
chmod 644 public/*.html
chmod 644 public/css/*.css
chmod 644 public/js/*.js

print_success "Permissions set"

# Create README for deployment
cat > DEPLOYMENT_README.md << 'EOF'
# Decentralize AI Network - Deployment Guide

## 🚀 Quick Start

1. **Start the application:**
   ```bash
   ./start.sh
   ```

2. **Access the web interface:**
   - Open your browser and go to: http://localhost:3000
   - WebSocket endpoint: ws://localhost:8080

3. **Monitor the application:**
   ```bash
   ./monitor.sh
   ```

## 📋 Available Scripts

- `./start.sh` - Start the application
- `./stop.sh` - Stop the application
- `./restart.sh` - Restart the application
- `./monitor.sh` - Check application status
- `./setup-ssl.sh` - Set up SSL certificate

## 🌐 Production Deployment

### 1. Domain Setup
1. Update nginx configuration: `/etc/nginx/sites-available/decentralize-ai`
2. Change `server_name` to your domain
3. Enable the site: `sudo ln -s /etc/nginx/sites-available/decentralize-ai /etc/nginx/sites-enabled/`
4. Test nginx: `sudo nginx -t`
5. Restart nginx: `sudo systemctl restart nginx`

### 2. SSL Certificate
```bash
./setup-ssl.sh
```

### 3. Systemd Service
```bash
sudo systemctl enable decentralize-ai
sudo systemctl start decentralize-ai
```

## 📊 Monitoring

- **Logs:** `tail -f logs/app.log`
- **Status:** `./monitor.sh`
- **Systemd:** `sudo systemctl status decentralize-ai`

## 🔧 Configuration

Edit `.env` file to configure:
- Database settings
- Blockchain RPC URLs
- API keys
- Security settings

## 🆘 Troubleshooting

1. **Application won't start:**
   - Check logs: `tail -f logs/app.log`
   - Verify dependencies: `npm install`
   - Check port availability: `netstat -tulpn | grep :3000`

2. **Web interface not accessible:**
   - Check if application is running: `./monitor.sh`
   - Verify firewall settings
   - Check nginx configuration

3. **WebSocket connection issues:**
   - Verify port 8080 is open
   - Check firewall settings
   - Test connection: `nc -z localhost 8080`

## 📞 Support

For support and questions:
- GitHub Issues: [Your Repository]
- Discord: [Your Discord Server]
- Email: [Your Support Email]

---

**🎉 Your Decentralize AI Network is ready to change the world!**
EOF

print_success "Deployment README created"

# Final summary
echo ""
print_header
print_success "🎉 Decentralize AI Network deployment completed successfully!"
echo ""
print_status "📋 Next Steps:"
echo "   1. Update .env file with your configuration"
echo "   2. Run: ./start.sh"
echo "   3. Open: http://localhost:3000"
echo "   4. For production: Follow DEPLOYMENT_README.md"
echo ""
print_status "📊 Available Commands:"
echo "   • ./start.sh     - Start the application"
echo "   • ./stop.sh      - Stop the application"
echo "   • ./restart.sh   - Restart the application"
echo "   • ./monitor.sh   - Check status"
echo "   • ./setup-ssl.sh - Set up SSL certificate"
echo ""
print_status "🌐 Access Points:"
echo "   • Web Interface: http://localhost:3000"
echo "   • WebSocket: ws://localhost:8080"
echo "   • API Base: http://localhost:3000/api"
echo "   • Health Check: http://localhost:3000/health"
echo ""
print_success "🚀 Your Decentralize AI Network is ready to deploy!"
print_header
