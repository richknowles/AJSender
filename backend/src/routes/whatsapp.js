const express = require('express')
const router = express.Router()
const whatsappService = require('../services/whatsapp')

// Get WhatsApp status
router.get('/status', (req, res) => {
  const status = whatsappService.getStatus()
  res.json(status)
})

// Connect to WhatsApp
router.post('/connect', async (req, res) => {
  try {
    const result = await whatsappService.connect()
    res.json(result)
  } catch (error) {
    console.error('Error connecting to WhatsApp:', error)
    res.status(500).json({ error: 'Failed to connect to WhatsApp' })
  }
})

// Disconnect from WhatsApp
router.post('/disconnect', async (req, res) => {
  try {
    await whatsappService.disconnect()
    res.json({ success: true })
  } catch (error) {
    console.error('Error disconnecting from WhatsApp:', error)
    res.status(500).json({ error: 'Failed to disconnect from WhatsApp' })
  }
})

module.exports = router
