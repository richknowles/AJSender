import express from 'express'
import cors from 'cors'
import helmet from 'helmet'

const app = express()
const PORT = parseInt(process.env.PORT || '3001', 10) // Convert to number

app.use(helmet())
app.use(cors())
app.use(express.json())

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'ajsender-backend' })
})

app.get('/api/status', (req, res) => {
  res.json({ 
    message: 'AJ Sender Backend is running',
    timestamp: new Date().toISOString()
  })
})

// Future API endpoints will go here
app.get('/api/users', (req, res) => {
  res.json({ 
    message: 'User management endpoints coming soon',
    status: 'placeholder'
  })
})

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend server running on port ${PORT}`)
})
