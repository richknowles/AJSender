const express = require('express')
const cors = require('cors')
const helmet = require('helmet')
const morgan = require('morgan')
const path = require('path')
require('dotenv').config()

const app = express()
const PORT = process.env.PORT || 3001

// Middleware
app.use(helmet())
app.use(cors())
app.use(morgan('combined'))
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true, limit: '10mb' }))

// Routes
app.use('/api', require('./routes/api'))

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'running', 
    timestamp: new Date().toISOString(),
    version: '2.0.0' 
  })
})

// Error handling
app.use((err, req, res, next) => {
  console.error('Error:', err)
  res.status(500).json({ 
    error: process.env.NODE_ENV === 'production' 
      ? 'Internal server error' 
      : err.message 
  })
})

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Endpoint not found' })
})

app.listen(PORT, () => {
  console.log(`🚀 AJ Sender Backend running on port ${PORT}`)
  console.log(`📱 Health check: http://localhost:${PORT}/health`)
  console.log(`🔗 API base: http://localhost:${PORT}/api`)
})

module.exports = app
