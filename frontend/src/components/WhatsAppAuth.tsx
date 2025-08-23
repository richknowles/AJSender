import React, { useState, useEffect } from 'react'
import { QrCode, Smartphone, CheckCircle, XCircle, RefreshCw, Heart } from 'lucide-react'
import { motion } from 'framer-motion'

const WhatsAppAuth: React.FC = () => {
  const [qrCode, setQrCode] = useState<string | null>(null)
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [status, setStatus] = useState('disconnected')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const fetchAuthStatus = async () => {
    try {
      const response = await fetch('/api/whatsapp/qr')
      const data = await response.json()
      
      setIsAuthenticated(data.authenticated)
      setQrCode(data.qrCode)
      setStatus(data.status || 'disconnected')
      
      if (data.authenticated) {
        setError(null)
      }
    } catch (err) {
      setError('Failed to connect to backend')
      console.error('Auth status error:', err)
    }
  }

  const handleLogout = async () => {
    setLoading(true)
    try {
      await fetch('/api/whatsapp/logout', { method: 'POST' })
      setIsAuthenticated(false)
      setQrCode(null)
      setStatus('disconnected')
      setError(null)
    } catch (err) {
      setError('Failed to logout')
    } finally {
      setLoading(false)
    }
  }

  const handleRestart = async () => {
    setLoading(true)
    try {
      await fetch('/api/whatsapp/restart', { method: 'POST' })
      setQrCode(null)
      setStatus('initializing')
      setError(null)
      
      setTimeout(fetchAuthStatus, 3000)
    } catch (err) {
      setError('Failed to restart WhatsApp client')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchAuthStatus()
    const interval = setInterval(fetchAuthStatus, 5000)
    return () => clearInterval(interval)
  }, [])

  const getStatusColor = () => {
    switch (status) {
      case 'authenticated':
        return 'text-green-600'
      case 'qr_ready':
        return 'text-yellow-600'
      case 'auth_failed':
        return 'text-red-600'
      default:
        return 'text-gray-600'
    }
  }

  return (
    <motion.div 
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="bg-white/80 backdrop-blur-sm rounded-xl shadow-lg p-6 card-hover border border-white/20"
    >
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-semibold gradient-text flex items-center">
          <Heart className="w-5 h-5 mr-2 text-pink-500 heart-animation" />
          WhatsApp Authentication
        </h2>
        <div className="flex items-center space-x-2">
          {(() => {
            switch (status) {
              case 'authenticated':
                return <CheckCircle className="w-5 h-5 text-green-600" />
              case 'qr_ready':
                return <QrCode className="w-5 h-5 text-yellow-600" />
              case 'auth_failed':
                return <XCircle className="w-5 h-5 text-red-600" />
              default:
                return <Smartphone className="w-5 h-5 text-gray-600" />
            }
          })()}
          <span className={`text-sm font-medium ${getStatusColor()}`}>
            {status === 'authenticated' ? 'Connected' : 
             status === 'qr_ready' ? 'Scan QR Code' :
             status === 'auth_failed' ? 'Authentication Failed' :
             status === 'initializing' ? 'Initializing...' :
             'Disconnected'}
          </span>
        </div>
      </div>

      {error && (
        <motion.div 
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          className="bg-red-50 border border-red-200 rounded-md p-4 mb-4"
        >
          <div className="flex">
            <XCircle className="w-5 h-5 text-red-400" />
            <div className="ml-3">
              <p className="text-sm text-red-800">{error}</p>
            </div>
          </div>
        </motion.div>
      )}

      {isAuthenticated ? (
        <motion.div 
          initial={{ scale: 0.9 }}
          animate={{ scale: 1 }}
          className="text-center"
        >
          <div className="bg-gradient-to-r from-green-50 to-blue-50 border border-green-200 rounded-xl p-6 mb-4">
            <CheckCircle className="w-12 h-12 text-green-600 mx-auto mb-3" />
            <p className="text-green-800 font-medium text-lg">WhatsApp Connected!</p>
            <p className="text-green-600 text-sm mt-1">Ready to send messages ✨</p>
          </div>
          
          <button
            onClick={handleLogout}
            disabled={loading}
            className="bg-gradient-to-r from-red-500 to-pink-500 hover:from-red-600 hover:to-pink-600 disabled:from-gray-400 disabled:to-gray-400 text-white px-6 py-3 rounded-lg transition-all duration-300 shadow-lg hover:shadow-xl"
          >
            {loading ? (
              <div className="flex items-center">
                <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                Logging out...
              </div>
            ) : (
              'Disconnect'
            )}
          </button>
        </motion.div>
      ) : (
        <div className="text-center">
          {qrCode ? (
            <motion.div
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
            >
              <div className="bg-white border-2 border-gray-200 rounded-xl p-6 mb-4 inline-block shadow-inner">
                <img 
                  src={qrCode} 
                  alt="WhatsApp QR Code" 
                  className="w-64 h-64 mx-auto rounded-lg"
                />
              </div>
              <p className="text-gray-600 mb-4">
                Scan this QR code with WhatsApp! 📱✨
              </p>
            </motion.div>
          ) : (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
            >
              <QrCode className="w-16 h-16 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-500 mb-4">
                {status === 'initializing' ? 'Generating QR code...' : 'Ready to connect!'}
              </p>
            </motion.div>
          )}
          
          <button
            onClick={handleRestart}
            disabled={loading}
            className="bg-gradient-to-r from-blue-500 to-purple-500 hover:from-blue-600 hover:to-purple-600 disabled:from-gray-400 disabled:to-gray-400 text-white px-6 py-3 rounded-lg transition-all duration-300 shadow-lg hover:shadow-xl"
          >
            {loading ? (
              <div className="flex items-center">
                <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                {qrCode ? 'Refreshing...' : 'Initializing...'}
              </div>
            ) : (
              qrCode ? 'Refresh QR Code' : 'Start Authentication'
            )}
          </button>
        </div>
      )}
    </motion.div>
  )
}

export default WhatsAppAuth
