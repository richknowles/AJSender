
import React from 'react'
import { CheckCircle, XCircle, Clock, Loader, Phone } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { useTheme } from '../contexts/ThemeContext'

interface MessageStatus {
  id: string
  phoneNumber: string
  status: 'pending' | 'sending' | 'sent' | 'failed'
  error?: string
  timestamp?: string
}

interface ProgressTrackerProps {
  messages: MessageStatus[]
  isActive: boolean
}

const ProgressTracker: React.FC<ProgressTrackerProps> = ({ messages, isActive }) => {
  const { isDark } = useTheme()
  
  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'pending':
        return <Clock className="h-4 w-4 text-gray-400" />
      case 'sending':
        return <Loader className="h-4 w-4 text-blue-500 animate-spin" />
      case 'sent':
        return <CheckCircle className="h-4 w-4 text-green-500" />
      case 'failed':
        return <XCircle className="h-4 w-4 text-red-500" />
      default:
        return null
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'pending':
        return isDark ? 'text-gray-400' : 'text-gray-500'
      case 'sending':
        return 'text-blue-500'
      case 'sent':
        return 'text-green-500'
      case 'failed':
        return 'text-red-500'
      default:
        return isDark ? 'text-gray-400' : 'text-gray-500'
    }
  }

  const stats = {
    total: messages.length,
    pending: messages.filter(m => m.status === 'pending').length,
    sending: messages.filter(m => m.status === 'sending').length,
    sent: messages.filter(m => m.status === 'sent').length,
    failed: messages.filter(m => m.status === 'failed').length
  }

  const progressPercentage = stats.total > 0 
    ? Math.round(((stats.sent + stats.failed) / stats.total) * 100) 
    : 0

  return (
    <div className="h-full flex flex-col">
      <div className="p-6 border-b border-gray-200 dark:border-gray-700">
        <div className="flex items-center mb-4">
          <Phone className="h-5 w-5 text-purple-600 mr-2" />
          <h2 className={`text-lg font-semibold transition-colors duration-300 ${
            isDark ? 'text-white' : 'text-gray-900'
          }`}>
            Sending Progress
          </h2>
        </div>
        
        {stats.total > 0 && (
          <div className="space-y-3">
            <div className="flex justify-between text-sm">
              <span className={`transition-colors duration-300 ${
                isDark ? 'text-gray-300' : 'text-gray-600'
              }`}>
                Progress
              </span>
              <span className={`font-medium transition-colors duration-300 ${
                isDark ? 'text-white' : 'text-gray-900'
              }`}>
                {progressPercentage}%
              </span>
            </div>
            <div className={`w-full rounded-full h-2 transition-colors duration-300 ${
              isDark ? 'bg-gray-700' : 'bg-gray-200'
            }`}>
              <motion.div
                className="bg-gradient-to-r from-green-500 to-green-600 h-2 rounded-full"
                initial={{ width: 0 }}
                animate={{ width: `${progressPercentage}%` }}
                transition={{ duration: 0.5, ease: "easeOut" }}
              />
            </div>
            
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div className="flex items-center">
                <CheckCircle className="h-4 w-4 text-green-500 mr-1" />
                <span className="text-green-500 font-medium">{stats.sent} sent</span>
              </div>
              <div className="flex items-center">
                <XCircle className="h-4 w-4 text-red-500 mr-1" />
                <span className="text-red-500 font-medium">{stats.failed} failed</span>
              </div>
              <div className="flex items-center">
                <Loader className={`h-4 w-4 text-blue-500 mr-1 ${isActive ? 'animate-spin' : ''}`} />
                <span className="text-blue-500 font-medium">{stats.sending} sending</span>
              </div>
              <div className="flex items-center">
                <Clock className="h-4 w-4 text-gray-400 mr-1" />
                <span className={`font-medium transition-colors duration-300 ${
                  isDark ? 'text-gray-400' : 'text-gray-500'
                }`}>
                  {stats.pending} pending
                </span>
              </div>
            </div>
          </div>
        )}
      </div>
      
      <div className="flex-1 overflow-y-auto">
        {messages.length === 0 ? (
          <div className="flex items-center justify-center h-full">
            <div className="text-center">
              <Phone className={`h-12 w-12 mx-auto mb-3 transition-colors duration-300 ${
                isDark ? 'text-gray-600' : 'text-gray-400'
              }`} />
              <p className={`transition-colors duration-300 ${
                isDark ? 'text-gray-400' : 'text-gray-500'
              }`}>
                Upload phone numbers to start tracking
              </p>
            </div>
          </div>
        ) : (
          <div className="p-6">
            <AnimatePresence>
              {messages.map((message, index) => (
                <motion.div
                  key={message.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: 20 }}
                  transition={{ delay: index * 0.05 }}
                  className={`flex items-center justify-between py-3 border-b transition-colors duration-300 ${
                    isDark ? 'border-gray-700' : 'border-gray-100'
                  }`}
                >
                  <div className="flex items-center space-x-3">
                    {getStatusIcon(message.status)}
                    <div>
                      <p className={`text-sm font-medium transition-colors duration-300 ${
                        isDark ? 'text-white' : 'text-gray-900'
                      }`}>
                        {message.phoneNumber}
                      </p>
                      {message.error && (
                        <p className="text-xs text-red-500">{message.error}</p>
                      )}
                    </div>
                  </div>
                  <div className="text-right">
                    <span className={`text-xs font-medium capitalize ${getStatusColor(message.status)}`}>
                      {message.status}
                    </span>
                    {message.timestamp && (
                      <p className={`text-xs transition-colors duration-300 ${
                        isDark ? 'text-gray-400' : 'text-gray-500'
                      }`}>
                        {message.timestamp}
                      </p>
                    )}
                  </div>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        )}
      </div>
    </div>
  )
}

export default ProgressTracker
