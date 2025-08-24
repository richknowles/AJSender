const { Client, LocalAuth } = require('whatsapp-web.js')
const qrcode = require('qrcode')
const path = require('path')
const db = require('../models/database')

class WhatsAppService {
  constructor() {
    this.client = null
    this.status = {
      authenticated: false,
      ready: false,
      connected: false,
      status: 'disconnected',
      qrCode: null,
      phoneNumber: null,
      userName: null,
      expired: false
    }
    this.campaignProgress = {
      isActive: false,
      percentage: 0,
      currentCampaign: null,
      totalContacts: 0,
      sentCount: 0
    }
    this.currentCampaignId = null
    this.sendQueue = []
    this.isProcessingQueue = false
  }

  async connect() {
    try {
      if (this.client) {
        await this.disconnect()
      }

      console.log('🔄 Initializing WhatsApp client...')
      
      this.client = new Client({
        authStrategy: new LocalAuth({
          dataPath: path.join(__dirname, '../../whatsapp-session')
        }),
        puppeteer: {
          headless: true,
          executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/bin/chromium-browser',
          args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--single-process',
            '--disable-gpu',
            '--disable-web-security',
            '--disable-features=VizDisplayCompositor'
          ]
        }
      })

      this.setupEventHandlers()
      
      await this.client.initialize()
      
      return { success: true, message: 'WhatsApp client initialized' }
    } catch (error) {
      console.error('WhatsApp connection error:', error)
      this.status.status = 'error'
      throw error
    }
  }

  setupEventHandlers() {
    this.client.on('qr', async (qr) => {
      try {
        console.log('📱 QR Code received, generating image...')
        this.status.qrCode = await qrcode.toDataURL(qr)
        this.status.status = 'qr_received'
        this.status.expired = false
        console.log('✅ QR Code generated successfully')
      } catch (error) {
        console.error('Error generating QR code:', error)
      }
    })

    this.client.on('authenticated', (session) => {
      console.log('✅ WhatsApp authenticated successfully')
      this.status.authenticated = true
      this.status.qrCode = null
      this.status.status = 'authenticated'
    })

    this.client.on('auth_failure', (msg) => {
      console.error('❌ WhatsApp authentication failed:', msg)
      this.status.authenticated = false
      this.status.status = 'auth_failed'
      this.status.expired = true
    })

    this.client.on('ready', async () => {
      console.log('🚀 WhatsApp client is ready!')
      this.status.ready = true
      this.status.connected = true
      this.status.status = 'ready'
      
      try {
        const info = this.client.info
        this.status.phoneNumber = info.wid.user
        this.status.userName = info.pushname || 'Unknown'
        console.log(`📞 Connected as: ${this.status.userName} (${this.status.phoneNumber})`)
      } catch (error) {
        console.error('Error getting client info:', error)
      }
    })

    this.client.on('disconnected', (reason) => {
      console.log('📱 WhatsApp client disconnected:', reason)
      this.status.authenticated = false
      this.status.ready = false
      this.status.connected = false
      this.status.status = 'disconnected'
      this.status.qrCode = null
      this.status.phoneNumber = null
      this.status.userName = null
    })

    this.client.on('message', (message) => {
      // Handle incoming messages if needed
      console.log('📨 Received message:', message.body.substring(0, 50))
    })
  }

  async disconnect() {
    if (this.client) {
      try {
        await this.client.destroy()
        console.log('📱 WhatsApp client disconnected')
      } catch (error) {
        console.error('Error disconnecting WhatsApp:', error)
      }
      this.client = null
    }
    
    this.status = {
      authenticated: false,
      ready: false,
      connected: false,
      status: 'disconnected',
      qrCode: null,
      phoneNumber: null,
      userName: null,
      expired: false
    }
  }

  getStatus() {
    return { ...this.status }
  }

  getCampaignProgress() {
    return { ...this.campaignProgress }
  }

  async sendCampaign(campaignId) {
    try {
      console.log(`🚀 Starting campaign ${campaignId}`)
      
      if (!this.status.ready) {
        throw new Error('WhatsApp not ready')
      }

      const campaign = await db.getCampaign(campaignId)
      if (!campaign) {
        throw new Error('Campaign not found')
      }

      const contacts = await db.getAllContacts()
      if (contacts.length === 0) {
        throw new Error('No contacts found')
      }

      // Update campaign status
      await db.updateCampaignStatus(campaignId, 'sending')

      // Initialize progress
      this.campaignProgress = {
        isActive: true,
        percentage: 0,
        currentCampaign: campaign.name,
        totalContacts: contacts.length,
        sentCount: 0
      }

      // Create message records
      for (const contact of contacts) {
        await db.createMessage(campaignId, contact.id, contact.phone_number, campaign.message)
      }

      // Start sending process
      this.currentCampaignId = campaignId
      await this.processCampaignMessages(campaignId, campaign.message, contacts)

    } catch (error) {
      console.error('Error sending campaign:', error)
      if (campaignId) {
        await db.updateCampaignStatus(campaignId, 'failed')
      }
      this.campaignProgress.isActive = false
      throw error
    }
  }

  async processCampaignMessages(campaignId, message, contacts) {
    let sentCount = 0
    let failedCount = 0

    for (let i = 0; i < contacts.length; i++) {
      const contact = contacts[i]
      
      try {
        // Format phone number
        let phoneNumber = contact.phone_number.replace(/\D/g, '')
        if (!phoneNumber.startsWith('1') && phoneNumber.length === 10) {
          phoneNumber = '1' + phoneNumber
        }
        
        const chatId = phoneNumber + '@c.us'
        
        // Send message
        await this.client.sendMessage(chatId, message)
        
        // Update message status
        const messageRecord = await this.getMessageRecord(campaignId, contact.id)
        if (messageRecord) {
          await db.updateMessageStatus(messageRecord.id, 'sent')
        }
        
        sentCount++
        console.log(`✅ Sent message to ${phoneNumber}`)
        
      } catch (error) {
        console.error(`❌ Failed to send message to ${contact.phone_number}:`, error.message)
        
        // Update message status with error
        const messageRecord = await this.getMessageRecord(campaignId, contact.id)
        if (messageRecord) {
          await db.updateMessageStatus(messageRecord.id, 'failed', error.message)
        }
        
        failedCount++
      }

      // Update progress
      this.campaignProgress.sentCount = sentCount
      this.campaignProgress.percentage = Math.round(((sentCount + failedCount) / contacts.length) * 100)

      // Add delay between messages to avoid rate limiting
      if (i < contacts.length - 1) {
        await this.delay(2000) // 2 second delay
      }
    }

    // Update campaign final status
    const finalStatus = failedCount === 0 ? 'completed' : 'completed_with_errors'
    await db.updateCampaignStatus(campaignId, finalStatus, sentCount, failedCount)

    // Reset progress
    this.campaignProgress.isActive = false
    this.currentCampaignId = null

    console.log(`🎉 Campaign ${campaignId} completed: ${sentCount} sent, ${failedCount} failed`)
  }

  async getMessageRecord(campaignId, contactId) {
    return new Promise((resolve, reject) => {
      db.db.get(
        'SELECT * FROM messages WHERE campaign_id = ? AND contact_id = ?',
        [campaignId, contactId],
        (err, row) => {
          if (err) reject(err)
          else resolve(row)
        }
      )
    })
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
  }
}

// Create singleton instance
const whatsappService = new WhatsAppService()

module.exports = whatsappService
