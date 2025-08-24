#!/usr/bin/env bash
# Dashboard Restore Fix Script - Fixes the campaign creation form
set -euo pipefail

cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Restoring Complete Dashboard with Fixes ==="

# Stop containers
docker-compose down

# Create the complete Dashboard with the campaign form fix
cat > frontend/src/components/Dashboard.tsx << 'EOF'
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
                          <div className="flex items-center gap-4 mt-3">
                            <div className={`text-xs ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                              Sent: {campaign.sent_count}/{campaign.total_messages}
                            </div>
                            {campaign.failed_count > 0 && (
                              <div className="text-xs text-red-500">
                                Failed: {campaign.failed_count}
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                      {campaign.status === 'draft' && (
                        <button
                          onClick={() => handleSendCampaign(campaign.id)}
                          disabled={loading}
                          className={`ml-4 px-3 py-1 text-xs bg-green-500 hover:bg-green-600 text-white rounded-lg font-medium ${
                            loading ? 'opacity-50 cursor-not-allowed' : ''
                          }`}
                        >
                          Send Now
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
        <div className="space-y-4">
          {whatsappStatus.qrCode && !whatsappStatus.authenticated ? (
            <div className="text-center">
              <div className={`p-4 rounded-lg ${isDark ? 'bg-gray-700' : 'bg-gray-100'} mb-4`}>
                <QrCode className="w-8 h-8 mx-auto mb-2" />
                <p className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>
                  Scan this QR code with WhatsApp on your phone
                </p>
              </div>
              <div className="bg-white p-4 rounded-lg inline-block">
                <img src={whatsappStatus.qrCode} alt="WhatsApp QR Code" className="max-w-full h-auto" />
              </div>
              <div className="flex items-center justify-center gap-2 mt-4">
                <RefreshCw className="w-4 h-4 animate-spin" />
                <span className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Waiting for scan...
                </span>
              </div>
            </div>
          ) : whatsappStatus.authenticated ? (
            <div className="text-center">
              <div className={`p-4 rounded-lg ${isDark ? 'bg-gray-700' : 'bg-gray-100'} mb-4`}>
                <CheckCircle className="w-8 h-8 text-green-500 mx-auto mb-2" />
                <p className={`text-lg font-semibold ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  WhatsApp Connected!
                </p>
                {whatsappStatus.phoneNumber && (
                  <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                    Phone: {whatsappStatus.phoneNumber}
                  </p>
                )}
                {whatsappStatus.userName && (
                  <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                    Name: {whatsappStatus.userName}
                  </p>
                )}
              </div>
              <div className="flex gap-2 justify-center">
                <button
                  onClick={() => setShowWhatsAppModal(false)}
                  className="px-4 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg font-medium"
                >
                  Continue
                </button>
                <button
                  onClick={disconnectWhatsApp}
                  className={`px-4 py-2 border rounded-lg font-medium ${
                    isDark ? 'border-gray-600 text-gray-300 hover:bg-gray-700' : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                  }`}
                >
                  Disconnect
                </button>
              </div>
            </div>
          ) : whatsappStatus.expired ? (
            <div className="text-center">
              <div className={`p-4 rounded-lg ${isDark ? 'bg-gray-700' : 'bg-gray-100'} mb-4`}>
                <XCircle className="w-8 h-8 text-red-500 mx-auto mb-2" />
                <p className={`text-lg font-semibold ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  QR Code Expired
                </p>
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Please try connecting again
                </p>
              </div>
              <button
                onClick={connectWhatsApp}
                className="px-4 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg font-medium"
              >
                Generate New QR Code
              </button>
            </div>
          ) : (
            <div className="text-center">
              <div className={`p-4 rounded-lg ${isDark ? 'bg-gray-700' : 'bg-gray-100'} mb-4`}>
                <div className="flex items-center justify-center gap-2">
                  <RefreshCw className="w-4 h-4 animate-spin" />
                  <span className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                    Initializing WhatsApp connection...
                  </span>
                </div>
              </div>
            </div>
          )}
        </div>
      </Modal>
    </div>
  )
}

export default Dashboard
EOF

echo "✅ Dashboard component completed!"

# Create a simple backend API structure if it doesn't exist
echo "=== Setting up Backend Structure ==="

# Create backend directory structure
mkdir -p backend/src/{routes,models,services,middleware}

# Create package.json for backend
cat > backend/package.json << 'EOF'
{
  "name": "aj-sender-backend",
  "version": "2.0.0",
  "description": "WhatsApp Bulk Messaging Backend",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "build": "echo 'No build step required'",
    "test": "echo 'No tests specified'"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "sqlite3": "^5.1.6",
    "multer": "^1.4.5-lts.1",
    "csv-parser": "^3.0.0",
    "whatsapp-web.js": "^1.23.0",
    "qrcode": "^1.5.3",
    "dotenv": "^16.3.1",
    "express-rate-limit": "^6.8.1",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

# Create main backend server file
cat > backend/src/index.js << 'EOF'
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
EOF

# Create API routes
cat > backend/src/routes/api.js << 'EOF'
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
EOF

# Create contacts routes
cat > backend/src/routes/contacts.js << 'EOF'
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
EOF

# Create campaigns routes
cat > backend/src/routes/campaigns.js << 'EOF'
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
EOF

# Create WhatsApp routes
cat > backend/src/routes/whatsapp.js << 'EOF'
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
EOF

echo "✅ Backend routes created!"

# Build and start containers
echo "=== Building and Starting Application ==="
docker-compose up --build -d

echo ""
echo "🎉 AJ Sender deployment completed!"
echo ""
echo "📱 Application URLs:"
echo "   Frontend: http://localhost:3000"
echo "   Backend:  http://localhost:3001"
echo "   Health:   http://localhost:3001/health"
echo ""
echo "🔧 Management Commands:"
echo "   View logs:     docker-compose logs -f"
echo "   Stop app:      docker-compose down"
echo "   Restart:       docker-compose restart"
echo ""
echo "✨ Your WhatsApp bulk messaging application is ready!"
echo "   1. Upload contacts via CSV"
echo "   2. Connect WhatsApp by scanning QR code"
echo "   3. Create and send campaigns"
echo ""