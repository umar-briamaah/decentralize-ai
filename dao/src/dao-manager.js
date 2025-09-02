/**
 * Decentralize AI DAO Manager
 * Handles governance, treasury, and community management
 */

const express = require('express');
const { ethers } = require('ethers');
const Web3 = require('web3');
const ipfsClient = require('ipfs-http-client');
const Database = require('./database');
const Treasury = require('./treasury');
const Voting = require('./voting');
const Logger = require('./logger');

class DAOManager {
    constructor(config) {
        this.config = config;
        this.logger = new Logger(config.logLevel);
        this.database = new Database(config.databaseUrl);
        this.treasury = new Treasury(config);
        this.voting = new Voting(config);
        this.web3 = new Web3(config.ethereumRpc);
        this.ipfs = ipfsClient(config.ipfsGateway);
        this.app = express();
        
        this.setupRoutes();
    }
    
    async initialize() {
        await this.database.initialize();
        await this.treasury.initialize();
        await this.voting.initialize();
        this.logger.info('DAO Manager initialized');
    }
    
    setupRoutes() {
        // Governance routes
        this.app.get('/governance/proposals', this.getProposals.bind(this));
        this.app.post('/governance/proposals', this.createProposal.bind(this));
        this.app.post('/governance/vote', this.castVote.bind(this));
        
        // Treasury routes
        this.app.get('/treasury/balance', this.getTreasuryBalance.bind(this));
        this.app.post('/treasury/transfer', this.transferFunds.bind(this));
        
        // Community routes
        this.app.get('/community/members', this.getMembers.bind(this));
        this.app.post('/community/join', this.joinCommunity.bind(this));
    }
    
    async getProposals(req, res) {
        try {
            const proposals = await this.database.getProposals();
            res.json(proposals);
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    }
    
    async createProposal(req, res) {
        try {
            const proposal = await this.voting.createProposal(req.body);
            res.json(proposal);
        } catch (error) {
            res.status(400).json({ error: error.message });
        }
    }
    
    async castVote(req, res) {
        try {
            const result = await this.voting.castVote(req.body);
            res.json(result);
        } catch (error) {
            res.status(400).json({ error: error.message });
        }
    }
    
    async getTreasuryBalance(req, res) {
        try {
            const balance = await this.treasury.getBalance();
            res.json({ balance });
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    }
    
    async transferFunds(req, res) {
        try {
            const result = await this.treasury.transfer(req.body);
            res.json(result);
        } catch (error) {
            res.status(400).json({ error: error.message });
        }
    }
    
    async getMembers(req, res) {
        try {
            const members = await this.database.getMembers();
            res.json(members);
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    }
    
    async joinCommunity(req, res) {
        try {
            const result = await this.database.addMember(req.body);
            res.json(result);
        } catch (error) {
            res.status(400).json({ error: error.message });
        }
    }
    
    async start() {
        await this.initialize();
        this.app.listen(this.config.port, () => {
            this.logger.info(`DAO Manager started on port ${this.config.port}`);
        });
    }
}

module.exports = DAOManager;
