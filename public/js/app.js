/**
 * Decentralize AI Network - Modern Web Application
 * Advanced JavaScript framework for the decentralized AI platform
 */

class DecentralizeAIApp {
    constructor() {
        this.ws = null;
        this.isConnected = false;
        this.userWallet = null;
        this.networkData = {};
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.connectWebSocket();
        this.loadInitialData();
        this.setupAnimations();
        this.setupNotifications();
    }

    setupEventListeners() {
        // Smooth scrolling for navigation
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', this.handleSmoothScroll.bind(this));
        });

        // Wallet connection
        const connectBtn = document.querySelector('.connect-btn');
        if (connectBtn) {
            connectBtn.addEventListener('click', this.connectWallet.bind(this));
        }

        // Dashboard refresh
        const refreshBtn = document.querySelector('.refresh-btn');
        if (refreshBtn) {
            refreshBtn.addEventListener('click', this.refreshDashboard.bind(this));
        }

        // Form submissions
        document.querySelectorAll('form').forEach(form => {
            form.addEventListener('submit', this.handleFormSubmit.bind(this));
        });
    }

    connectWebSocket() {
        try {
            this.ws = new WebSocket('ws://localhost:8080');
            
            this.ws.onopen = () => {
                this.isConnected = true;
                this.updateConnectionStatus(true);
                this.showNotification('Connected to Decentralize AI Network', 'success');
                this.sendHeartbeat();
            };
            
            this.ws.onmessage = (event) => {
                const data = JSON.parse(event.data);
                this.handleWebSocketMessage(data);
            };
            
            this.ws.onclose = () => {
                this.isConnected = false;
                this.updateConnectionStatus(false);
                this.showNotification('Disconnected from network', 'warning');
                // Auto-reconnect after 3 seconds
                setTimeout(() => this.connectWebSocket(), 3000);
            };
            
            this.ws.onerror = (error) => {
                console.error('WebSocket error:', error);
                this.showNotification('Connection error', 'error');
            };
        } catch (error) {
            console.error('Failed to connect WebSocket:', error);
            this.showNotification('WebSocket connection failed', 'error');
        }
    }

    handleWebSocketMessage(data) {
        switch (data.type) {
            case 'network_update':
                this.updateNetworkData(data.payload);
                break;
            case 'governance_update':
                this.updateGovernanceData(data.payload);
                break;
            case 'ai_update':
                this.updateAIData(data.payload);
                break;
            case 'notification':
                this.showNotification(data.message, data.level);
                break;
            default:
                console.log('Received message:', data);
        }
    }

    sendHeartbeat() {
        if (this.isConnected) {
            this.ws.send(JSON.stringify({
                type: 'ping',
                timestamp: new Date().toISOString(),
                userWallet: this.userWallet
            }));
        }
    }

    updateConnectionStatus(connected) {
        const indicators = document.querySelectorAll('.status-indicator');
        indicators.forEach(indicator => {
            indicator.className = connected ? 'status-online' : 'status-offline';
        });

        // Update connection text
        const connectionText = document.querySelector('.connection-status');
        if (connectionText) {
            connectionText.textContent = connected ? 'Connected' : 'Disconnected';
            connectionText.className = `connection-status ${connected ? 'text-success' : 'text-error'}`;
        }
    }

    async loadInitialData() {
        try {
            // Load network status
            const statusResponse = await fetch('/api/status');
            const statusData = await statusResponse.json();
            this.networkData = statusData;
            this.updateDashboard(statusData);

            // Load contract information
            const contractsResponse = await fetch('/api/contracts');
            const contractsData = await contractsResponse.json();
            this.updateContractsDisplay(contractsData);

            // Load AI module status
            const aiResponse = await fetch('/api/ai');
            const aiData = await aiResponse.json();
            this.updateAIDisplay(aiData);

            // Load governance data
            const governanceResponse = await fetch('/api/governance');
            const governanceData = await governanceResponse.json();
            this.updateGovernanceDisplay(governanceData);

        } catch (error) {
            console.error('Failed to load initial data:', error);
            this.showNotification('Failed to load network data', 'error');
            // Use simulated data as fallback
            this.loadSimulatedData();
        }
    }

    loadSimulatedData() {
        // Simulate realistic network data
        setTimeout(() => {
            this.animateNumber('totalContributors', 1247);
            this.animateNumber('totalRewards', 89234);
            this.animateNumber('activeProposals', 3);
            this.animateNumber('networkNodes', 156);
            this.animateNumber('modelsTraining', 12);
            this.animateNumber('dataPoints', 89456);
            this.animateNumber('activeProposalsCount', 3);
            this.animateNumber('connectedPeers', 23);
            this.animateNumber('blockHeight', 1847293);
        }, 1000);
    }

    updateDashboard(data) {
        if (data.components) {
            Object.keys(data.components).forEach(component => {
                const element = document.getElementById(`${component}Status`);
                if (element) {
                    element.textContent = data.components[component];
                }
            });
        }
    }

    updateNetworkData(data) {
        if (data.totalContributors) this.animateNumber('totalContributors', data.totalContributors);
        if (data.totalRewards) this.animateNumber('totalRewards', data.totalRewards);
        if (data.activeProposals) this.animateNumber('activeProposals', data.activeProposals);
        if (data.networkNodes) this.animateNumber('networkNodes', data.networkNodes);
        if (data.connectedPeers) this.animateNumber('connectedPeers', data.connectedPeers);
        if (data.blockHeight) this.animateNumber('blockHeight', data.blockHeight);
    }

    updateGovernanceData(data) {
        if (data.activeProposals) this.animateNumber('activeProposalsCount', data.activeProposals);
        if (data.totalVoters) this.animateNumber('totalVoters', data.totalVoters);
        if (data.votingPower) document.getElementById('votingPower').textContent = `${data.votingPower} DAI`;
    }

    updateAIData(data) {
        if (data.modelsTraining) this.animateNumber('modelsTraining', data.modelsTraining);
        if (data.dataPoints) this.animateNumber('dataPoints', data.dataPoints);
    }

    updateContractsDisplay(data) {
        if (data.contracts) {
            data.contracts.forEach(contract => {
                const element = document.getElementById(`${contract.name.toLowerCase()}Status`);
                if (element) {
                    element.textContent = contract.status;
                    element.className = `metric-value ${contract.status.toLowerCase()}`;
                }
            });
        }
    }

    updateAIDisplay(data) {
        if (data.status) {
            const aiStatus = document.getElementById('aiStatus');
            if (aiStatus) {
                aiStatus.textContent = data.status;
            }
        }
    }

    updateGovernanceDisplay(data) {
        if (data.status) {
            const governanceStatus = document.getElementById('governanceStatus');
            if (governanceStatus) {
                governanceStatus.textContent = data.status;
            }
        }
    }

    animateNumber(elementId, targetValue) {
        const element = document.getElementById(elementId);
        if (!element) return;

        const currentValue = parseInt(element.textContent.replace(/[^\d]/g, '')) || 0;
        const increment = (targetValue - currentValue) / 30;
        let current = currentValue;
        
        const timer = setInterval(() => {
            current += increment;
            if ((increment > 0 && current >= targetValue) || (increment < 0 && current <= targetValue)) {
                current = targetValue;
                clearInterval(timer);
            }
            
            // Format number with commas
            const formattedValue = Math.floor(current).toLocaleString();
            element.textContent = formattedValue;
        }, 50);
    }

    async connectWallet() {
        const btn = document.querySelector('.connect-btn');
        const originalText = btn.innerHTML;
        
        btn.innerHTML = '<div class="spinner"></div> Connecting...';
        btn.disabled = true;
        
        try {
            // Simulate wallet connection (replace with actual wallet integration)
            await new Promise(resolve => setTimeout(resolve, 2000));
            
            this.userWallet = '0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6';
            
            btn.innerHTML = '<i class="fas fa-check"></i> Connected';
            btn.style.background = 'var(--success-color)';
            
            this.showNotification('Wallet connected successfully', 'success');
            
            // Update user-specific data
            this.animateNumber('totalVoters', 1);
            document.getElementById('votingPower').textContent = '1,000 DAI';
            
            // Send wallet info to server
            if (this.isConnected) {
                this.ws.send(JSON.stringify({
                    type: 'wallet_connected',
                    wallet: this.userWallet,
                    timestamp: new Date().toISOString()
                }));
            }
            
        } catch (error) {
            console.error('Wallet connection failed:', error);
            btn.innerHTML = originalText;
            btn.disabled = false;
            this.showNotification('Wallet connection failed', 'error');
        }
    }

    handleSmoothScroll(e) {
        e.preventDefault();
        const target = document.querySelector(e.target.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    }

    handleFormSubmit(e) {
        e.preventDefault();
        const formData = new FormData(e.target);
        const data = Object.fromEntries(formData);
        
        this.showNotification('Form submitted successfully', 'success');
        
        // Send form data to server
        if (this.isConnected) {
            this.ws.send(JSON.stringify({
                type: 'form_submission',
                data: data,
                timestamp: new Date().toISOString()
            }));
        }
    }

    refreshDashboard() {
        this.loadInitialData();
        this.showNotification('Dashboard refreshed', 'info');
    }

    setupAnimations() {
        // Intersection Observer for scroll animations
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('animate-in');
                }
            });
        }, { threshold: 0.1 });

        // Observe all cards and sections
        document.querySelectorAll('.feature-card, .dashboard-card, .stat-item').forEach(el => {
            observer.observe(el);
        });

        // Add hover effects to cards
        document.querySelectorAll('.feature-card, .dashboard-card').forEach(card => {
            card.addEventListener('mouseenter', function() {
                this.style.transform = 'translateY(-10px) scale(1.02)';
            });
            
            card.addEventListener('mouseleave', function() {
                this.style.transform = 'translateY(0) scale(1)';
            });
        });
    }

    setupNotifications() {
        // Create notification container if it doesn't exist
        if (!document.querySelector('.notification-container')) {
            const container = document.createElement('div');
            container.className = 'notification-container';
            document.body.appendChild(container);
        }
    }

    showNotification(message, type = 'info') {
        const container = document.querySelector('.notification-container');
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.innerHTML = `
            <div style="display: flex; align-items: center; gap: 0.5rem;">
                <i class="fas fa-${this.getNotificationIcon(type)}"></i>
                <span>${message}</span>
                <button onclick="this.parentElement.parentElement.remove()" style="margin-left: auto; background: none; border: none; color: inherit; cursor: pointer;">
                    <i class="fas fa-times"></i>
                </button>
            </div>
        `;
        
        container.appendChild(notification);
        
        // Trigger animation
        setTimeout(() => notification.classList.add('show'), 100);
        
        // Auto-remove after 5 seconds
        setTimeout(() => {
            notification.classList.remove('show');
            setTimeout(() => notification.remove(), 300);
        }, 5000);
    }

    getNotificationIcon(type) {
        const icons = {
            success: 'check-circle',
            error: 'exclamation-circle',
            warning: 'exclamation-triangle',
            info: 'info-circle'
        };
        return icons[type] || 'info-circle';
    }

    // Public API methods
    getNetworkData() {
        return this.networkData;
    }

    isWalletConnected() {
        return !!this.userWallet;
    }

    getWalletAddress() {
        return this.userWallet;
    }

    sendMessage(type, data) {
        if (this.isConnected) {
            this.ws.send(JSON.stringify({
                type: type,
                data: data,
                timestamp: new Date().toISOString()
            }));
        }
    }
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.decentralizeAI = new DecentralizeAIApp();
    
    // Make it globally available
    window.app = window.decentralizeAI;
    
    // Add some global utility functions
    window.showNotification = (message, type) => window.decentralizeAI.showNotification(message, type);
    window.connectWallet = () => window.decentralizeAI.connectWallet();
    window.refreshDashboard = () => window.decentralizeAI.refreshDashboard();
});

// Handle page visibility changes
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        // Page is hidden, reduce activity
        if (window.decentralizeAI && window.decentralizeAI.ws) {
            window.decentralizeAI.ws.send(JSON.stringify({
                type: 'page_hidden',
                timestamp: new Date().toISOString()
            }));
        }
    } else {
        // Page is visible, resume activity
        if (window.decentralizeAI) {
            window.decentralizeAI.sendHeartbeat();
        }
    }
});

// Handle online/offline status
window.addEventListener('online', () => {
    if (window.decentralizeAI) {
        window.decentralizeAI.showNotification('Internet connection restored', 'success');
    }
});

window.addEventListener('offline', () => {
    if (window.decentralizeAI) {
        window.decentralizeAI.showNotification('Internet connection lost', 'warning');
    }
});
