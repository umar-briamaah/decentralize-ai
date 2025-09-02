#!/usr/bin/env node

/**
 * Decentralize AI Network Node
 * 
 * This is the main entry point for the Decentralize AI network node.
 * It handles:
 * - P2P networking and peer discovery
 * - Consensus mechanism (Proof of Stake)
 * - Block production and validation
 * - Smart contract execution
 * - AI model coordination
 * - API endpoints for interaction
 */

const express = require('express');
const WebSocket = require('ws');
const { createLibp2p } = require('libp2p');
const { TCP } = require('libp2p-tcp');
const { WebSockets } = require('libp2p-websockets');
const { Noise } = require('libp2p-noise');
const { Mplex } = require('libp2p-mplex');
const { KadDHT } = require('libp2p-kad-dht');
const { GossipSub } = require('libp2p-pubsub');
const { createFromJSON } = require('peer-id');
const { ethers } = require('ethers');
const Database = require('./database');
const Blockchain = require('./blockchain');
const Consensus = require('./consensus');
const AICoordinator = require('./ai-coordinator');
const Logger = require('./logger');
const Config = require('./config');
const { RateLimiterMemory } = require('rate-limiter-flexible');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');

class DecentralizeAINode {
    constructor() {
        this.config = new Config();
        this.logger = new Logger(this.config.logLevel);
        this.database = new Database(this.config.databaseUrl);
        this.blockchain = new Blockchain(this.database);
        this.consensus = new Consensus(this.blockchain, this.config);
        this.aiCoordinator = new AICoordinator(this.config);
        
        this.app = express();
        this.server = null;
        this.wss = null;
        this.libp2p = null;
        this.peerId = null;
        this.isRunning = false;
        this.isValidator = false;
        this.validatorStake = 0;
        
        // Rate limiting
        this.rateLimiter = new RateLimiterMemory({
            keyPrefix: 'dai_node',
            points: 100, // Number of requests
            duration: 60, // Per 60 seconds
        });
        
        this.setupMiddleware();
        this.setupRoutes();
        this.setupWebSocket();
    }
    
    /**
     * Initialize the node
     */
    async initialize() {
        try {
            this.logger.info('Initializing Decentralize AI Node...');
            
            // Initialize database
            await this.database.initialize();
            this.logger.info('Database initialized');
            
            // Initialize blockchain
            await this.blockchain.initialize();
            this.logger.info('Blockchain initialized');
            
            // Initialize consensus
            await this.consensus.initialize();
            this.logger.info('Consensus initialized');
            
            // Initialize AI coordinator
            await this.aiCoordinator.initialize();
            this.logger.info('AI Coordinator initialized');
            
            // Initialize P2P networking
            await this.initializeP2P();
            this.logger.info('P2P networking initialized');
            
            // Check validator status
            await this.checkValidatorStatus();
            
            this.logger.info('Node initialization completed');
            
        } catch (error) {
            this.logger.error('Failed to initialize node:', error);
            throw error;
        }
    }
    
    /**
     * Initialize P2P networking
     */
    async initializeP2P() {
        try {
            // Create or load peer ID
            this.peerId = await this.createOrLoadPeerId();
            
            // Create LibP2P node
            this.libp2p = await createLibp2p({
                peerId: this.peerId,
                addresses: {
                    listen: [
                        `/ip4/0.0.0.0/tcp/${this.config.p2pPort}`,
                        `/ip4/0.0.0.0/tcp/${this.config.p2pPort}/ws`
                    ]
                },
                transports: [
                    new TCP(),
                    new WebSockets()
                ],
                connectionEncryption: [new Noise()],
                streamMuxers: [new Mplex()],
                dht: new KadDHT({
                    kBucketSize: 20,
                    clientMode: false
                }),
                pubsub: new GossipSub({
                    allowPublishToZeroPeers: true,
                    doPX: true
                })
            });
            
            // Set up event handlers
            this.setupP2PEventHandlers();
            
            // Start LibP2P
            await this.libp2p.start();
            this.logger.info(`P2P node started with peer ID: ${this.peerId.toString()}`);
            
            // Connect to bootstrap nodes
            await this.connectToBootstrapNodes();
            
        } catch (error) {
            this.logger.error('Failed to initialize P2P:', error);
            throw error;
        }
    }
    
    /**
     * Create or load peer ID
     */
    async createOrLoadPeerId() {
        try {
            // Try to load existing peer ID
            const peerIdData = await this.database.getPeerId();
            if (peerIdData) {
                return await createFromJSON(peerIdData);
            }
        } catch (error) {
            this.logger.warn('Could not load existing peer ID, creating new one');
        }
        
        // Create new peer ID
        const peerId = await createFromJSON(await this.generatePeerId());
        await this.database.savePeerId(peerId.toJSON());
        return peerId;
    }
    
    /**
     * Generate new peer ID
     */
    async generatePeerId() {
        const { createEd25519PeerId } = await import('@libp2p/peer-id-factory');
        const peerId = await createEd25519PeerId();
        return peerId.toJSON();
    }
    
    /**
     * Set up P2P event handlers
     */
    setupP2PEventHandlers() {
        this.libp2p.addEventListener('peer:connect', (event) => {
            this.logger.info(`Connected to peer: ${event.detail.toString()}`);
        });
        
        this.libp2p.addEventListener('peer:disconnect', (event) => {
            this.logger.info(`Disconnected from peer: ${event.detail.toString()}`);
        });
        
        this.libp2p.addEventListener('peer:discovery', (event) => {
            this.logger.info(`Discovered peer: ${event.detail.toString()}`);
        });
        
        // Handle incoming messages
        this.libp2p.pubsub.addEventListener('message', (event) => {
            this.handleIncomingMessage(event.detail);
        });
    }
    
    /**
     * Connect to bootstrap nodes
     */
    async connectToBootstrapNodes() {
        const bootstrapNodes = this.config.bootstrapNodes;
        
        for (const node of bootstrapNodes) {
            try {
                await this.libp2p.dial(node);
                this.logger.info(`Connected to bootstrap node: ${node}`);
            } catch (error) {
                this.logger.warn(`Failed to connect to bootstrap node ${node}:`, error.message);
            }
        }
    }
    
    /**
     * Check validator status
     */
    async checkValidatorStatus() {
        try {
            // Check if this node is a validator
            const validatorInfo = await this.database.getValidatorInfo(this.peerId.toString());
            if (validatorInfo && validatorInfo.isActive) {
                this.isValidator = true;
                this.validatorStake = validatorInfo.stake;
                this.logger.info(`Node is a validator with stake: ${this.validatorStake}`);
            } else {
                this.logger.info('Node is not a validator');
            }
        } catch (error) {
            this.logger.error('Failed to check validator status:', error);
        }
    }
    
    /**
     * Set up middleware
     */
    setupMiddleware() {
        // Security middleware
        this.app.use(helmet());
        
        // CORS middleware
        this.app.use(cors({
            origin: this.config.allowedOrigins,
            credentials: true
        }));
        
        // Compression middleware
        this.app.use(compression());
        
        // Body parsing middleware
        this.app.use(express.json({ limit: '10mb' }));
        this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));
        
        // Rate limiting middleware
        this.app.use(async (req, res, next) => {
            try {
                await this.rateLimiter.consume(req.ip);
                next();
            } catch (rejRes) {
                res.status(429).json({ error: 'Too many requests' });
            }
        });
        
        // Logging middleware
        this.app.use((req, res, next) => {
            this.logger.info(`${req.method} ${req.path} - ${req.ip}`);
            next();
        });
    }
    
    /**
     * Set up API routes
     */
    setupRoutes() {
        // Health check
        this.app.get('/health', (req, res) => {
            res.json({
                status: 'healthy',
                timestamp: new Date().toISOString(),
                peerId: this.peerId?.toString(),
                isValidator: this.isValidator,
                validatorStake: this.validatorStake,
                connectedPeers: this.libp2p?.getPeers().length || 0,
                blockHeight: this.blockchain?.getLatestBlock()?.height || 0
            });
        });
        
        // Node info
        this.app.get('/info', (req, res) => {
            res.json({
                peerId: this.peerId?.toString(),
                addresses: this.libp2p?.getMultiaddrs().map(addr => addr.toString()) || [],
                isValidator: this.isValidator,
                validatorStake: this.validatorStake,
                version: this.config.version,
                network: this.config.networkName
            });
        });
        
        // Blockchain info
        this.app.get('/blockchain/info', (req, res) => {
            const latestBlock = this.blockchain.getLatestBlock();
            res.json({
                height: latestBlock?.height || 0,
                hash: latestBlock?.hash || null,
                timestamp: latestBlock?.timestamp || null,
                validator: latestBlock?.validator || null,
                transactionCount: latestBlock?.transactions?.length || 0
            });
        });
        
        // Get block by height
        this.app.get('/blockchain/block/:height', async (req, res) => {
            try {
                const height = parseInt(req.params.height);
                const block = await this.blockchain.getBlock(height);
                if (block) {
                    res.json(block);
                } else {
                    res.status(404).json({ error: 'Block not found' });
                }
            } catch (error) {
                res.status(500).json({ error: error.message });
            }
        });
        
        // Submit transaction
        this.app.post('/blockchain/transaction', async (req, res) => {
            try {
                const transaction = req.body;
                const result = await this.blockchain.submitTransaction(transaction);
                res.json(result);
            } catch (error) {
                res.status(400).json({ error: error.message });
            }
        });
        
        // AI model info
        this.app.get('/ai/models', async (req, res) => {
            try {
                const models = await this.aiCoordinator.getAvailableModels();
                res.json(models);
            } catch (error) {
                res.status(500).json({ error: error.message });
            }
        });
        
        // Submit AI contribution
        this.app.post('/ai/contribution', async (req, res) => {
            try {
                const contribution = req.body;
                const result = await this.aiCoordinator.submitContribution(contribution);
                res.json(result);
            } catch (error) {
                res.status(400).json({ error: error.message });
            }
        });
        
        // Get peer list
        this.app.get('/peers', (req, res) => {
            const peers = this.libp2p?.getPeers().map(peer => ({
                id: peer.toString(),
                addresses: this.libp2p.getMultiaddrs(peer).map(addr => addr.toString())
            })) || [];
            res.json(peers);
        });
        
        // Error handling middleware
        this.app.use((error, req, res, next) => {
            this.logger.error('API Error:', error);
            res.status(500).json({ error: 'Internal server error' });
        });
    }
    
    /**
     * Set up WebSocket server
     */
    setupWebSocket() {
        this.wss = new WebSocket.Server({ port: this.config.wsPort });
        
        this.wss.on('connection', (ws) => {
            this.logger.info('WebSocket client connected');
            
            ws.on('message', async (message) => {
                try {
                    const data = JSON.parse(message);
                    await this.handleWebSocketMessage(ws, data);
                } catch (error) {
                    this.logger.error('WebSocket message error:', error);
                    ws.send(JSON.stringify({ error: 'Invalid message format' }));
                }
            });
            
            ws.on('close', () => {
                this.logger.info('WebSocket client disconnected');
            });
            
            ws.on('error', (error) => {
                this.logger.error('WebSocket error:', error);
            });
        });
    }
    
    /**
     * Handle WebSocket messages
     */
    async handleWebSocketMessage(ws, data) {
        switch (data.type) {
            case 'subscribe':
                // Handle subscription to specific topics
                break;
            case 'unsubscribe':
                // Handle unsubscription
                break;
            case 'ping':
                ws.send(JSON.stringify({ type: 'pong', timestamp: Date.now() }));
                break;
            default:
                ws.send(JSON.stringify({ error: 'Unknown message type' }));
        }
    }
    
    /**
     * Handle incoming P2P messages
     */
    async handleIncomingMessage(message) {
        try {
            const data = JSON.parse(message.data.toString());
            
            switch (data.type) {
                case 'block':
                    await this.handleIncomingBlock(data.payload);
                    break;
                case 'transaction':
                    await this.handleIncomingTransaction(data.payload);
                    break;
                case 'ai_contribution':
                    await this.handleIncomingAIContribution(data.payload);
                    break;
                default:
                    this.logger.warn('Unknown message type:', data.type);
            }
        } catch (error) {
            this.logger.error('Failed to handle incoming message:', error);
        }
    }
    
    /**
     * Handle incoming block
     */
    async handleIncomingBlock(block) {
        try {
            const isValid = await this.blockchain.validateBlock(block);
            if (isValid) {
                await this.blockchain.addBlock(block);
                this.logger.info(`Added block ${block.height} from peer`);
            } else {
                this.logger.warn('Received invalid block');
            }
        } catch (error) {
            this.logger.error('Failed to handle incoming block:', error);
        }
    }
    
    /**
     * Handle incoming transaction
     */
    async handleIncomingTransaction(transaction) {
        try {
            const isValid = await this.blockchain.validateTransaction(transaction);
            if (isValid) {
                await this.blockchain.addTransaction(transaction);
                this.logger.info('Added transaction to mempool');
            } else {
                this.logger.warn('Received invalid transaction');
            }
        } catch (error) {
            this.logger.error('Failed to handle incoming transaction:', error);
        }
    }
    
    /**
     * Handle incoming AI contribution
     */
    async handleIncomingAIContribution(contribution) {
        try {
            await this.aiCoordinator.processContribution(contribution);
            this.logger.info('Processed AI contribution');
        } catch (error) {
            this.logger.error('Failed to handle AI contribution:', error);
        }
    }
    
    /**
     * Start the node
     */
    async start() {
        try {
            if (this.isRunning) {
                this.logger.warn('Node is already running');
                return;
            }
            
            await this.initialize();
            
            // Start HTTP server
            this.server = this.app.listen(this.config.apiPort, this.config.apiHost, () => {
                this.logger.info(`HTTP server started on ${this.config.apiHost}:${this.config.apiPort}`);
            });
            
            this.isRunning = true;
            this.logger.info('Decentralize AI Node started successfully');
            
            // Start consensus if validator
            if (this.isValidator) {
                await this.consensus.start();
            }
            
        } catch (error) {
            this.logger.error('Failed to start node:', error);
            throw error;
        }
    }
    
    /**
     * Stop the node
     */
    async stop() {
        try {
            if (!this.isRunning) {
                this.logger.warn('Node is not running');
                return;
            }
            
            this.logger.info('Stopping Decentralize AI Node...');
            
            // Stop consensus
            if (this.isValidator) {
                await this.consensus.stop();
            }
            
            // Stop HTTP server
            if (this.server) {
                this.server.close();
            }
            
            // Stop WebSocket server
            if (this.wss) {
                this.wss.close();
            }
            
            // Stop LibP2P
            if (this.libp2p) {
                await this.libp2p.stop();
            }
            
            this.isRunning = false;
            this.logger.info('Decentralize AI Node stopped');
            
        } catch (error) {
            this.logger.error('Failed to stop node:', error);
            throw error;
        }
    }
}

// Handle graceful shutdown
process.on('SIGINT', async () => {
    console.log('\nReceived SIGINT, shutting down gracefully...');
    if (global.node) {
        await global.node.stop();
    }
    process.exit(0);
});

process.on('SIGTERM', async () => {
    console.log('\nReceived SIGTERM, shutting down gracefully...');
    if (global.node) {
        await global.node.stop();
    }
    process.exit(0);
});

// Start the node if this file is run directly
if (require.main === module) {
    const node = new DecentralizeAINode();
    global.node = node;
    
    node.start().catch((error) => {
        console.error('Failed to start node:', error);
        process.exit(1);
    });
}

module.exports = DecentralizeAINode;
