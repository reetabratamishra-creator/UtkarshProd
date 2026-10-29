import { LightningElement, api } from 'lwc';
import askAgent from '@salesforce/apex/AccountAgentService.askAgent';

export default class AccountAgentChat extends LightningElement {
    @api recordId;
    messages = [];
    draft = '';
    isLoading = false;
    sessionId;
    hasGreeted = false;
    isOpen = false;

    get widgetClass() {
        return this.isOpen ? 'chat-panel open' : 'chat-panel closed';
    }

    get bubbleClass() {
        return this.isOpen ? 'chat-bubble hidden' : 'chat-bubble';
    }

    toggleChat() {
        this.isOpen = !this.isOpen;
        if (this.isOpen && !this.hasGreeted) {
            this.hasGreeted = true;
            this.addMessage('agent', 'Hi! How can I help you today?');
        }
    }

    minimizeChat() {
        this.isOpen = false;
    }

    get isSendDisabled() {
        return this.isLoading || !this.draft || !this.draft.trim();
    }

    handleInputChange(event) {
        this.draft = event.target.value;
    }

    handleKeyUp(event) {
        if (event.key === 'Enter' && !this.isSendDisabled) {
            this.handleSend();
        }
    }

    handleSend() {
        const text = this.draft;
        this.draft = '';
        this.sendMessage(text);
    }

    async sendMessage(displayText) {
        if (displayText) {
            this.addMessage('user', displayText);
        }
        this.isLoading = true;

        // Silently include account context so the agent never has to ask for it
        const messageForAgent = `(Account Id: ${this.recordId}) ${displayText}`;

        try {
            const result = await askAgent({
                accountId: this.recordId,
                userMessage: messageForAgent,
                sessionId: this.sessionId
            });
            if (result.success) {
                this.sessionId = result.sessionId;
                this.addMessage('agent', this.parseAgentReply(result.reply));
            } else {
                this.addMessage('agent', "I couldn't process that: " + result.errorMessage);
            }
        } catch (error) {
            this.addMessage('agent', 'Something went wrong reaching the agent.');
        } finally {
            this.isLoading = false;
            this.scrollToBottom();
        }
    }

    parseAgentReply(rawText) {
        if (!rawText) return '';
        try {
            const parsed = JSON.parse(rawText);
            if (parsed && typeof parsed === 'object' && 'value' in parsed) {
                return parsed.value;
            }
            return rawText;
        } catch (e) {
            return rawText;
        }
    }

    addMessage(sender, text) {
        this.messages = [
            ...this.messages,
            {
                id: Date.now() + Math.random(),
                sender,
                text,
                cssClass: sender === 'user' ? 'bubble user' : 'bubble agent'
            }
        ];
    }

    scrollToBottom() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const container = this.template.querySelector('.messages-container');
            if (container) container.scrollTop = container.scrollHeight;
        }, 0);
    }
}