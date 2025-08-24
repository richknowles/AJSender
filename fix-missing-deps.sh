#!/bin/bash
# Fix missing dependencies and simplify App.tsx
set -euo pipefail

echo "=== Fixing Missing Dependencies ==="

# Stop containers
docker-compose down

# Create a simplified App.tsx without the missing dependencies
cat > frontend/src/App.tsx << 'EOF'
import React from 'react'
import Dashboard from './components/Dashboard'
import './index.css'

function App() {
  return (
    <div className="App">
      <Dashboard />
    </div>
  )
}

export default App
EOF

# Create main.tsx
cat > frontend/src/main.tsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

# Create a working Dashboard.tsx without framer-motion and react-hot-toast
cat > frontend/src/components/Dashboard.tsx << 'EOF'
import React, { useState, useEffect } from 'react'
import { Users, MessageSquare, Send, BarChart3, Plus, TrendingUp, Upload, CheckCircle, XCircle, Clock, RefreshCw, Heart, Wifi, Moon, Sun, X } from 'lucide-react'

interface Metrics {
  totalContacts: number
  totalCampaigns: number
  totalMessages: number
  sentMessages: number
}

interface CampaignProgress {
  isActive: boolean
  percentage: number
  currentCampaign: string | null
  totalContacts: number
  sentCount: number
}

interface SystemStatus {
  backend: string
  whatsapp: string
  authenticated: boolean
}

interface Contact {
  id: number
  phone_number: string
  name: string
  email?: string
  created_at: string
}

interface Campaign {
  id: number
  name: string
  message: string
  status: string
  sent_count: number
  failed_count: number
  total_messages: number
  created_at: string
}

const Dashboard: React.FC = () => {
  const [isDark, setIsDark] = useState(false)
  const [showUploadModal, setShowUploadModal] = useState(false)
  const [showCampaignModal, setShowCampaignModal] = useState(false)
  const [showAnalyticsModal, setShowAnalyticsModal] = useState(false)
  const [contacts, setContacts] = useState<Contact[]>([])
  const [campaigns, setCampaigns] = useState<Campaign[]>([])
  const [metrics, setMetrics] = useState<Metrics>({
    totalContacts: 0,
    totalCampaigns: 0,
    totalMessages: 0,
    sentMessages: 0
  })
  const [campaignProgress, setCampaignProgress] = useState<CampaignProgress>({
    isActive: false,
    percentage: 0,
    currentCampaign: null,
    totalContacts: 0,
    sentCount: 0
  })
  const [systemStatus, setSystemStatus] = useState<SystemStatus>({
    backend: 'unknown',
    whatsapp: 'disconnected',
    authenticated: false
  })
  const [loading, setLoading] = useState(false)

  // Fetch data from backend
  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true)
        const [metricsRes, progressRes, statusRes, contactsRes, campaignsRes] = await Promise.all([
          fetch('/api/metrics').catch(() => ({ ok: false })),
          fetch('/api/campaigns/progress').catch(() => ({ ok: false })),
          fetch('/api/status').catch(() => ({ ok: false })),
          fetch('/api/contacts').catch(() => ({ ok: false })),
          fetch('/api/campaigns').catch(() => ({ ok: false }))
        ])

        if (metricsRes.ok) {
          const metricsData = await metricsRes.json()
          setMetrics(metricsData)
        }

        if (progressRes.ok) {
          const progressData = await progressRes.json()
          setCampaignProgress(progressData)
        }

        if (statusRes.ok) {
          const statusData = await statusRes.json()
          setSystemStatus(statusData)
        }

        if (contactsRes.ok) {
          const contactsData = await contactsRes.json()
          setContacts(contactsData)
        }

        if (campaignsRes.ok) {
          const campaignsData = await campaignsRes.json()
          setCampaigns(campaignsData)
        }
      } catch (error) {
        console.error('Error fetching data:', error)
      } finally {
        setLoading(false)
      }
    }

    fetchData()
    const interval = setInterval(fetchData, 5000)
    return () => clearInterval(interval)
  }, [])

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return

    const formData = new FormData()
    formData.append('csvFile', file)

    try {
      setLoading(true)
      const response = await fetch('/api/contacts/upload', {
        method: 'POST',
        body: formData
      })

      const result = await response.json()
      
      if (response.ok) {
        alert(`Success! Imported ${result.inserted} contacts, skipped ${result.skipped} duplicates.`)
        const contactsRes = await fetch('/api/contacts')
        if (contactsRes.ok) {
          const contactsData = await contactsRes.json()
          setContacts(contactsData)
        }
      } else {
        alert(`Error: ${result.error}`)
      }
    } catch (error) {
      alert('Error uploading file: ' + (error as Error).message)
    } finally {
      setLoading(false)
      setShowUploadModal(false)
    }
  }

  const handleCreateCampaign = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const formData = new FormData(event.currentTarget)
    const name = formData.get('name') as string
    const message = formData.get('message') as string

    if (!name || !message) {
      alert('Please fill in both campaign name and message.')
      return
    }

    try {
      setLoading(true)
      const response = await fetch('/api/campaigns', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ name, message })
      })

      const result = await response.json()

      if (response.ok) {
        alert('Campaign created successfully!')
        const campaignsRes = await fetch('/api/campaigns')
        if (campaignsRes.ok) {
          const campaignsData = await campaignsRes.json()
          setCampaigns(campaignsData)
        }
        setShowCampaignModal(false)
      } else {
        alert('Error creating campaign: ' + result.error)
      }
    } catch (error) {
      alert('Error creating campaign: ' + (error as Error).message)
    } finally {
      setLoading(false)
    }
  }

  const Modal = ({ show, onClose, title, children, size = 'md' }: { 
    show: boolean
    onClose: () => void
    title: string
    children: React.ReactNode
    size?: 'sm' | 'md' | 'lg' | 'xl'
  }) => {
    const sizeClasses = {
      sm: 'max-w-sm',
      md: 'max-w-md',
      lg: 'max-w-lg',
      xl: 'max-w-2xl'
    }

    if (!show) return null

    return (
      <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onClick={onClose}>
        <div
          onClick={e => e.stopPropagation()}
          className={`${sizeClasses[size]} w-full rounded-2xl shadow-xl ${
            isDark ? 'bg-gray-800 border border-gray-700' : 'bg-white border border-gray-200'
          }`}
        >
          <div className={`flex items-center justify-between p-6 border-b ${
            isDark ? 'border-gray-700' : 'border-gray-200'
          }`}>
            <h3 className={`text-lg font-semibold ${isDark ? 'text-white' : 'text-gray-900'}`}>
              {title}
            </h3>
            <button
              onClick={onClose}
              className={`p-2 rounded-lg hover:bg-gray-100 ${isDark ? 'hover:bg-gray-700' : ''}`}
            >
              <X className="w-5 h-5" />
            </button>
          </div>
          <div className="p-6">
            {children}
          </div>
        </div>
      </div>
    )
  }

  const StatCard = ({ title, value, icon: Icon, color }: { 
    title: string
    value: string | number
    icon: React.ComponentType<any>
    color: string
  }) => (
    <div className={`p-6 rounded-2xl shadow-lg transition-all hover:scale-105 ${
      isDark ? 'bg-gray-800 hover:bg-gray-750' : 'bg-white hover:shadow-xl'
    }`}>
      <div className="flex items-center justify-between">
        <div>
          <p className={`text-sm font-medium ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
            {title}
          </p>
          <p className={`text-3xl font-bold ${isDark ? 'text-white' : 'text-gray-900'}`}>
            {value}
          </p>
        </div>
        <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
          <Icon className={`w-8 h-8 ${color}`} />
        </div>
      </div>
    </div>
  )

  const StatusBadge = ({ status, label }: { status: string, label: string }) => {
    const isPositive = status === 'running' || status === 'authenticated'
    return (
      <span className={`inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium ${
        isPositive 
          ? 'bg-green-100 text-green-700'
          : 'bg-red-100 text-red-700'
      }`}>
        {isPositive ? <CheckCircle className="w-3 h-3" /> : <XCircle className="w-3 h-3" />}
        {label}
      </span>
    )
  }

  return (
    <div className={`min-h-screen transition-all duration-500 ${
      isDark 
        ? 'bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900' 
        : 'bg-gradient-to-br from-gray-50 via-white to-gray-100'
    }`}>
      {/* Progress Bar */}
      {campaignProgress.isActive && (
        <div className="fixed top-0 left-0 right-0 z-50">
          <div className={`h-2 ${isDark ? 'bg-gray-800' : 'bg-gray-100'}`}>
            <div
              className="h-full bg-gradient-to-r from-green-500 via-emerald-500 to-green-600"
              style={{ width: `${campaignProgress.percentage}%` }}
            />
          </div>
          {campaignProgress.percentage > 0 && (
            <div className={`absolute top-3 right-4 px-3 py-1 rounded-full text-xs font-bold shadow-lg ${
              isDark ? 'bg-gray-800 text-green-400' : 'bg-white text-green-600'
            }`}>
              {campaignProgress.currentCampaign}: {campaignProgress.percentage}% ({campaignProgress.sentCount}/{campaignProgress.totalContacts})
            </div>
          )}
        </div>
      )}

      {/* Header */}
      <header className={`sticky top-0 z-40 backdrop-blur-xl border-b ${
        isDark ? 'bg-gray-900/80 border-gray-700/50' : 'bg-white/80 border-gray-200/50'
      }`}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-xl bg-gradient-to-r from-green-500 to-emerald-600">
                <Send className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className={`text-xl font-bold ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  AJ Sender
                </h1>
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  WhatsApp Bulk Messaging
                </p>
              </div>
            </div>
            
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-3">
                <StatusBadge 
                  status={systemStatus.backend}
                  label="Backend" 
                />
                <StatusBadge 
                  status={systemStatus.authenticated ? 'authenticated' : 'disconnected'}
                  label="WhatsApp" 
                />
              </div>

              <button
                onClick={() => setIsDark(!isDark)}
                className={`p-2 rounded-lg transition-all duration-300 ${
                  isDark ? 'bg-gray-700 hover:bg-gray-600 text-yellow-400' : 'bg-gray-100 hover:bg-gray-200 text-gray-700'
                }`}
              >
                {isDark ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <StatCard
            title="Total Contacts"
            value={metrics.totalContacts.toLocaleString()}
            icon={Users}
            color="text-blue-500"
          />
          <StatCard
            title="Campaigns"
            value={metrics.totalCampaigns.toLocaleString()}
            icon={MessageSquare}
            color="text-green-500"
          />
          <StatCard
            title="Messages"
            value={metrics.totalMessages.toLocaleString()}
            icon={Send}
            color="text-purple-500"
          />
          <StatCard
            title="Success Rate"
            value={`${metrics.totalMessages > 0 ? Math.round((metrics.sentMessages / metrics.totalMessages) * 100) : 0}%`}
            icon={TrendingUp}
            color="text-orange-500"
          />
        </div>

        {/* Quick Actions */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div
            onClick={() => setShowUploadModal(true)}
            className={`p-6 rounded-2xl shadow-lg cursor-pointer transition-all hover:scale-105 ${
              isDark ? 'bg-gray-800 hover:bg-gray-750' : 'bg-white hover:shadow-xl'
            }`}
          >
            <div className="flex items-start gap-4">
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <Upload className={`w-6 h-6 ${isDark ? 'text-gray-300' : 'text-gray-700'}`} />
              </div>
              <div>
                <h3 className={`font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  Upload Contacts
                </h3>
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Import contacts from CSV
                </p>
              </div>
            </div>
          </div>

          <div
            onClick={() => setShowCampaignModal(true)}
            className={`p-6 rounded-2xl shadow-lg cursor-pointer transition-all hover:scale-105 ${
              isDark ? 'bg-gray-800 hover:bg-gray-750' : 'bg-white hover:shadow-xl'
            }`}
          >
            <div className="flex items-start gap-4">
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <Plus className={`w-6 h-6 ${isDark ? 'text-gray-300' : 'text-gray-700'}`} />
              </div>
              <div>
                <h3 className={`font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  Create Campaign
                </h3>
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Start a new message campaign
                </p>
              </div>
            </div>
          </div>

          <div
            onClick={() => setShowAnalyticsModal(true)}
            className={`p-6 rounded-2xl shadow-lg cursor-pointer transition-all hover:scale-105 ${
              isDark ? 'bg-gray-800 hover:bg-gray-750' : 'bg-white hover:shadow-xl'
            }`}
          >
            <div className="flex items-start gap-4">
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <BarChart3 className={`w-6 h-6 ${isDark ? 'text-gray-300' : 'text-gray-700'}`} />
              </div>
              <div>
                <h3 className={`font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  View Analytics
                </h3>
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Track campaign performance
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <footer className={`text-center py-8 border-t ${isDark ? 'border-gray-700' : 'border-gray-200'}`}>
          <div className="flex items-center justify-center gap-2 mb-2">
            <span className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
              Made with
            </span>
            <Heart className="w-4 h-4 text-red-500" />
            <span className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
              for my girl
            </span>
          </div>
          <p className={`text-xs ${isDark ? 'text-gray-500' : 'text-gray-500'}`}>
            AJ Sender v2.0 - WhatsApp Bulk Messaging Platform
          </p>
        </footer>
      </main>

      {/* Modals */}
      <Modal show={showUploadModal} onClose={() => setShowUploadModal(false)} title="Upload Contacts">
        <div className="space-y-4">
          <p className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>
            Upload a CSV file with contacts. Supported columns: phone_number, phone, number, name, email
          </p>
          <input
            type="file"
            accept=".csv"
            onChange={handleFileUpload}
            className={`w-full p-3 border rounded-lg ${
              isDark ? 'bg-gray-700 border-gray-600 text-white' : 'bg-white border-gray-300'
            }`}
          />
          <div className={`text-xs ${isDark ? 'text-gray-400' : 'text-gray-500'}`}>
            Current contacts: {contacts.length}
          </div>
        </div>
      </Modal>

      <Modal show={showCampaignModal} onClose={() => setShowCampaignModal(false)} title="Create Campaign">
        <form onSubmit={handleCreateCampaign} className="space-y-4">
          <div>
            <label className={`block text-sm font-medium mb-2 ${isDark ? 'text-gray-300' : 'text-gray-700'}`}>
              Campaign Name
            </label>
            <input
              name="name"
              type="text"
              required
              className={`w-full p-3 border rounded-lg ${
                isDark ? 'bg-gray-700 border-gray-600 text-white' : 'bg-white border-gray-300'
              }`}
              placeholder="Enter campaign name"
            />
          </div>
          <div>
            <label className={`block text-sm font-medium mb-2 ${isDark ? 'text-gray-300' : 'text-gray-700'}`}>
              Message
            </label>
            <textarea
              name="message"
              required
              rows={4}
              maxLength={1000}
              className={`w-full p-3 border rounded-lg ${
                isDark ? 'bg-gray-700 border-gray-600 text-white' : 'bg-white border-gray-300'
              }`}
              placeholder="Enter your message (max 1000 characters)"
            />
          </div>
          <button
            type="submit"
            disabled={loading}
            className={`w-full bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-lg font-medium ${
              loading ? 'opacity-50 cursor-not-allowed' : ''
            }`}
          >
            {loading ? 'Creating...' : 'Create Campaign'}
          </button>
        </form>
      </Modal>

      <Modal show={showAnalyticsModal} onClose={() => setShowAnalyticsModal(false)} title="Analytics & Campaigns" size="xl">
        <div className="space-y-6">
          <div className="grid grid-cols-2 gap-4 mb-4">
            <div className={`p-4 rounded-lg ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
              <div className="text-2xl font-bold text-green-500">{contacts.length}</div>
              <div className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>Total Contacts</div>
            </div>
            <div className={`p-4 rounded-lg ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
              <div className="text-2xl font-bold text-blue-500">{campaigns.length}</div>
              <div className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>Campaigns</div>
            </div>
          </div>
          
          <div>
            <h4 className={`font-semibold mb-4 ${isDark ? 'text-white' : 'text-gray-900'}`}>
              Recent Campaigns
            </h4>
            <div className="space-y-3">
              {campaigns.length === 0 ? (
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-500'}`}>
                  No campaigns created yet
                </p>
              ) : (
                campaigns.slice(0, 5).map(campaign => (
                  <div
                    key={campaign.id}
                    className={`p-4 rounded-lg border ${isDark ? 'bg-gray-700 border-gray-600' : 'bg-gray-50 border-gray-200'}`}
                  >
                    <div className="flex justify-between items-start">
                      <div className="flex-1">
                        <div className="flex items-center gap-2 mb-2">
                          <h5 className={`font-medium ${isDark ? 'text-white' : 'text-gray-900'}`}>
                            {campaign.name}
                          </h5>
                          <span className={`inline-block px-2 py-1 text-xs rounded-full ${
                            campaign.status === 'completed' ? 'bg-green-100 text-green-800' :
                            campaign.status === 'sending' ? 'bg-yellow-100 text-yellow-800' :
                            'bg-gray-100 text-gray-800'
                          }`}>
                            {campaign.status}
                          </span>
                        </div>
                        <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                          {campaign.message.length > 100 ? campaign.message.substring(0, 100) + '...' : campaign.message}
                        </p>
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </Modal>
    </div>
  )
}

export default Dashboard
EOF

# Create index.css with Tailwind
cat > frontend/src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#root {
  min-height: 100vh;
}

.App {
  min-height: 100vh;
}
EOF

echo "✅ Dependencies fixed!"
echo ""
echo "Building and starting containers..."
docker-compose up --build -d

echo ""
echo "🎉 Should work now!"
echo "Frontend: http://localhost:3000"
echo "Backend: http://localhost:3001"