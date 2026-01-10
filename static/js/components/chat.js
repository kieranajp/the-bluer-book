export function Chat() {
    return {
        messages: [],
        input: '',
        loading: false,
        error: null,
        visible: false,

        toggle() {
            this.visible = !this.visible;
        },

        renderMarkdown(text) {
            if (!text) return '';
            // Simple markdown parsing for common patterns
            return text
                .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>') // Bold
                .replace(/\*(.+?)\*/g, '<em>$1</em>') // Italic
                .replace(/`(.+?)`/g, '<code>$1</code>') // Inline code
                .replace(/\n\n/g, '</p><p>') // Paragraphs
                .replace(/\n/g, '<br>'); // Line breaks
        },

        async send() {
            if (!this.input.trim() || this.loading) return;

            const userMessage = this.input.trim();
            this.messages.push({
                role: 'user',
                text: userMessage,
                timestamp: new Date()
            });
            this.input = '';
            this.loading = true;
            this.error = null;

            const messageIndex = this.messages.length;
            this.messages.push({
                role: 'assistant',
                text: '',
                author: null,
                timestamp: new Date()
            });

            try {
                const response = await fetch('/api/chat', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        message: userMessage,
                        userId: 'web-user',
                        sessionId: this.getOrCreateSessionId()
                    })
                });

                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }

                const reader = response.body.getReader();
                const decoder = new TextDecoder();

                while (true) {
                    const { value, done } = await reader.read();
                    if (done) break;

                    const chunk = decoder.decode(value);
                    const lines = chunk.split('\n\n');

                    for (const line of lines) {
                        if (line.startsWith('data: ')) {
                            const data = line.slice(6);
                            if (data === '[DONE]') continue;

                            try {
                                const parsed = JSON.parse(data);
                                if (parsed.text) {
                                    // Trigger reactivity by reassigning the whole message object
                                    this.messages[messageIndex] = {
                                        ...this.messages[messageIndex],
                                        text: this.messages[messageIndex].text + parsed.text,
                                        author: parsed.author || this.messages[messageIndex].author
                                    };
                                }
                            } catch (e) {
                                console.error('Failed to parse SSE data:', e, 'Data:', data);
                            }
                        } else if (line.startsWith('event: done')) {
                            break;
                        }
                    }
                }
            } catch (err) {
                this.error = err.message;
                this.messages.pop();
                console.error('Chat error:', err);
            } finally {
                this.loading = false;
                this.$nextTick(() => {
                    this.scrollToBottom();
                });
            }
        },

        scrollToBottom() {
            const container = this.$refs.messageContainer;
            if (container) {
                container.scrollTop = container.scrollHeight;
            }
        },

        getOrCreateSessionId() {
            let sessionId = localStorage.getItem('chat-session-id');
            if (!sessionId) {
                sessionId = 'session-' + Date.now();
                localStorage.setItem('chat-session-id', sessionId);
            }
            return sessionId;
        },

        clearHistory() {
            if (confirm('Clear chat history?')) {
                this.messages = [];
                localStorage.removeItem('chat-session-id');
            }
        }
    };
}
