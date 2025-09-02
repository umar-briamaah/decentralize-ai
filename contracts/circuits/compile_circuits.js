#!/usr/bin/env node

/**
 * Decentralize AI - ZK Circuit Compilation Script
 * 
 * This script compiles Circom circuits for anonymous contribution verification
 * and generates the necessary artifacts for integration with the smart contracts.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class ZKCircuitCompiler {
    constructor() {
        this.circuitsDir = __dirname;
        this.buildDir = path.join(this.circuitsDir, 'build');
        this.artifactsDir = path.join(this.circuitsDir, 'artifacts');
        
        // Ensure directories exist
        this.ensureDirectories();
    }
    
    ensureDirectories() {
        if (!fs.existsSync(this.buildDir)) {
            fs.mkdirSync(this.buildDir, { recursive: true });
        }
        if (!fs.existsSync(this.artifactsDir)) {
            fs.mkdirSync(this.artifactsDir, { recursive: true });
        }
    }
    
    /**
     * Compile a Circom circuit
     * @param {string} circuitName - Name of the circuit file (without .circom)
     */
    compileCircuit(circuitName) {
        console.log(`Compiling circuit: ${circuitName}`);
        
        const circuitFile = path.join(this.circuitsDir, `${circuitName}.circom`);
        const outputFile = path.join(this.buildDir, `${circuitName}.r1cs`);
        const wasmFile = path.join(this.buildDir, `${circuitName}.wasm`);
        const symFile = path.join(this.buildDir, `${circuitName}.sym`);
        
        try {
            // Compile circuit to R1CS
            execSync(`circom ${circuitFile} --r1cs --wasm --sym --c -o ${this.buildDir}`, {
                stdio: 'inherit',
                cwd: this.circuitsDir
            });
            
            console.log(`✅ Circuit ${circuitName} compiled successfully`);
            
            // Generate setup files
            this.generateSetup(circuitName);
            
            // Generate verification key
            this.generateVerificationKey(circuitName);
            
            return {
                r1cs: outputFile,
                wasm: wasmFile,
                sym: symFile
            };
            
        } catch (error) {
            console.error(`❌ Failed to compile circuit ${circuitName}:`, error.message);
            throw error;
        }
    }
    
    /**
     * Generate trusted setup for the circuit
     * @param {string} circuitName - Name of the circuit
     */
    generateSetup(circuitName) {
        console.log(`Generating trusted setup for ${circuitName}`);
        
        const r1csFile = path.join(this.buildDir, `${circuitName}.r1cs`);
        const ptauFile = path.join(this.buildDir, `${circuitName}.ptau`);
        const zkeyFile = path.join(this.buildDir, `${circuitName}.zkey`);
        
        try {
            // Generate powers of tau
            execSync(`snarkjs powersoftau new bn128 12 ${ptauFile} -v`, {
                stdio: 'inherit',
                cwd: this.buildDir
            });
            
            // Contribute to powers of tau
            execSync(`snarkjs powersoftau contribute ${ptauFile} ${ptauFile} --name="Decentralize AI" -v`, {
                stdio: 'inherit',
                cwd: this.buildDir
            });
            
            // Prepare phase 2
            execSync(`snarkjs powersoftau prepare phase2 ${ptauFile} ${ptauFile} -v`, {
                stdio: 'inherit',
                cwd: this.buildDir
            });
            
            // Generate zkey
            execSync(`snarkjs groth16 setup ${r1csFile} ${ptauFile} ${zkeyFile}`, {
                stdio: 'inherit',
                cwd: this.buildDir
            });
            
            // Contribute to zkey
            execSync(`snarkjs zkey contribute ${zkeyFile} ${zkeyFile} --name="Decentralize AI Contributor" -v`, {
                stdio: 'inherit',
                cwd: this.buildDir
            });
            
            console.log(`✅ Trusted setup completed for ${circuitName}`);
            
        } catch (error) {
            console.error(`❌ Failed to generate setup for ${circuitName}:`, error.message);
            throw error;
        }
    }
    
    /**
     * Generate verification key
     * @param {string} circuitName - Name of the circuit
     */
    generateVerificationKey(circuitName) {
        console.log(`Generating verification key for ${circuitName}`);
        
        const zkeyFile = path.join(this.buildDir, `${circuitName}.zkey`);
        const vkeyFile = path.join(this.artifactsDir, `${circuitName}_verification_key.json`);
        
        try {
            // Extract verification key
            execSync(`snarkjs zkey export verificationkey ${zkeyFile} ${vkeyFile}`, {
                stdio: 'inherit',
                cwd: this.buildDir
            });
            
            console.log(`✅ Verification key generated for ${circuitName}`);
            
        } catch (error) {
            console.error(`❌ Failed to generate verification key for ${circuitName}:`, error.message);
            throw error;
        }
    }
    
    /**
     * Generate Solidity verifier contract
     * @param {string} circuitName - Name of the circuit
     */
    generateVerifierContract(circuitName) {
        console.log(`Generating Solidity verifier for ${circuitName}`);
        
        const zkeyFile = path.join(this.buildDir, `${circuitName}.zkey`);
        const verifierFile = path.join(this.artifactsDir, `${circuitName}_verifier.sol`);
        
        try {
            // Generate verifier contract
            execSync(`snarkjs zkey export solidityverifier ${zkeyFile} ${verifierFile}`, {
                stdio: 'inherit',
                cwd: this.buildDir
            });
            
            console.log(`✅ Solidity verifier generated for ${circuitName}`);
            
        } catch (error) {
            console.error(`❌ Failed to generate verifier contract for ${circuitName}:`, error.message);
            throw error;
        }
    }
    
    /**
     * Compile all circuits
     */
    compileAll() {
        const circuits = [
            'contribution_verification',
            'reputation_scoring',
            'quality_assessment'
        ];
        
        console.log('🚀 Starting ZK circuit compilation...');
        
        const results = {};
        
        for (const circuit of circuits) {
            try {
                results[circuit] = this.compileCircuit(circuit);
                this.generateVerifierContract(circuit);
            } catch (error) {
                console.error(`Failed to compile circuit ${circuit}:`, error.message);
                process.exit(1);
            }
        }
        
        // Generate integration artifacts
        this.generateIntegrationArtifacts(results);
        
        console.log('✅ All circuits compiled successfully!');
        return results;
    }
    
    /**
     * Generate integration artifacts for smart contracts
     * @param {Object} results - Compilation results
     */
    generateIntegrationArtifacts(results) {
        console.log('Generating integration artifacts...');
        
        const integrationData = {
            circuits: {},
            verificationKeys: {},
            verifierContracts: {}
        };
        
        for (const [circuitName, result] of Object.entries(results)) {
            integrationData.circuits[circuitName] = {
                r1cs: result.r1cs,
                wasm: result.wasm,
                sym: result.sym
            };
            
            // Load verification key
            const vkeyFile = path.join(this.artifactsDir, `${circuitName}_verification_key.json`);
            if (fs.existsSync(vkeyFile)) {
                integrationData.verificationKeys[circuitName] = JSON.parse(fs.readFileSync(vkeyFile, 'utf8'));
            }
            
            // Load verifier contract
            const verifierFile = path.join(this.artifactsDir, `${circuitName}_verifier.sol`);
            if (fs.existsSync(verifierFile)) {
                integrationData.verifierContracts[circuitName] = fs.readFileSync(verifierFile, 'utf8');
            }
        }
        
        // Save integration data
        const integrationFile = path.join(this.artifactsDir, 'integration_data.json');
        fs.writeFileSync(integrationFile, JSON.stringify(integrationData, null, 2));
        
        console.log('✅ Integration artifacts generated');
    }
    
    /**
     * Generate test data for circuits
     */
    generateTestData() {
        console.log('Generating test data...');
        
        const testData = {
            contributionVerification: {
                publicInputs: {
                    contributionHash: "0x1234567890abcdef",
                    reputationThreshold: 50,
                    qualityThreshold: 70,
                    timeWindow: 1700000000
                },
                privateInputs: {
                    contributorSecret: "0xabcdef1234567890",
                    contributionData: "0x9876543210fedcba",
                    qualityScore: 85,
                    reputationScore: 75,
                    timestamp: 1699000000,
                    proofOfWork: 12345
                }
            },
            reputationScoring: {
                inputs: {
                    totalContributions: 25,
                    averageQuality: 80,
                    consistencyScore: 85,
                    peerReviews: 90
                }
            },
            qualityAssessment: {
                inputs: {
                    technicalQuality: 85,
                    innovation: 90,
                    impact: 80,
                    documentation: 75,
                    communityBenefit: 85
                }
            }
        };
        
        const testDataFile = path.join(this.artifactsDir, 'test_data.json');
        fs.writeFileSync(testDataFile, JSON.stringify(testData, null, 2));
        
        console.log('✅ Test data generated');
    }
}

// Main execution
if (require.main === module) {
    const compiler = new ZKCircuitCompiler();
    
    try {
        compiler.compileAll();
        compiler.generateTestData();
        console.log('🎉 ZK circuit compilation completed successfully!');
    } catch (error) {
        console.error('💥 ZK circuit compilation failed:', error.message);
        process.exit(1);
    }
}

module.exports = ZKCircuitCompiler;
