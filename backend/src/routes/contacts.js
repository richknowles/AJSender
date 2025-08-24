const express = require('express')
const multer = require('multer')
const csv = require('csv-parser')
const fs = require('fs')
const router = express.Router()
const db = require('../models/database')

// Configure multer for file uploads
const upload = multer({ dest: 'uploads/' })

// Get all contacts
router.get('/', async (req, res) => {
  try {
    const contacts = await db.getAllContacts()
    res.json(contacts)
  } catch (error) {
    console.error('Error fetching contacts:', error)
    res.status(500).json({ error: 'Failed to fetch contacts' })
  }
})

// Upload CSV contacts
router.post('/upload', upload.single('csvFile'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' })
  }

  const results = []
  let inserted = 0
  let skipped = 0

  try {
    await new Promise((resolve, reject) => {
      fs.createReadStream(req.file.path)
        .pipe(csv())
        .on('data', (data) => results.push(data))
        .on('end', resolve)
        .on('error', reject)
    })

    for (const row of results) {
      const phone = row.phone_number || row.phone || row.number
      const name = row.name || row.Name || 'Unknown'
      const email = row.email || row.Email || null

      if (phone) {
        const cleanPhone = phone.toString().replace(/\D/g, '')
        if (cleanPhone.length >= 10) {
          try {
            await db.addContact(cleanPhone, name, email)
            inserted++
          } catch (error) {
            if (error.message.includes('UNIQUE constraint failed')) {
              skipped++
            } else {
              throw error
            }
          }
        }
      }
    }

    // Cleanup uploaded file
    fs.unlinkSync(req.file.path)

    res.json({ 
      success: true, 
      inserted, 
      skipped, 
      total: results.length 
    })
  } catch (error) {
    console.error('Error processing CSV:', error)
    // Cleanup uploaded file on error
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path)
    }
    res.status(500).json({ error: 'Failed to process CSV file' })
  }
})

module.exports = router
