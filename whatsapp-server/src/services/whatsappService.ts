import { Client, LocalAuth, MessageMedia } from 'whatsapp-web.js';
import QRCode from 'qrcode';

export interface Contact {
    phone: string;
    name?: string;
}

export interface MessageStatus {
    phone: string;
    status: 'pending' | 'sent' | 'delivered' | 'failed';
    error?: string;
    timestamp: Date;
}

class WhatsAppService {
    private client: Client | null = null;
    private isReady = false;
    private qrCode: string | null = null;
    private messageQueue: Array<{contact: Contact, message: string, resolve: Function, reject: Function}> = [];
    private isProcessing = false;

    constructor() {
        this.initializeClient();
    }

    private initializeClient() {
        this.client = new Client({
            authStrategy: new LocalAuth({
                dataPath: '/app/session'
            }),
            puppeteer: {
                headless: true,
                args: [
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-dev-shm-usage',
                    '--disable-accelerated-2d-canvas',
                    '--no-first-run',
                    '--no-zygote',
                    '--single-process',
                    '--disable-gpu',
                    '--disable-extensions',
                    '--disable-background-timer-throttling',
                    '--disable-backgrounding-occluded-windows',
                    '--disable-renderer-backgrounding'
                ]
            }
        });

        this.client.on('qr', async (qr) => {
            console.log('QR Code received, generating data URL...');
            try {
                this.qrCode = await QRCode.toDataURL(qr);
                console.log('QR Code generated successfully');
            } catch (error) {
                console.error('Error generating QR code:', error);
            }
        });

        this.client.on('ready', () => {
            console.log('WhatsApp client is ready!');
            this.isReady = true;
            this.qrCode = null;
            this.processMessageQueue();
        });

        this.client.on('authenticated', () => {
            console.log('WhatsApp client authenticated');
        });

        this.client.on('auth_failure', (msg) => {
            console.error('Authentication failed:', msg);
            this.isReady = false;
        });

        this.client.on('disconnected', (reason) => {
            console.log('WhatsApp client disconnected:', reason);
            this.isReady = false;
        });

        console.log('Initializing WhatsApp client...');
        this.client.initialize().catch(error => {
            console.error('Failed to initialize WhatsApp client:', error);
        });
    }

    public getStatus() {
        return {
            isReady: this.isReady,
            hasQRCode: !!this.qrCode,
            queueLength: this.messageQueue.length
        };
    }

    public getQRCode(): string | null {
        return this.qrCode;
    }

    public async sendMessage(contact: Contact, message: string): Promise<MessageStatus> {
        return new Promise((resolve, reject) => {
            this.messageQueue.push({ contact, message, resolve, reject });
            
            if (!this.isProcessing) {
                this.processMessageQueue();
            }
        });
    }

    private async processMessageQueue() {
        if (this.isProcessing || !this.isReady || this.messageQueue.length === 0) {
            return;
        }

        this.isProcessing = true;

        while (this.messageQueue.length > 0 && this.isReady) {
            const { contact, message, resolve, reject } = this.messageQueue.shift()!;
            
            try {
                const result = await this.sendSingleMessage(contact, message);
                resolve(result);
                
                // Rate limiting - wait 2-5 seconds between messages
                await this.delay(2000 + Math.random() * 3000);
                
            } catch (error) {
                const failedStatus: MessageStatus = {
                    phone: contact.phone,
                    status: 'failed',
                    error: error instanceof Error ? error.message : 'Unknown error',
                    timestamp: new Date()
                };
                reject(failedStatus);
            }
        }

        this.isProcessing = false;
    }

    private async sendSingleMessage(contact: Contact, message: string): Promise<MessageStatus> {
        if (!this.client || !this.isReady) {
            throw new Error('WhatsApp client not ready');
        }

        const phoneNumber = this.formatPhoneNumber(contact.phone);
        const chatId = `${phoneNumber}@c.us`;

        try {
            const isRegistered = await this.client.isRegisteredUser(chatId);
            if (!isRegistered) {
                throw new Error('Phone number not registered on WhatsApp');
            }

            await this.client.sendMessage(chatId, message);

            return {
                phone: contact.phone,
                status: 'sent',
                timestamp: new Date()
            };
        } catch (error) {
            throw new Error(`Failed to send to ${contact.phone}: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
    }

    private formatPhoneNumber(phone: string): string {
        const cleaned = phone.replace(/\D/g, '');
        
        if (cleaned.length === 10) {
            return '1' + cleaned;
        }
        
        return cleaned;
    }

    private delay(ms: number): Promise<void> {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    public async sendBulkMessages(contacts: Contact[], message: string): Promise<MessageStatus[]> {
        const results: MessageStatus[] = [];
        
        for (const contact of contacts) {
            try {
                const result = await this.sendMessage(contact, message);
                results.push(result);
            } catch (error) {
                results.push(error as MessageStatus);
            }
        }
        
        return results;
    }
}

export const whatsappService = new WhatsAppService();
