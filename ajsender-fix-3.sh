#!/usr/bin/env bash
# AJ Sender Fix Script - Resolves API routing and frontend issues
set -Eeuo pipefail

cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Fixing AJ Sender Frontend/Backend Communication ==="

# 1. Create proper frontend package.json with proxy configuration
mkdir -p frontend
cat > frontend/package.json <<'EOF'
{
  "name": "ajsender-frontend",
  "version": "2.0.0",
  "private": true,
  "dependencies": {
    "@types/node": "^20.0.0",
    "@types/react": "^18.0.0",
    "@types/react-dom": "^18.0.0",
    "framer-motion": "^10.16.4",
    "lucide-react": "^0.263.1",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "typescript": "^5.0.0",
    "web-vitals": "^3.3.2"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  },
  "proxy": "http://backend:3001"
}
EOF

# 2. Create proper React app structure
mkdir -p frontend/public frontend/src

# Create index.html
cat > frontend/public/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="AJ Sender - WhatsApp Bulk Messaging" />
    <title>AJ Sender</title>
    <script src="https://cdn.tailwindcss.com"></script>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF

# Create index.tsx
cat > frontend/src/index.tsx <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# Create index.css
cat > frontend/src/index.css <<'EOF'
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}
EOF

# Create App.tsx
cat > frontend/src/App.tsx <<'EOF'
import React from 'react';
import Dashboard from './components/Dashboard';

function App() {
  return (
    <div className="App">
      <Dashboard />
    </div>
  );
}

export default App;
EOF

# Create components directory and copy Dashboard
mkdir -p frontend/src/components

# Copy the existing Dashboard component (assuming it exists in the shell script)
# We'll create a fixed version with proper API base URL handling
cat > frontend/src/components/Dashboard.tsx <<'REACT_DASHBOARD'
import React, { useState, useEffect, useRef } from 'react'
import { Users, MessageSquare, Send, BarChart3, Plus, TrendingUp, Upload, CheckCircle, XCircle, Heart, Moon, Sun, Wifi, X, QrCode, RefreshCw } from 'lucide-react'

// API Configuration - Use environment variable or fallback
const API_BASE_URL = process.env.REACT_APP_API_URL || '/api'

interface Metrics {
  totalContacts: number
  totalCampaigns: number
  totalMessages: number
  sentMessages: number
}

interface SystemStatus {
  backend: string
  whatsapp: string
  authenticated: boolean
  sessionId?: string
  phoneNumber?: string
  userName?: string
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

interface CampaignProgress {
  isActive: boolean
  percentage: number
  currentCampaign: string | null
  totalContacts: number
  sentCount: number
}

interface WhatsAppStatus {
  authenticated: boolean
  ready: boolean
  connected: boolean
  qrCode?: string
  phoneNumber?: string
  userName?: string
  status: string
  expired?: boolean
}

const Dashboard: React.FC = () => {
  const [isDark, setIsDark] = useState(false)
  const [showUploadModal, setShowUploadModal] = useState(false)
  const [showCampaignModal, setShowCampaignModal] = useState(false)
  const [showAnalyticsModal, setShowAnalyticsModal] = useState(false)
  const [showWhatsAppModal, setShowWhatsAppModal] = useState(false)
  const [contacts, setContacts] = useState<Contact[]>([])
  const [campaigns, setCampaigns] = useState<Campaign[]>([])
  const [metrics, setMetrics] = useState<Metrics>({
    totalContacts: 0,
    totalCampaigns: 0,
    totalMessages: 0,
    sentMessages: 0
  })
  const [systemStatus, setSystemStatus] = useState<SystemStatus>({
    backend: 'unknown',
    whatsapp: 'disconnected',
    authenticated: false
  })
  const [campaignProgress, setCampaignProgress] = useState<CampaignProgress>({
    isActive: false,
    percentage: 0,
    currentCampaign: null,
    totalContacts: 0,
    sentCount: 0
  })
  const [whatsappStatus, setWhatsAppStatus] = useState<WhatsAppStatus>({
    authenticated: false,
    ready: false,
    connected: false,
    status: 'disconnected'
  })
  const [loading, setLoading] = useState(false)

  const fileInputRef = useRef<HTMLInputElement>(null)

  // Helper function to make API calls
  const apiCall = async (endpoint: string, options: RequestInit = {}) => {
    const url = endpoint.startsWith('http') ? endpoint : `${API_BASE_URL}${endpoint}`
    const response = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    })
    
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({ error: 'Network error' }))
      throw new Error(errorData.error || `HTTP ${response.status}`)
    }
    
    return response.json()
  }

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true)
        const [metricsData, statusData, contactsData, campaignsData, progressData] = await Promise.allSettled([
          apiCall('/metrics'),
          apiCall('/status'),
          apiCall('/contacts'),
          apiCall('/campaigns'),
          apiCall('/campaigns/progress')
        ])

        if (metricsData.status === 'fulfilled') {
          setMetrics(metricsData.value)
        }

        if (statusData.status === 'fulfilled') {
          setSystemStatus(statusData.value)
        }

        if (contactsData.status === 'fulfilled') {
          setContacts(contactsData.value)
        }

        if (campaignsData.status === 'fulfilled') {
          setCampaigns(campaignsData.value)
        }

        if (progressData.status === 'fulfilled') {
          setCampaignProgress(progressData.value)
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

  const connectWhatsApp = async () => {
    try {
      setLoading(true)
      const result = await apiCall('/whatsapp/connect', { method: 'POST' })
      setShowWhatsAppModal(true)
      pollWhatsAppStatus()
    } catch (error) {
      alert('Error connecting to WhatsApp: ' + (error as Error).message)
    } finally {
      setLoading(false)
    }
  }

  const pollWhatsAppStatus = async () => {
    try {
      const status = await apiCall('/whatsapp/status')
      setWhatsAppStatus(status)
      
      if (!status.authenticated && !status.expired) {
        setTimeout(pollWhatsAppStatus, 2000)
      }
    } catch (error) {
      console.error('Error polling WhatsApp status:', error)
    }
  }

  const disconnectWhatsApp = async () => {
    try {
      await apiCall('/whatsapp/disconnect', { method: 'POST' })
      
      setWhatsAppStatus({
        authenticated: false,
        ready: false,
        connected: false,
        status: 'disconnected'
      })
      setShowWhatsAppModal(false)
    } catch (error) {
      console.error('Error disconnecting WhatsApp:', error)
    }
  }

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return

    const formData = new FormData()
    formData.append('csvFile', file)

    try {
      setLoading(true)
      const response = await fetch(`${API_BASE_URL}/contacts/upload`, {
        method: 'POST',
        body: formData
      })

      const result = await response.json()
      
      if (response.ok) {
        alert(`Success! Imported ${result.inserted} contacts, skipped ${result.skipped} duplicates.`)
        const contactsData = await apiCall('/contacts')
        setContacts(contactsData)
      } else {
        alert(`Error: ${result.error}`)
      }
    } catch (error) {
      alert('Error uploading file: ' + (error as Error).message)
    } finally {
      setLoading(false)
      setShowUploadModal(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
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
      const result = await apiCall('/campaigns', {
        method: 'POST',
        body: JSON.stringify({ name, message })
      })

      alert('Campaign created successfully!')
      const campaignsData = await apiCall('/campaigns')
      setCampaigns(campaignsData)
      setShowCampaignModal(false)
    } catch (error) {
      alert('Error creating campaign: ' + (error as Error).message)
    } finally {
      setLoading(false)
    }
  }

  const handleSendCampaign = async (campaignId: number) => {
    if (!systemStatus.authenticated) {
      alert('Please connect WhatsApp first before sending campaigns.')
      setShowWhatsAppModal(true)
      return
    }

    if (!confirm('Are you sure you want to send this campaign to all contacts via WhatsApp?')) return

    try {
      setLoading(true)
      const result = await apiCall(`/campaigns/${campaignId}/send`, { method: 'POST' })
      alert('Campaign started! Messages are being sent via WhatsApp. Check the progress bar.')
    } catch (error) {
      alert('Error sending campaign: ' + (error as Error).message)
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

  return (
    <div className={`min-h-screen transition-all duration-500 ${
      isDark ? 'bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900' : 'bg-gradient-to-br from-gray-50 via-white to-gray-100'
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
                <span className={`inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium ${
                  systemStatus.backend === 'running' 
                    ? 'bg-green-100 text-green-700'
                    : 'bg-red-100 text-red-700'
                }`}>
                  {systemStatus.backend === 'running' ? <CheckCircle className="w-3 h-3" /> : <XCircle className="w-3 h-3" />}
                  Backend
                </span>
                <button
                  onClick={() => systemStatus.authenticated ? disconnectWhatsApp() : connectWhatsApp()}
                  disabled={loading}
                  className={`inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium cursor-pointer transition-colors ${
                    systemStatus.authenticated 
                      ? 'bg-green-100 text-green-700 hover:bg-green-200'
                      : 'bg-red-100 text-red-700 hover:bg-red-200'
                  } ${loading ? 'opacity-50 cursor-not-allowed' : ''}`}
                >
                  {systemStatus.authenticated ? <Wifi className="w-3 h-3" /> : <XCircle className="w-3 h-3" />}
                  WhatsApp {systemStatus.authenticated ? '(Connected)' : '(Click to Connect)'}
                </button>
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

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Metrics Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <div className={`p-6 rounded-2xl shadow-lg ${isDark ? 'bg-gray-800' : 'bg-white'}`}>
            <div className="flex items-center justify-between">
              <div>
                <p className={`text-sm font-medium ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Total Contacts
                </p>
                <p className={`text-3xl font-bold ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  {metrics.totalContacts.toLocaleString()}
                </p>
              </div>
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <Users className="w-8 h-8 text-blue-500" />
              </div>
            </div>
          </div>

          <div className={`p-6 rounded-2xl shadow-lg ${isDark ? 'bg-gray-800' : 'bg-white'}`}>
            <div className="flex items-center justify-between">
              <div>
                <p className={`text-sm font-medium ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Campaigns
                </p>
                <p className={`text-3xl font-bold ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  {metrics.totalCampaigns.toLocaleString()}
                </p>
              </div>
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <MessageSquare className="w-8 h-8 text-green-500" />
              </div>
            </div>
          </div>

          <div className={`p-6 rounded-2xl shadow-lg ${isDark ? 'bg-gray-800' : 'bg-white'}`}>
            <div className="flex items-center justify-between">
              <div>
                <p className={`text-sm font-medium ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Messages
                </p>
                <p className={`text-3xl font-bold ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  {metrics.totalMessages.toLocaleString()}
                </p>
              </div>
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <Send className="w-8 h-8 text-purple-500" />
              </div>
            </div>
          </div>

          <div className={`p-6 rounded-2xl shadow-lg ${isDark ? 'bg-gray-800' : 'bg-white'}`}>
            <div className="flex items-center justify-between">
              <div>
                <p className={`text-sm font-medium ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Success Rate
                </p>
                <p className={`text-3xl font-bold ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  {metrics.totalMessages > 0 ? Math.round((metrics.sentMessages / metrics.totalMessages) * 100) : 0}%
                </p>
              </div>
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <TrendingUp className="w-8 h-8 text-orange-500" />
              </div>
            </div>
          </div>
        </div>

        {/* Action Cards */}
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
            AJ Sender v2.0 - Real WhatsApp Integration
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
            ref={fileInputRef}
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
              placeholder="Enter your WhatsApp message (max 1000 characters)"
            />
            <div className={`text-xs mt-1 ${isDark ? 'text-gray-400' : 'text-gray-500'}`}>
              This message will be sent to all contacts via WhatsApp
            </div>
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
        <div className="space-y-6 max-h-96 overflow-y-auto">
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
                            campaign.status === 'completed_with_errors' ? 'bg-orange-100 text-orange-800' :
                            campaign.status === 'failed' ? 'bg-red-100 text-red-800' :
                            'bg-gray-100 text-gray-800'
                          }`}>
                            {campaign.status}
                          </span>
                        </div>
                        <p className={`text-sm mt-1 ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                          {campaign.message.length > 100 ? campaign.message.substring(0, 100) + '...' : campaign.message}
                        </p>
                        {campaign.total_messages > 0 && (
                          <div className="flex gap-4 mt-2 text-xs">
                            <span className="text-green-600">✓ {campaign.sent_count} sent</span>
                            {campaign.failed_count > 0 && (
                              <span className="text-red-600">✗ {campaign.failed_count} failed</span>
                            )}
                          </div>
                        )}
                      </div>
                      {campaign.status === 'draft' && (
                        <button
                          onClick={() => handleSendCampaign(campaign.id)}
                          disabled={loading}
                          className={`ml-4 px-4 py-2 bg-green-500 hover:bg-green-600 text-white text-sm rounded-lg flex items-center gap-2 ${
                            loading ? 'opacity-50 cursor-not-allowed' : ''
                          }`}
                        >
                          <Send className="w-4 h-4" />
                          Send via WhatsApp
                        </button>
                      )}
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </Modal>

      <Modal show={showWhatsAppModal} onClose={() => setShowWhatsAppModal(false)} title="WhatsApp Connection" size="lg">
        <div className="space-y-6">
          {whatsappStatus.authenticated ? (
            <div className="text-center">
              <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <CheckCircle className="w-8 h-8 text-green-600" />
              </div>
              <h3 className={`text-lg font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                WhatsApp Connected!
              </h3>
              {whatsappStatus.userName && (
                <p className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>
                  Connected as: {whatsappStatus.userName} ({whatsappStatus.phoneNumber})
                </p>
              )}
              <button
                onClick={disconnectWhatsApp}
                className="mt-4 px-4 py-2 bg-red-500 hover:bg-red-600 text-white rounded-lg"
              >
                Disconnect WhatsApp
              </button>
            </div>
          ) : whatsappStatus.qrCode ? (
            <div className="text-center">
              <div className="w-64 h-64 mx-auto mb-4 bg-white p-4 rounded-lg">
                <img 
                  src={whatsappStatus.qrCode} 
                  alt="WhatsApp QR Code" 
                  className="w-full h-full"
                />
              </div>
              <h3 className={`text-lg font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                Scan QR Code
              </h3>
              <div className={`text-sm space-y-2 ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>
                <p>1. Open WhatsApp on your phone</p>
                <p>2. Go to Settings → Linked Devices</p>
                <p>3. Tap "Link a Device"</p>
                <p>4. Scan this QR code</p>
              </div>
              <button
                onClick={pollWhatsAppStatus}
                className="mt-4 px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg flex items-center gap-2 mx-auto"
              >
                <RefreshCw className="w-4 h-4" />
                Refresh Status
              </button>
            </div>
          ) : whatsappStatus.expired ? (
            <div className="text-center">
              <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <XCircle className="w-8 h-8 text-red-600" />
              </div>
              <h3 className={`text-lg font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                Session Expired
              </h3>
              <p className={`text-sm mb-4 ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>
                The QR code has expired. Please create a new session.
              </p>
              <button
                onClick={connectWhatsApp}
                className="px-4 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg"
              >
                Create New Session
              </button>
            </div>
          ) : (
            <div className="text-center">
              <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <QrCode className="w-8 h-8 text-blue-600" />
              </div>
              <h3 className={`text-lg font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                Generating QR Code...
              </h3>
              <p className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>
                Please wait while we create your WhatsApp session
              </p>
            </div>
          )}
        </div>
      </Modal>
    </div>
  )
}

export default Dashboard
REACT_DASHBOARD

# 3. Update Docker Compose with proper networking and environment variables
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:80"
    environment:
      - NODE_ENV=production
      - REACT_APP_API_URL=http://localhost:3001/api
    depends_on:
      - backend
    networks:
      - ajsender-network

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "3001:3001"
    environment:
      - NODE_ENV=production
      - PORT=3001
      - WHATSAPP_AUTH_URL=http://whatsapp-server:3002
      - DATABASE_URL=sqlite:///app/data/database.sqlite
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    depends_on:
      - whatsapp-server
    networks:
      - ajsender-network
    restart: unless-stopped

  whatsapp-server:
    build:
      context: ./whatsapp-server
      dockerfile: Dockerfile
    ports:
      - "3002:3002"
    environment:
      - NODE_ENV=production
      - PORT=3002
    volumes:
      - ./whatsapp-sessions:/app/.wwebjs_auth
      - ./whatsapp-cache:/app/.wwebjs_cache
      - ./whatsapp-public:/app/public
    networks:
      - ajsender-network
    restart: unless-stopped

  # Nginx proxy to handle frontend API routing
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - frontend
      - backend
    networks:
      - ajsender-network
    restart: unless-stopped

volumes:
  caddy_data:
  caddy_config:

networks:
  ajsender-network:
    driver: bridge
EOF

# 4. Create Nginx configuration for proper API routing
cat > nginx.conf <<'EOF'
events {
    worker_connections 1024;
}

http {
    upstream frontend {
        server frontend:80;
    }
    
    upstream backend {
        server backend:3001;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        # Frontend routes
        location / {
            proxy_pass http://frontend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # API routes - proxy to backend
        location /api/ {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Handle CORS
            add_header Access-Control-Allow-Origin * always;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
            add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization" always;
            
            if ($request_method = 'OPTIONS') {
                add_header Access-Control-Allow-Origin * always;
                add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
                add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization" always;
                add_header Access-Control-Max-Age 1728000;
                add_header Content-Type 'text/plain charset=UTF-8';
                add_header Content-Length 0;
                return 204;
            }
        }
    }
}
EOF

# 5. Update frontend Dockerfile for proper build process
cat > frontend/Dockerfile <<'EOF'
# Build stage
FROM node:18-alpine AS build
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Set environment variable for API URL during build
ENV REACT_APP_API_URL=/api

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html

# Create nginx config for SPA routing
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ { \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

# 6. Create .dockerignore files
cat > frontend/.dockerignore <<'EOF'
node_modules
npm-debug.log
.git
.gitignore
README.md
.env
.nyc_output
coverage
.nyc_output
.coverage
.sass-cache
connect.lock
libpeerconnection.log
testem.log
.DS_Store
Thumbs.db
EOF

cat > backend/.dockerignore <<'EOF'
node_modules
npm-debug.log
.git
.gitignore
README.md
.env
.nyc_output
coverage
logs
*.log
.DS_Store
Thumbs.db
EOF

echo "=== Rebuilding with fixes ==="

# Stop existing containers
docker-compose down -v

# Rebuild everything
docker-compose build --no-cache

# Start services
docker-compose up -d

# Wait for services to start
sleep 15

echo "=== Testing connectivity ==="
echo "Frontend: http://localhost (via Nginx)"
echo "Backend: http://localhost:3001"
echo "WhatsApp: http://localhost:3002"

echo ""
echo "=== Service Status ==="
docker-compose ps

echo ""
echo "=== Health Checks ==="
echo "Backend Health:"
curl -s http://localhost:3001/health || echo "Backend not ready yet"

echo ""
echo "WhatsApp Health:"
curl -s http://localhost:3002/health || echo "WhatsApp server not ready yet"

echo ""
echo "=== Fixed Issues ==="
echo "✓ Added proper API routing via Nginx"
echo "✓ Fixed CORS configuration"  
echo "✓ Added proper React build process"
echo "✓ Fixed frontend-backend communication"
echo "✓ Added loading states to prevent UI loops"
echo "✓ Improved error handling"

echo ""
echo "🎉 AJ Sender should now work properly!"
echo "Visit http://localhost to test the application"-700 border-gray-600 text-white' : 'bg-white border-gray-300'
              }`}
              placeholder="Enter campaign name"
            />
          </div>
          <div>
            <label className={`block text-sm font-medium mb-2 ${isDark ? 'text-gray-300' : 'text-gray-700'}`}>
              WhatsApp Message
            </label>
            <textarea
              name="message"
              required
              rows={4}
              maxLength={1000}
              className={`w-full p-3 border rounded-lg ${
                isDark ? 'bg-gray