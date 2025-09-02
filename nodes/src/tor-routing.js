/**
 * Decentralize AI - Tor-based Anonymous Routing
 * 
 * This module implements Tor-based anonymous routing for node communication
 * to enhance privacy and resist deanonymization attacks.
 * 
 * Features:
 * - Tor circuit establishment and management
 * - Anonymous peer-to-peer communication
 * - Traffic analysis resistance
 * - Automatic circuit rotation
 * - Jurisdictional flexibility
 * - Forensic countermeasures
 */

const { spawn, exec } = require('child_process');
const net = require('net');
const crypto = require('crypto');
const EventEmitter = require('events');
const fs = require('fs');
const path = require('path');

class TorRouting extends EventEmitter {
    constructor(config) {
        super();
        this.config = config;
        this.torProcess = null;
        this.circuits = new Map();
        this.activeConnections = new Map();
        this.circuitRotationInterval = null;
        this.isRunning = false;
        this.torControlPort = config.torControlPort || 9051;
        this.torSocksPort = config.torSocksPort || 9050;
        this.circuitRotationTime = config.circuitRotationTime || 600000; // 10 minutes
        this.maxCircuits = config.maxCircuits || 5;
        
        // Security settings
        this.enableTrafficPadding = config.enableTrafficPadding !== false;
        this.enableCircuitRotation = config.enableCircuitRotation !== false;
        this.enableForensicCountermeasures = config.enableForensicCountermeasures !== false;
    }
    
    /**
     * Initialize Tor routing
     */
    async initialize() {
        try {
            console.log('Initializing Tor routing...');
            
            // Check if Tor is installed
            await this.checkTorInstallation();
            
            // Start Tor process
            await this.startTorProcess();
            
            // Wait for Tor to be ready
            await this.waitForTorReady();
            
            // Initialize circuits
            await this.initializeCircuits();
            
            // Start circuit rotation
            if (this.enableCircuitRotation) {
                this.startCircuitRotation();
            }
            
            this.isRunning = true;
            console.log('Tor routing initialized successfully');
            
        } catch (error) {
            console.error('Failed to initialize Tor routing:', error);
            throw error;
        }
    }
    
    /**
     * Check if Tor is installed
     */
    async checkTorInstallation() {
        return new Promise((resolve, reject) => {
            exec('which tor', (error, stdout, stderr) => {
                if (error) {
                    reject(new Error('Tor is not installed. Please install Tor first.'));
                } else {
                    resolve(stdout.trim());
                }
            });
        });
    }
    
    /**
     * Start Tor process
     */
    async startTorProcess() {
        return new Promise((resolve, reject) => {
            const torConfig = this.generateTorConfig();
            const configFile = path.join(__dirname, 'torrc');
            
            // Write Tor configuration
            fs.writeFileSync(configFile, torConfig);
            
            // Start Tor process
            this.torProcess = spawn('tor', ['-f', configFile], {
                stdio: ['pipe', 'pipe', 'pipe']
            });
            
            this.torProcess.stdout.on('data', (data) => {
                const output = data.toString();
                if (output.includes('Bootstrapped 100%')) {
                    resolve();
                }
            });
            
            this.torProcess.stderr.on('data', (data) => {
                console.error('Tor stderr:', data.toString());
            });
            
            this.torProcess.on('error', (error) => {
                reject(error);
            });
            
            this.torProcess.on('exit', (code) => {
                if (code !== 0) {
                    reject(new Error(`Tor process exited with code ${code}`));
                }
            });
            
            // Timeout after 30 seconds
            setTimeout(() => {
                reject(new Error('Tor startup timeout'));
            }, 30000);
        });
    }
    
    /**
     * Generate Tor configuration
     */
    generateTorConfig() {
        const config = [
            'SocksPort 9050',
            'ControlPort 9051',
            'CookieAuthentication 1',
            'DataDirectory ' + path.join(__dirname, 'tor_data'),
            'Log notice file ' + path.join(__dirname, 'tor.log'),
            'CircuitBuildTimeout 10',
            'NewCircuitPeriod 30',
            'MaxCircuitDirtiness 600',
            'EnforceDistinctSubnets 1',
            'StrictNodes 0',
            'ExitNodes {us},{ca},{gb}',
            'ExcludeNodes {cn},{ru},{ir}',
            'GeoIPFile /usr/share/tor/geoip',
            'GeoIPv6File /usr/share/tor/geoip6'
        ];
        
        if (this.enableTrafficPadding) {
            config.push('ConnectionPadding 1');
            config.push('ReducedConnectionPadding 0');
        }
        
        if (this.enableForensicCountermeasures) {
            config.push('SafeLogging 1');
            config.push('DisableDebuggerAttachment 1');
        }
        
        return config.join('\n');
    }
    
    /**
     * Wait for Tor to be ready
     */
    async waitForTorReady() {
        return new Promise((resolve, reject) => {
            const checkTor = () => {
                const socket = net.createConnection(this.torControlPort, 'localhost');
                
                socket.on('connect', () => {
                    socket.end();
                    resolve();
                });
                
                socket.on('error', () => {
                    setTimeout(checkTor, 1000);
                });
            };
            
            checkTor();
            
            // Timeout after 30 seconds
            setTimeout(() => {
                reject(new Error('Tor control port not ready'));
            }, 30000);
        });
    }
    
    /**
     * Initialize Tor circuits
     */
    async initializeCircuits() {
        for (let i = 0; i < this.maxCircuits; i++) {
            await this.createCircuit();
        }
    }
    
    /**
     * Create a new Tor circuit
     */
    async createCircuit() {
        try {
            const circuitId = crypto.randomBytes(4).toString('hex');
            const circuit = {
                id: circuitId,
                createdAt: Date.now(),
                status: 'building',
                nodes: [],
                bandwidth: 0,
                latency: 0
            };
            
            this.circuits.set(circuitId, circuit);
            
            // Build circuit through Tor control interface
            await this.buildCircuit(circuitId);
            
            console.log(`Circuit ${circuitId} created`);
            return circuitId;
            
        } catch (error) {
            console.error('Failed to create circuit:', error);
            throw error;
        }
    }
    
    /**
     * Build circuit through Tor control interface
     */
    async buildCircuit(circuitId) {
        return new Promise((resolve, reject) => {
            const socket = net.createConnection(this.torControlPort, 'localhost');
            let response = '';
            
            socket.on('data', (data) => {
                response += data.toString();
                
                if (response.includes('250 OK')) {
                    socket.end();
                    resolve();
                } else if (response.includes('551')) {
                    socket.end();
                    reject(new Error('Circuit build failed'));
                }
            });
            
            socket.on('error', (error) => {
                reject(error);
            });
            
            // Send circuit build command
            socket.write(`EXTENDCIRCUIT ${circuitId}\r\n`);
        });
    }
    
    /**
     * Start circuit rotation
     */
    startCircuitRotation() {
        this.circuitRotationInterval = setInterval(async () => {
            try {
                await this.rotateCircuits();
            } catch (error) {
                console.error('Circuit rotation failed:', error);
            }
        }, this.circuitRotationTime);
    }
    
    /**
     * Rotate circuits for enhanced anonymity
     */
    async rotateCircuits() {
        console.log('Rotating Tor circuits...');
        
        // Close old circuits
        const now = Date.now();
        for (const [circuitId, circuit] of this.circuits) {
            if (now - circuit.createdAt > this.circuitRotationTime) {
                await this.closeCircuit(circuitId);
            }
        }
        
        // Create new circuits
        const currentCircuits = this.circuits.size;
        const neededCircuits = this.maxCircuits - currentCircuits;
        
        for (let i = 0; i < neededCircuits; i++) {
            await this.createCircuit();
        }
        
        console.log(`Circuit rotation completed. Active circuits: ${this.circuits.size}`);
    }
    
    /**
     * Close a circuit
     */
    async closeCircuit(circuitId) {
        try {
            const socket = net.createConnection(this.torControlPort, 'localhost');
            
            socket.on('data', (data) => {
                if (data.toString().includes('250 OK')) {
                    socket.end();
                }
            });
            
            socket.write(`CLOSECIRCUIT ${circuitId}\r\n`);
            this.circuits.delete(circuitId);
            
        } catch (error) {
            console.error(`Failed to close circuit ${circuitId}:`, error);
        }
    }
    
    /**
     * Establish anonymous connection
     */
    async connectAnonymously(targetHost, targetPort, circuitId = null) {
        try {
            // Select circuit if not specified
            if (!circuitId) {
                circuitId = this.selectBestCircuit();
            }
            
            if (!circuitId) {
                throw new Error('No available circuits');
            }
            
            // Create SOCKS5 connection through Tor
            const connection = await this.createSocksConnection(targetHost, targetPort);
            
            // Store connection
            const connectionId = crypto.randomBytes(8).toString('hex');
            this.activeConnections.set(connectionId, {
                id: connectionId,
                circuitId: circuitId,
                targetHost: targetHost,
                targetPort: targetPort,
                socket: connection,
                createdAt: Date.now()
            });
            
            console.log(`Anonymous connection established to ${targetHost}:${targetPort}`);
            return connectionId;
            
        } catch (error) {
            console.error('Failed to establish anonymous connection:', error);
            throw error;
        }
    }
    
    /**
     * Select best circuit for connection
     */
    selectBestCircuit() {
        let bestCircuit = null;
        let bestScore = -1;
        
        for (const [circuitId, circuit] of this.circuits) {
            if (circuit.status === 'ready') {
                // Score based on bandwidth and latency
                const score = circuit.bandwidth / (circuit.latency + 1);
                if (score > bestScore) {
                    bestScore = score;
                    bestCircuit = circuitId;
                }
            }
        }
        
        return bestCircuit;
    }
    
    /**
     * Create SOCKS5 connection through Tor
     */
    async createSocksConnection(targetHost, targetPort) {
        return new Promise((resolve, reject) => {
            const socket = net.createConnection(this.torSocksPort, 'localhost');
            
            // SOCKS5 handshake
            socket.write(Buffer.from([0x05, 0x01, 0x00])); // Version, auth methods, no auth
            
            socket.on('data', (data) => {
                if (data[0] === 0x05 && data[1] === 0x00) {
                    // SOCKS5 connection request
                    const request = Buffer.alloc(10);
                    request[0] = 0x05; // Version
                    request[1] = 0x01; // Connect
                    request[2] = 0x00; // Reserved
                    request[3] = 0x03; // Domain name
                    request[4] = targetHost.length; // Domain length
                    request.write(targetHost, 5);
                    request.writeUInt16BE(targetPort, 5 + targetHost.length);
                    
                    socket.write(request);
                } else if (data[0] === 0x05 && data[1] === 0x00) {
                    // Connection established
                    resolve(socket);
                } else {
                    reject(new Error('SOCKS5 connection failed'));
                }
            });
            
            socket.on('error', (error) => {
                reject(error);
            });
        });
    }
    
    /**
     * Send data through anonymous connection
     */
    async sendData(connectionId, data) {
        const connection = this.activeConnections.get(connectionId);
        if (!connection) {
            throw new Error('Connection not found');
        }
        
        // Add traffic padding if enabled
        if (this.enableTrafficPadding) {
            data = this.addTrafficPadding(data);
        }
        
        // Send data through Tor circuit
        connection.socket.write(data);
    }
    
    /**
     * Add traffic padding to resist analysis
     */
    addTrafficPadding(data) {
        const paddingSize = Math.floor(Math.random() * 1024) + 512; // 512-1536 bytes
        const padding = crypto.randomBytes(paddingSize);
        
        return Buffer.concat([data, padding]);
    }
    
    /**
     * Close anonymous connection
     */
    async closeConnection(connectionId) {
        const connection = this.activeConnections.get(connectionId);
        if (connection) {
            connection.socket.end();
            this.activeConnections.delete(connectionId);
            console.log(`Connection ${connectionId} closed`);
        }
    }
    
    /**
     * Get routing statistics
     */
    getRoutingStats() {
        return {
            isRunning: this.isRunning,
            activeCircuits: this.circuits.size,
            activeConnections: this.activeConnections.size,
            torControlPort: this.torControlPort,
            torSocksPort: this.torSocksPort,
            circuitRotationEnabled: this.enableCircuitRotation,
            trafficPaddingEnabled: this.enableTrafficPadding,
            forensicCountermeasuresEnabled: this.enableForensicCountermeasures
        };
    }
    
    /**
     * Stop Tor routing
     */
    async stop() {
        console.log('Stopping Tor routing...');
        
        this.isRunning = false;
        
        // Stop circuit rotation
        if (this.circuitRotationInterval) {
            clearInterval(this.circuitRotationInterval);
        }
        
        // Close all connections
        for (const connectionId of this.activeConnections.keys()) {
            await this.closeConnection(connectionId);
        }
        
        // Close all circuits
        for (const circuitId of this.circuits.keys()) {
            await this.closeCircuit(circuitId);
        }
        
        // Stop Tor process
        if (this.torProcess) {
            this.torProcess.kill();
        }
        
        console.log('Tor routing stopped');
    }
}

module.exports = TorRouting;
