const express = require('express')
const router = express.Router()

// Import individual route modules
const contactsRouter = require('./contacts')
const campaignsRouter = require('./campaigns')
const whatsappRouter = require('./whatsapp')
const { initializeDatabase } = require('../models/database')

// Initialize database on startup
initializeDatabase()

// Status endpoint
router.get('/status', (req, res) => {
  const whatsappService = require('../services/whatsapp')
  
  res.json({
    backend: 'running',
    whatsapp: whatsappService.getStatus().status,
    authenticated: whatsappService.getStatus().authenticated,
    timestamp: new Date().toISOString()
  })
})

// Metrics endpoint
router.get('/metrics', async (req, res) => {
  try {
    const db = require('../models/database')
    
    const contacts = await db.getContactCount()
    const campaigns = await db.getCampaignCount()
    const messages = await db.getMessageStats()
    
    res.json({
      totalContacts: contacts,
      totalCampaigns: campaigns,
      totalMessages: messages.total || 0,
      sentMessages: messages.sent || 0
    })
  } catch (error) {
    console.error('Error fetching metrics:', error)
    res.status(500).json({ error: 'Failed to fetch metrics' })
  }
})

// Mount route modules
router.use('/contacts', contactsRouter)
router.use('/campaigns', campaignsRouter)
router.use('/whatsapp', whatsappRouter)

module.exports = router
