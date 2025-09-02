# Decentralize AI Network - Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the complete Decentralize AI network infrastructure, including smart contracts, node software, federated AI system, and DAO management tools.

## Prerequisites

### System Requirements

- **Operating System**: Linux (Ubuntu 20.04+), macOS, or Windows with WSL2
- **RAM**: Minimum 8GB, Recommended 16GB+
- **Storage**: Minimum 100GB free space
- **CPU**: Multi-core processor (4+ cores recommended)
- **Network**: Stable internet connection

### Software Dependencies

- **Node.js**: v18.0.0 or higher
- **Python**: v3.8 or higher
- **Rust**: Latest stable version
- **Git**: Latest version
- **Docker**: v20.10+ (optional, for containerized deployment)

## Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone https://github.com/decentralize-ai/network.git
cd decentralize-ai

# Run bootstrap script
./scripts/bootstrap.sh
```

### 2. Deploy Network

```bash
# Deploy complete network
./scripts/deploy.sh
```

### 3. Verify Deployment

```bash
# Check network status
./scripts/status.sh

# View logs
tail -f logs/*.log
```

## Detailed Deployment

### Phase 1: Smart Contracts

1. **Deploy DAI Token Contract**

   ```bash
   cd contracts
   npm install
   npx hardhat compile
   npx hardhat run scripts/deploy-token.js --network localhost
   ```

2. **Deploy Governance Contract**

   ```bash
   npx hardhat run scripts/deploy-governance.js --network localhost
   ```

3. **Deploy Staking Contract**

   ```bash
   npx hardhat run scripts/deploy-staking.js --network localhost
   ```

4. **Deploy Contribution System**

   ```bash
   npx hardhat run scripts/deploy-contribution.js --network localhost
   ```

### Phase 2: Node Software

1. **Start Blockchain Node**

   ```bash
   cd nodes
   npm install
   npm start
   ```

2. **Configure Validator** (Optional)

   ```bash
   # Register as validator
   curl -X POST http://localhost:8080/validator/register \
     -H "Content-Type: application/json" \
     -d '{"stake": 10000, "nodeId": "validator-1"}'
   ```

### Phase 3: Federated AI System

1. **Setup AI Environment**

   ```bash
   cd ai
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

2. **Start AI Coordinator**

   ```bash
   python3 federated_learning.py
   ```

3. **Join Federation** (as participant)

   ```bash
   python3 client.py --join --coordinator-url http://localhost:8080
   ```

### Phase 4: DAO Infrastructure

1. **Start DAO Manager**

   ```bash
   cd dao
   npm install
   npm start
   ```

2. **Initialize Treasury**

   ```bash
   curl -X POST http://localhost:8082/treasury/initialize \
     -H "Content-Type: application/json" \
     -d '{"initialBalance": 1000000}'
   ```

## Configuration

### Network Configuration

Edit `config/network.json`:

```json
{
  "name": "decentralize-ai",
  "chainId": 1337,
  "rpcPort": 8545,
  "p2pPort": 30303,
  "apiPort": 8080,
  "consensus": "proof-of-stake",
  "blockTime": 15,
  "maxValidators": 100,
  "minStake": "10000000000000000000000"
}
```

### Environment Variables

Create `.env` file:

```bash
# Network Configuration
NETWORK_NAME=decentralize-ai
CHAIN_ID=1337
RPC_PORT=8545
P2P_PORT=30303
API_PORT=8080

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
API_PORT=8080

# P2P
P2P_ENABLED=true
P2P_HOST=0.0.0.0
P2P_PORT=30303
```

## Service Management

### Start Services

```bash
# Start all services
./scripts/start-node.sh

# Start individual services
cd nodes && npm start
cd ai && python3 federated_learning.py
cd dao && npm start
```

### Stop Services

```bash
# Stop all services
./scripts/stop.sh

# Stop individual services
pkill -f "decentralize-ai-node"
pkill -f "federated_learning.py"
pkill -f "dao-manager"
```

### Monitor Services

```bash
# Check status
./scripts/status.sh

# View logs
tail -f logs/network.log
tail -f logs/ai.log
tail -f logs/dao.log

# Monitor resources
htop
```

## API Endpoints

### Blockchain Node

- **Health Check**: `GET http://localhost:8080/health`
- **Node Info**: `GET http://localhost:8080/info`
- **Blockchain Info**: `GET http://localhost:8080/blockchain/info`
- **Submit Transaction**: `POST http://localhost:8080/blockchain/transaction`

### AI Coordinator

- **Available Models**: `GET http://localhost:8080/ai/models`
- **Submit Contribution**: `POST http://localhost:8080/ai/contribution`
- **Training Status**: `GET http://localhost:8080/ai/training/status`

### DAO Manager

- **Proposals**: `GET http://localhost:8082/governance/proposals`
- **Create Proposal**: `POST http://localhost:8082/governance/proposals`
- **Treasury Balance**: `GET http://localhost:8082/treasury/balance`
- **Community Members**: `GET http://localhost:8082/community/members`

## Troubleshooting

### Common Issues

1. **Port Already in Use**

   ```bash
   # Find process using port
   lsof -i :8080
   
   # Kill process
   kill -9 <PID>
   ```

2. **Database Connection Error**

   ```bash
   # Check database file
   ls -la data/network.db
   
   # Recreate database
   rm data/network.db
   ./scripts/bootstrap.sh
   ```

3. **Node Sync Issues**

   ```bash
   # Reset node data
   rm -rf data/blocks
   rm -rf data/state
   ./scripts/start-node.sh
   ```

4. **AI Coordinator Errors**

   ```bash
   # Check Python environment
   source ai/venv/bin/activate
   pip list
   
   # Reinstall dependencies
   pip install -r ai/requirements.txt
   ```

### Log Analysis

```bash
# View error logs
grep -i error logs/*.log

# View warning logs
grep -i warning logs/*.log

# Monitor real-time logs
tail -f logs/network.log | grep -i error
```

## Security Considerations

### Key Management

- Store private keys securely
- Use hardware wallets for production
- Implement key rotation policies
- Backup keys in secure locations

### Network Security

- Use firewalls to restrict access
- Enable SSL/TLS for API endpoints
- Implement rate limiting
- Monitor for suspicious activity

### Smart Contract Security

- Audit all smart contracts
- Use formal verification tools
- Implement upgrade mechanisms
- Monitor for vulnerabilities

## Production Deployment

### Scaling Considerations

- Use load balancers for API endpoints
- Implement database clustering
- Use CDN for static content
- Monitor resource usage

### High Availability

- Deploy multiple validator nodes
- Use redundant storage systems
- Implement failover mechanisms
- Monitor system health

### Backup and Recovery

- Regular database backups
- Snapshot blockchain state
- Document recovery procedures
- Test backup restoration

## Support

### Community Support

- **Discord**: <https://discord.gg/decentralize-ai>
- **Telegram**: <https://t.me/decentralize_ai>
- **GitHub**: <https://github.com/decentralize-ai/network>

### Documentation

- **Whitepaper**: `docs/WHITEPAPER.md`
- **API Reference**: `docs/API.md`
- **Developer Guide**: `docs/DEVELOPER_GUIDE.md`

### Reporting Issues

- **Bug Reports**: GitHub Issues
- **Security Issues**: <security@decentralize-ai.org>
- **Feature Requests**: GitHub Discussions

---

## "In a decentralized world, deployment is just the beginning."
