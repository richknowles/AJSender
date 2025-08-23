import { Router } from 'express'

export const apiRouter = Router()

// Status endpoint
apiRouter.get('/status', (req, res) => {
  res.json({
    message: 'AJ Sender Backend API is running',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: '/health',
      users: '/api/users',
      messages: '/api/messages',
      whatsapp: '/api/whatsapp'
    }
  })
})

// User management endpoints (placeholder)
apiRouter.get('/users', (req, res) => {
  res.json({
    message: 'User management endpoints',
    users: [],
    total: 0
  })
})

apiRouter.post('/users', (req, res) => {
  res.json({
    message: 'Create user endpoint',
    status: 'not_implemented'
  })
})

// Message endpoints (placeholder)
apiRouter.get('/messages', (req, res) => {
  res.json({
    message: 'Message history endpoints',
    messages: [],
    total: 0
  })
})

apiRouter.post('/messages/send', (req, res) => {
  res.json({
    message: 'Send message endpoint',
    status: 'not_implemented'
  })
})

// WhatsApp integration endpoints (placeholder)
apiRouter.get('/whatsapp/status', (req, res) => {
  res.json({
    message: 'WhatsApp integration status',
    connected: false,
    status: 'not_connected'
  })
})

apiRouter.post('/whatsapp/connect', (req, res) => {
  res.json({
    message: 'WhatsApp connect endpoint',
    status: 'not_implemented'
  })
})
