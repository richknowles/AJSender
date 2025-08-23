import React, { useState, useEffect, useRef } from 'react'
import { Users, MessageSquare, Send, BarChart3, Plus, TrendingUp, Upload, CheckCircle, XCircle, Heart, Moon, Sun, Wifi, X, FileText } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

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
}

interface Contact {
  id: number
  phone_number: string
  name: string
  created_at: string
}

interface Campaign {
  id: number
  name: string
  message: string
  status: string
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
  const [systemStatus, setSystemStatus] = useState<SystemStatus>({
    backend: 'unknown',
    whatsapp: 'disconnected',
    authenticated: false
  })

  const fileInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [metricsRes, statusRes, contactsRes, campaignsRes] = await Promise.all([
          fetch('/api/metrics'),
          fetch('/api/status'),
          fetch('/api/contacts'),
          fetch('/api/campaigns')
        ])

        if (metricsRes.ok) {
          const metricsData = await metricsRes.json()
          setMetrics(metricsData)
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
      }
    }

    fetchData()
    const interval = setInterval(fetchData, 10000)
    return () => clearInterval(interval)
  }, [])

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return

    const formData = new FormData()
    formData.append('csvFile', file)

    try {
      const response = await fetch('/api/contacts/upload', {
        method: 'POST',
        body: formData
      })

      const result = await response.json()
      
      if (response.ok) {
        alert(`Success! Imported ${result.inserted} contacts, skipped ${result.skipped} duplicates.`)
        // Refresh contacts
        const contactsRes = await fetch('/api/contacts')
        if (contactsRes.ok) {
          const contactsData = await contactsRes.json()
          setContacts(contactsData)
        }
      } else {
        alert(`Error: ${result.error}`)
      }
    } catch (error) {
      alert('Error uploading file: ' + error)
    }

    setShowUploadModal(false)
    if (fileInputRef.current) fileInputRef.current.value = ''
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
      const response = await fetch('/api/campaigns', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, message })
      })

      const result = await response.json()
      
      if (response.ok) {
        alert('Campaign created successfully!')
        // Refresh campaigns
        const campaignsRes = await fetch('/api/campaigns')
        if (campaignsRes.ok) {
          const campaignsData = await campaignsRes.json()
          setCampaigns(campaignsData)
        }
      } else {
        alert(`Error: ${result.error}`)
      }
    } catch (error) {
      alert('Error creating campaign: ' + error)
    }

    setShowCampaignModal(false)
  }

  const handleSendCampaign = async (campaignId: number) => {
    if (!confirm('Are you sure you want to send this campaign to all contacts?')) return

    try {
      const response = await fetch(`/api/campaigns/${campaignId}/send`, {
        method: 'POST'
      })

      const result = await response.json()
      
      if (response.ok) {
        alert(`Campaign sent! ${result.sent} messages delivered to ${result.total} contacts.`)
      } else {
        alert(`Error: ${result.error}`)
      }
    } catch (error) {
      alert('Error sending campaign: ' + error)
    }
  }

  const Modal = ({ show, onClose, title, children }: { 
    show: boolean
    onClose: () => void
    title: string
    children: React.ReactNode 
  }) => (
    <AnimatePresence>
      {show && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
          onClick={onClose}
        >
          <motion.div
            initial={{ scale: 0.95, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.95, opacity: 0 }}
            onClick={e => e.stopPropagation()}
            className={`max-w-md w-full rounded-2xl shadow-xl ${
              isDark ? 'bg-gray-800 border border-gray-700' : 'bg-white border border-gray-200'
            }`}
          >
            <div className="flex items-center justify-between p-6 border-b border-gray-200">
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
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  )

  return (
    <div className={`min-h-screen transition-all duration-500 ${
      isDark ? 'bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900' : 'bg-gradient-to-br from-gray-50 via-white to-gray-100'
    }`}>
      <motion.header 
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className={`sticky top-0 z-40 backdrop-blur-xl border-b transition-all duration-300 ${
          isDark ? 'bg-gray-900/80 border-gray-700/50' : 'bg-white/80 border-gray-200/50'
        }`}
      >
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-xl bg-gradient-to-r from-green-500 to-emerald-600 shadow-lg">
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
                    ? 'bg-green-100 text-green-700 border border-green-200'
                    : 'bg-red-100 text-red-700 border border-red-200'
                }`}>
                  {systemStatus.backend === 'running' ? <CheckCircle className="w-3 h-3" /> : <XCircle className="w-3 h-3" />}
                  Backend
                </span>
                <span className={`inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium ${
                  systemStatus.authenticated 
                    ? 'bg-green-100 text-green-700 border border-green-200'
                    : 'bg-red-100 text-red-700 border border-red-200'
                }`}>
                  {systemStatus.authenticated ? <Wifi className="w-3 h-3" /> : <XCircle className="w-3 h-3" />}
                  WhatsApp
                </span>
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
      </motion.header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0, duration: 0.5 }}
            className={`p-6 rounded-2xl shadow-lg ${isDark ? 'bg-gray-800' : 'bg-white'}`}
          >
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
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1, duration: 0.5 }}
            className={`p-6 rounded-2xl shadow-lg ${isDark ? 'bg-gray-800' : 'bg-white'}`}
          >
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
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2, duration: 0.5 }}
            className={`p-6 rounded-2xl shadow-lg ${isDark ? 'bg-gray-800' : 'bg-white'}`}
          >
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
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3, duration: 0.5 }}
            className={`p-6 rounded-2xl shadow-lg ${isDark ? 'bg-gray-800' : 'bg-white'}`}
          >
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
          </motion.div>
        </div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
          className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8"
        >
          <motion.div
            whileHover={{ y: -4, scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => setShowUploadModal(true)}
            className={`p-6 rounded-2xl shadow-lg cursor-pointer transition-all ${
              isDark ? 'bg-gray-800 hover:bg-gray-750' : 'bg-white hover:shadow-xl'
            }`}
          >
            <div className="flex items-start gap-4">
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <Upload className={`w-6 h-6 ${isDark ? 'text-gray-300' : 'text-gray-700'}`} />
              </div>
              <div className="flex-1">
                <h3 className={`font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  Upload Contacts
                </h3>
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Import contacts from CSV
                </p>
              </div>
            </div>
          </motion.div>

          <motion.div
            whileHover={{ y: -4, scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => setShowCampaignModal(true)}
            className={`p-6 rounded-2xl shadow-lg cursor-pointer transition-all ${
              isDark ? 'bg-gray-800 hover:bg-gray-750' : 'bg-white hover:shadow-xl'
            }`}
          >
            <div className="flex items-start gap-4">
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <Plus className={`w-6 h-6 ${isDark ? 'text-gray-300' : 'text-gray-700'}`} />
              </div>
              <div className="flex-1">
                <h3 className={`font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  Create Campaign
                </h3>
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Start a new message campaign
                </p>
              </div>
            </div>
          </motion.div>

          <motion.div
            whileHover={{ y: -4, scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => setShowAnalyticsModal(true)}
            className={`p-6 rounded-2xl shadow-lg cursor-pointer transition-all ${
              isDark ? 'bg-gray-800 hover:bg-gray-750' : 'bg-white hover:shadow-xl'
            }`}
          >
            <div className="flex items-start gap-4">
              <div className={`p-3 rounded-xl ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
                <BarChart3 className={`w-6 h-6 ${isDark ? 'text-gray-300' : 'text-gray-700'}`} />
              </div>
              <div className="flex-1">
                <h3 className={`font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
                  View Analytics
                </h3>
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                  Track campaign performance
                </p>
              </div>
            </div>
          </motion.div>
        </motion.div>

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

      {/* Upload Modal */}
      <Modal show={showUploadModal} onClose={() => setShowUploadModal(false)} title="Upload Contacts">
        <div className="space-y-4">
          <p className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>
            Upload a CSV file with contacts. The file should have columns: phone_number, name
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

      {/* Campaign Modal */}
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
              className={`w-full p-3 border rounded-lg ${
                isDark ? 'bg-gray-700 border-gray-600 text-white' : 'bg-white border-gray-300'
              }`}
              placeholder="Enter your message"
            />
          </div>
          <button
            type="submit"
            className="w-full bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-lg font-medium"
          >
            Create Campaign
          </button>
        </form>
      </Modal>

      {/* Analytics Modal */}
      <Modal show={showAnalyticsModal} onClose={() => setShowAnalyticsModal(false)} title="Analytics & Campaigns">
        <div className="space-y-4 max-h-96 overflow-y-auto">
          <div className="grid grid-cols-2 gap-4 mb-4">
            <div className={`p-3 rounded-lg ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
              <div className="text-2xl font-bold text-green-500">{contacts.length}</div>
              <div className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>Total Contacts</div>
            </div>
            <div className={`p-3 rounded-lg ${isDark ? 'bg-gray-700' : 'bg-gray-100'}`}>
              <div className="text-2xl font-bold text-blue-500">{campaigns.length}</div>
              <div className={`text-sm ${isDark ? 'text-gray-300' : 'text-gray-600'}`}>Campaigns</div>
            </div>
          </div>
          
          <div>
            <h4 className={`font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-900'}`}>
              Recent Campaigns
            </h4>
            <div className="space-y-2">
              {campaigns.length === 0 ? (
                <p className={`text-sm ${isDark ? 'text-gray-400' : 'text-gray-500'}`}>
                  No campaigns created yet
                </p>
              ) : (
                campaigns.slice(0, 5).map(campaign => (
                  <div
                    key={campaign.id}
                    className={`p-3 rounded-lg border ${isDark ? 'bg-gray-700 border-gray-600' : 'bg-gray-50 border-gray-200'}`}
                  >
                    <div className="flex justify-between items-start">
                      <div className="flex-1">
                        <h5 className={`font-medium ${isDark ? 'text-white' : 'text-gray-900'}`}>
                          {campaign.name}
                        </h5>
                        <p className={`text-sm mt-1 ${isDark ? 'text-gray-400' : 'text-gray-600'}`}>
                          {campaign.message.length > 50 ? campaign.message.substring(0, 50) + '...' : campaign.message}
                        </p>
                        <span className={`inline-block mt-2 px-2 py-1 text-xs rounded ${
                          campaign.status === 'completed' ? 'bg-green-100 text-green-800' :
                          campaign.status === 'sending' ? 'bg-yellow-100 text-yellow-800' :
                          'bg-gray-100 text-gray-800'
                        }`}>
                          {campaign.status}
                        </span>
                      </div>
                      {campaign.status === 'draft' && (
                        <button
                          onClick={() => handleSendCampaign(campaign.id)}
                          className="ml-2 px-3 py-1 bg-green-500 hover:bg-green-600 text-white text-xs rounded"
                        >
                          Send
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
    </div>
  )
}

export default Dashboard
