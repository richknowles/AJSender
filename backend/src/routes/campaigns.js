const express = require('express')
const router = express.Router()
const db = require('../models/database')
const whatsappService = require('../services/whatsapp')

// Get all campaigns
router.get('/', async (req, res) => {
  try {
    const campaigns = await db.getAllCampaigns()
    res.json(campaigns)
  } catch (error) {
    console.error('Error fetching campaigns:', error)
    res.status(500).json({ error: 'Failed to fetch campaigns' })
  }
})

// Create campaign
router.post('/', async (req, res) => {
  try {
    const { name, message } = req.body
    
    if (!name || !message) {
      return res.status(400).json({ error: 'Name and message are required' })
    }

    const campaignId = await db.createCampaign(name, message)
    res.json({ success: true, campaignId })
  } catch (error) {
    console.error('Error creating campaign:', error)
    res.status(500).json({ error: 'Failed to create campaign' })
  }
})

// Send campaign
router.post('/:id/send', async (req, res) => {
  try {
    const campaignId = parseInt(req.params.id)
    const campaign = await db.getCampaign(campaignId)
    
    if (!campaign) {
      return res.status(404).json({ error: 'Campaign not found' })
    }

    if (!whatsappService.getStatus().authenticated) {
      return res.status(400).json({ error: 'WhatsApp not connected' })
    }

    // Start sending campaign in background
    whatsappService.sendCampaign(campaignId)
    
    res.json({ success: true, message: 'Campaign started' })
  } catch (error) {
    console.error('Error sending campaign:', error)
    res.status(500).json({ error: 'Failed to send campaign' })
  }
})

// Get campaign progress
router.get('/progress', async (req, res) => {
  try {
    const progress = whatsappService.getCampaignProgress()
    res.json(progress)
  } catch (error) {
    console.error('Error fetching progress:', error)
    res.status(500).json({ 
      isActive: false, 
      percentage: 0, 
      currentCampaign: null,
      totalContacts: 0,
      sentCount: 0 
    })
  }
})

module.exports = router
