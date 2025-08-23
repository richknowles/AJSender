
import React, { useState, useEffect } from 'react'
import { Calendar, Users, CheckCircle, XCircle, Clock, BarChart3 } from 'lucide-react'
import { motion } from 'framer-motion'
import { useTheme } from '../contexts/ThemeContext'

interface BatchData {
  id: string
  name: string
  date: string
  total: number
  sent: number
  failed: number
  status: 'completed' | 'processing' | 'failed'
  messagePreview: string
}

const BatchHistory: React.FC = () => {
  const { isDark } = useTheme()
  const [batches, setBatches] = useState<BatchData[]>([])

  useEffect(() => {
    // Simulate loading batch history
    const mockBatches: BatchData[] = [
      {
        id: 'BATCH-001',
        name: 'Welcome Campaign - January 2025',
        date: '2025-01-16T08:00:00.000Z',
        total: 150,
        sent: 145,
        failed: 5,
        status: 'completed',
        messagePreview: 'Hello! Welcome to our platform. We\'re excited to have you...'
      },
      {
        id: 'BATCH-002',
        name: 'Product Launch Announcement',
        date: '2025-01-15T14:30:00.000Z',
        total: 320,
        sent: 318,
        failed: 2,
        status: 'completed',
        messagePreview: 'Exciting news! Our new product is now available. Check it out...'
      },
      {
        id: 'BATCH-003',
        name: 'Weekend Sale Promotion',
        date: '2025-01-14T10:15:00.000Z',
        total: 85,
        sent: 82,
        failed: 3,
        status: 'completed',
        messagePreview: 'Don\'t miss our weekend sale! Get up to 50% off on selected items...'
      },
      {
        id: 'BATCH-004',
        name: 'Customer Survey Request',
        date: '2025-01-13T16:45:00.000Z',
        total: 200,
        sent: 156,
        failed: 12,
        status: 'processing',
        messagePreview: 'We value your feedback! Please take a moment to complete our survey...'
      }
    ]
    setBatches(mockBatches)
  }, [])

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'completed':
        return <CheckCircle className="h-5 w-5 text-green-500" />
      case 'processing':
        return <Clock className="h-5 w-5 text-yellow-500" />
      case 'failed':
        return <XCircle className="h-5 w-5 text-red-500" />
      default:
        return null
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed':
        return 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300'
      case 'processing':
        return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300'
      case 'failed':
        return 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300'
      default:
        return 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  const calculateSuccessRate = (sent: number, total: number) => {
    return total > 0 ? Math.round((sent / total) * 100) : 0
  }

  const totalStats = batches.reduce(
    (acc, batch) => ({
      totalMessages: acc.totalMessages + batch.total,
      totalSent: acc.totalSent + batch.sent,
      totalFailed: acc.totalFailed + batch.failed
    }),
    { totalMessages: 0, totalSent: 0, totalFailed: 0 }
  )

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className={`rounded-xl p-6 text-white transition-all duration-300 ${
        isDark 
          ? 'bg-gradient-to-r from-blue-700 to-blue-800 shadow-blue-900/20' 
          : 'bg-gradient-to-r from-blue-600 to-blue-700 shadow-blue-600/20'
      } shadow-xl`}>
        <h1 className="text-3xl font-bold mb-2">Batch History</h1>
        <p className={`transition-colors duration-300 ${
          isDark ? 'text-blue-100' : 'text-blue-100'
        }`}>
          Track and analyze your messaging campaigns
        </p>
      </div>

      {/* Overall Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className={`rounded-xl p-6 shadow-sm transition-all duration-300 ${
          isDark 
            ? 'bg-gray-800 shadow-gray-900/20' 
            : 'bg-white shadow-gray-200/20'
        }`}>
          <div className="flex items-center">
            <BarChart3 className="h-8 w-8 text-blue-600" />
            <div className="ml-4">
              <p className={`text-sm font-medium transition-colors duration-300 ${
                isDark ? 'text-gray-400' : 'text-gray-600'
              }`}>
                Total Campaigns
              </p>
              <p className={`text-2xl font-bold transition-colors duration-300 ${
                isDark ? 'text-white' : 'text-gray-900'
              }`}>
                {batches.length}
              </p>
            </div>
          </div>
        </div>
        
        <div className={`rounded-xl p-6 shadow-sm transition-all duration-300 ${
          isDark 
            ? 'bg-gray-800 shadow-gray-900/20' 
            : 'bg-white shadow-gray-200/20'
        }`}>
          <div className="flex items-center">
            <Users className="h-8 w-8 text-purple-600" />
            <div className="ml-4">
              <p className={`text-sm font-medium transition-colors duration-300 ${
                isDark ? 'text-gray-400' : 'text-gray-600'
              }`}>
                Total Messages
              </p>
              <p className={`text-2xl font-bold transition-colors duration-300 ${
                isDark ? 'text-white' : 'text-gray-900'
              }`}>
                {totalStats.totalMessages.toLocaleString()}
              </p>
            </div>
          </div>
        </div>
        
        <div className={`rounded-xl p-6 shadow-sm transition-all duration-300 ${
          isDark 
            ? 'bg-gray-800 shadow-gray-900/20' 
            : 'bg-white shadow-gray-200/20'
        }`}>
          <div className="flex items-center">
            <CheckCircle className="h-8 w-8 text-green-600" />
            <div className="ml-4">
              <p className={`text-sm font-medium transition-colors duration-300 ${
                isDark ? 'text-gray-400' : 'text-gray-600'
              }`}>
                Successfully Sent
              </p>
              <p className={`text-2xl font-bold transition-colors duration-300 ${
                isDark ? 'text-white' : 'text-gray-900'
              }`}>
                {totalStats.totalSent.toLocaleString()}
              </p>
            </div>
          </div>
        </div>
        
        <div className={`rounded-xl p-6 shadow-sm transition-all duration-300 ${
          isDark 
            ? 'bg-gray-800 shadow-gray-900/20' 
            : 'bg-white shadow-gray-200/20'
        }`}>
          <div className="flex items-center">
            <BarChart3 className="h-8 w-8 text-orange-600" />
            <div className="ml-4">
              <p className={`text-sm font-medium transition-colors duration-300 ${
                isDark ? 'text-gray-400' : 'text-gray-600'
              }`}>
                Success Rate
              </p>
              <p className={`text-2xl font-bold transition-colors duration-300 ${
                isDark ? 'text-white' : 'text-gray-900'
              }`}>
                {calculateSuccessRate(totalStats.totalSent, totalStats.totalMessages)}%
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Batch List */}
      <div className={`rounded-xl shadow-sm overflow-hidden transition-all duration-300 ${
        isDark 
          ? 'bg-gray-800 shadow-gray-900/20' 
          : 'bg-white shadow-gray-200/20'
      }`}>
        <div className={`px-6 py-4 border-b transition-colors duration-300 ${
          isDark ? 'border-gray-700' : 'border-gray-200'
        }`}>
          <h2 className={`text-lg font-semibold transition-colors duration-300 ${
            isDark ? 'text-white' : 'text-gray-900'
          }`}>
            Recent Campaigns
          </h2>
        </div>
        
        <div className={`divide-y transition-colors duration-300 ${
          isDark ? 'divide-gray-700' : 'divide-gray-200'
        }`}>
          {batches.map((batch, index) => (
            <motion.div
              key={batch.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.1 }}
              className={`p-6 transition-all duration-300 ${
                isDark ? 'hover:bg-gray-750' : 'hover:bg-gray-50'
              }`}
            >
              <div className="flex items-center justify-between">
                <div className="flex-1">
                  <div className="flex items-center space-x-3 mb-2">
                    <h3 className={`text-lg font-semibold transition-colors duration-300 ${
                      isDark ? 'text-white' : 'text-gray-900'
                    }`}>
                      {batch.name}
                    </h3>
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium transition-colors duration-300 ${getStatusColor(batch.status)}`}>
                      {getStatusIcon(batch.status)}
                      <span className="ml-1 capitalize">{batch.status}</span>
                    </span>
                  </div>
                  
                  <div className={`flex items-center space-x-6 text-sm mb-3 transition-colors duration-300 ${
                    isDark ? 'text-gray-400' : 'text-gray-600'
                  }`}>
                    <div className="flex items-center">
                      <Calendar className="h-4 w-4 mr-1" />
                      {formatDate(batch.date)}
                    </div>
                    <div className="flex items-center">
                      <Users className="h-4 w-4 mr-1" />
                      {batch.total} recipients
                    </div>
                  </div>
                  
                  <p className={`text-sm mb-4 transition-colors duration-300 ${
                    isDark ? 'text-gray-400' : 'text-gray-600'
                  }`}>
                    {batch.messagePreview}
                  </p>
                  
                  <div className="flex items-center space-x-6">
                    <div className="flex items-center text-sm">
                      <CheckCircle className="h-4 w-4 text-green-500 mr-1" />
                      <span className="text-green-600 font-medium">{batch.sent} sent</span>
                    </div>
                    {batch.failed > 0 && (
                      <div className="flex items-center text-sm">
                        <XCircle className="h-4 w-4 text-red-500 mr-1" />
                        <span className="text-red-600 font-medium">{batch.failed} failed</span>
                      </div>
                    )}
                    <div className={`text-sm transition-colors duration-300 ${
                      isDark ? 'text-gray-400' : 'text-gray-600'
                    }`}>
                      Success rate: {calculateSuccessRate(batch.sent, batch.total)}%
                    </div>
                  </div>
                </div>
                
                <div className="ml-6">
                  <div className="text-right">
                    <div className={`text-2xl font-bold transition-colors duration-300 ${
                      isDark ? 'text-white' : 'text-gray-900'
                    }`}>
                      {calculateSuccessRate(batch.sent, batch.total)}%
                    </div>
                    <div className={`text-sm transition-colors duration-300 ${
                      isDark ? 'text-gray-400' : 'text-gray-500'
                    }`}>
                      Success Rate
                    </div>
                  </div>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </div>
  )
}

export default BatchHistory
