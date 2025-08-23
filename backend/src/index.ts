import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import dotenv from 'dotenv'
import { healthRouter } from './routes/health'
import { apiRouter } from './routes/api'

dotenv.config()

const app = express()
const PORT = parseInt(process.env.PORT || '3001', 10)

// Middleware
app.use(helmet())
app.use(cors())
app.use(express.json())
app.use(express.urlencoded({ extended: true }))

// Routes
app.use('/health', healthRouter)
app.use('/api', apiRouter)

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'AJ Sender Backend API',
    version: '1.0.0',
    status: 'running'
  })
})

// Error handling middleware
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error(err.stack)
  res.status(500).json({ error: 'Something went wrong!' })
})

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' })
})

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend server running on port ${PORT}`)
  console.log(`Health check: http://localhost:${PORT}/health`)
  console.log(`API routes: http://localhost:${PORT}/api`)
})
