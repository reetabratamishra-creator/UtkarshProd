import { LightningElement ,api, track} from 'lwc';
import USER_ID from '@salesforce/user/Id';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import startChatSession from '@salesforce/apex/EinsteinChatController.startChatSession';
import sendChatMessage from '@salesforce/apex/EinsteinChatController.sendChatMessage';
import translateMessegeFromUser from '@salesforce/apex/EinsteinChatController.translateMessegeFromUser';
import translateMessegeFromAgent from '@salesforce/apex/EinsteinChatController.translateMessegeFromAgent';
import endChatSession from '@salesforce/apex/EinsteinChatController.endChatSession';

const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;

export default class UtkarshCustomChatbot extends LightningElement {

    @api recordId;
    @api agentforceAgentId;
    @track userChoosenLang = 'English';
    
    // --- 1. CORE UI STATE VARIABLES ---
    @track isOpen = false;
    @track isListening = false;
    @track isLoading = false;
    
    // --- 2. CHAT DATA VARIABLES ---
    @track messages = []; 
    sessionId = '';
    agentJoinedMessage = 'Agent has joined the chat.';
    agentLoadingMessage = 'Agent is typing...';
    
    // --- 3. INPUT VARIABLES ---
    @track userInput = '';
    @track isProcessing = false;
    @track isInputDisabled = false;
    placeholderText = 'Type your message...';
    selectedLang = 'en-US';

    // --- GETTERS ---
    get chatIconClass() { return this.isOpen ? 'chat-bubble hidden' : 'chat-bubble visible'; }
    get inputWrapperClass() { return this.isInputDisabled ? 'input-wrapper disabled-bg' : 'input-wrapper'; }
    get micClass() { return this.isListening ? 'mic-btn listening' : 'mic-btn'; }
    get micVariant() { return this.isListening ? 'error' : 'inverse'; }

    get engChipClass() { return this.selectedLang === 'en-US' ? 'lang-chip active' : 'lang-chip'; }
    get hinChipClass() { return this.selectedLang === 'hi-IN' ? 'lang-chip active' : 'lang-chip'; }
    get benChipClass() { return this.selectedLang === 'bn-IN' ? 'lang-chip active' : 'lang-chip'; }

    // --- DYNAMIC CACHE KEY ---
    // This ensures the session cache is strictly tied to the logged-in user
    get cacheKey() {
        return `UTKARSH_AGENT_SESSION_${USER_ID}`;
    }

    // --- CACHING LOGIC ---
    loadSessionState() {
        const storedData = localStorage.getItem(this.cacheKey);
        if (storedData) {
            try {
                const parsedData = JSON.parse(storedData);
                const currentTime = Date.now();
                
                // Check if session is older than 24 hours
                if (currentTime - parsedData.timestamp < TWENTY_FOUR_HOURS_MS) {
                    this.sessionId = parsedData.sessionId;
                    this.messages = parsedData.messages || [];
                    this.selectedLang = parsedData.selectedLang || 'en-US';
                    this.userChoosenLang = parsedData.userChoosenLang || 'English';
                    return true; // Successfully loaded cache
                } else {
                    // Cache expired, remove it
                    localStorage.removeItem(this.cacheKey);
                }
            } catch (error) {
                console.error('Error parsing cached session:', error);
                localStorage.removeItem(this.cacheKey);
            }
        }
        return false; // No valid cache found
    }

    saveSessionState() {
        if (!this.sessionId) return;
        const stateToSave = {
            sessionId: this.sessionId,
            messages: this.messages,
            timestamp: Date.now(),
            selectedLang: this.selectedLang,
            userChoosenLang: this.userChoosenLang
        };
        localStorage.setItem(this.cacheKey, JSON.stringify(stateToSave));
    }

    // --- END CHAT ---
    async endChat() {
        // 1. Call Salesforce to end the session on the backend
        if (this.sessionId) {
            try {
                await endChatSession({ sessionId: this.sessionId });
                console.log('Session ended successfully on the server.');
            } catch (error) {
                // If the server call fails (network issue, etc.), log it but continue 
                // to clear the UI so the user isn't permanently stuck.
                console.error('Error ending session on server:', error);
            }
        }

        // 2. Clear local storage cache for this specific user
        localStorage.removeItem(this.cacheKey);
        
        // 3. Reset variables
        this.sessionId = '';
        this.messages = [];
        this.userInput = '';
        
        // 4. Close the chat window
        this.isOpen = false;
        this.showToast('Chat Ended', 'Your session has been securely closed. Have a great day!', 'success');
        
    }

    // --- LANGUAGE SETUP ---
    setEnglish() { 
        this.selectedLang = 'en-US'; 
        this.userChoosenLang = 'English';
        this.saveSessionState();
    }
    setHindi()   { 
        this.selectedLang = 'hi-IN';
        this.userChoosenLang = 'Hindi';
        this.saveSessionState();
    }
    setBengali() { 
        this.selectedLang = 'bn-IN'; 
        this.userChoosenLang = 'Bengali';
        this.saveSessionState();
    }

    // --- CHAT TOGGLE & INITIALIZATION ---
    async toggleChat() {
        this.isOpen = !this.isOpen;
        console.log('Toggling chat. New state:', this.isOpen);

        // ONLY start a new session if the chat is opening AND we don't already have a session
        if (this.isOpen && !this.sessionId) {
            
            // First, attempt to load an existing active session for this user
            const hasCachedSession = this.loadSessionState();
            
            if (!hasCachedSession) {
                // If no cache, initialize a brand new session
                this.isLoading = true;
                this.isInputDisabled = true; 

                try {
                    console.log('Starting chat session with AgentId:', this.agentforceAgentId, 'and OppID:', this.recordId);
                    const welcomeMsgObj = await startChatSession({ AgentId: this.agentforceAgentId , OppID: this.recordId });
                    this.sessionId = welcomeMsgObj.sessionId;

                    const now = new Date();
                    const timeString = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: true });
                    const dateString = now.toLocaleDateString([], { weekday: 'long', month: 'short', day: 'numeric' });

                    this.messages = [
                        { id: Date.now(), text: `${dateString} • ${timeString}`, isSystem: true },
                        { id: Date.now() + 1, text: this.agentJoinedMessage, isSystem: true },
                        { id: Date.now() + 2, text: welcomeMsgObj.message, isBot: true }
                    ];

                    // Cache the new session immediately
                    this.saveSessionState();

                } catch (error) {
                    console.error('Error starting chat session:', error);
                    this.messages = [
                        { id: Date.now(), text: 'Failed to start chat session. Please try again later.', isSystem: true }
                    ];
                } finally {
                    this.isLoading = false;
                    this.isInputDisabled = false;
                }
            } else {
                // We successfully loaded from cache! Let's just scroll to the bottom.
                setTimeout(() => {
                    const container = this.template.querySelector('.chat-messages');
                    if (container) {
                        container.scrollTop = container.scrollHeight;
                    }
                }, 50);
            }
        }
    }

    // --- INPUT HANDLING ---
    handleInputChange(event) {
        this.userInput = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            this.handleSend();
        }
    }

    // --- SEND MESSAGE ---
    async handleSend() {
        if (!this.userInput || !this.sessionId) return;
        
        this.isProcessing = true;
        this.isInputDisabled = true;
        
        const userText = this.userInput;
        const promptResponse = await translateMessegeFromUser({ message: userText });
        console.log('Prompt template response:', promptResponse);

        // Add user message to UI and save to cache
        this.messages = [...this.messages, { id: Date.now(), text: userText, isUser: true }];
        this.saveSessionState();
        
        this.userInput = ''; // clear input field
        
        try {
            const response = await sendChatMessage({
                sessionId: this.sessionId,
                message: promptResponse
            });
            console.log('Bot response:', response);

            const promptResponse2 = await translateMessegeFromAgent({
                message: response,
                selectedLanguage: this.userChoosenLang
            });
            console.log('Translated Bot response:', promptResponse2);
            
            // Add bot message to UI and update cache
            this.messages = [...this.messages, { id: Date.now() + 1, text: promptResponse2, isBot: true }];
            this.saveSessionState();

        } catch (error) {
            console.error('Error sending message:', error);
            this.messages = [...this.messages, { 
                id: Date.now() + 1, 
                text: 'Sorry, I encountered an error. Please try again.', 
                isSystem: true 
            }];
        } finally {
            this.isProcessing = false;
            this.isInputDisabled = false;
            
            setTimeout(() => {
                const container = this.template.querySelector('.chat-messages');
                if (container) {
                    container.scrollTop = container.scrollHeight;
                }
            }, 50);
        }
    }

    // --- SPEECH RECOGNITION ---
    handleListen() {
        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        if (!SpeechRecognition) {
            alert('Your browser does not support speech recognition.');
            return;
        }
        const recognition = new SpeechRecognition();
        recognition.lang = this.selectedLang;
        recognition.interimResults = false;
        this.isListening = true;
        recognition.start();
        
        recognition.onresult = e => { 
            this.userInput = e.results[0][0].transcript; 
            this.isListening = false; 
        };
        console.log('userinput', this.userInput);
        recognition.onerror = () => { this.isListening = false; };
        recognition.onspeechend = () => { recognition.stop(); this.isListening = false; };
    }

    // --- UI HELPERS ---
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant, // 'success', 'error', 'warning', or 'info'
            mode: 'dismissible'
        });
        this.dispatchEvent(event);
    }
}