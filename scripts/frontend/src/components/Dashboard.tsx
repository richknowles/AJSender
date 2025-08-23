import React, { useState, useEffect } from 'react'
import { Users, MessageSquare, Send, BarChart3, Plus, TrendingUp, Upload, CheckCircle, XCircle, Clock, RefreshCw, Heart, Wifi, Moon, Sun } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

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

const Dashboard: React.FC = () => {
  const [isDark, setIsDark] = useState(false)
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

  // Fetch data from backend
  useEffect(() => {
    const fetchData = async () => {
      try {
        const [metricsRes, progressRes, statusRes] = await Promise.all([
          fetch('/api/metrics'),
          fetch('/api/campaigns/progress'),
          fetch('/api/status')
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
      } catch (error) {
        console.error('Error fetching data:', error)
      }
    }

    fetchData()
    const interval = setInterval(fetchData, 2000)
    return () => clearInterval(interval)
  }, [])

  // Animated Progress Bar
  const AnimatedProgressBar = () => {
    if (!campaignProgress.isActive && campaignProgress.percentage === 0) return null

    return (
      <motion.div 
        initial={{ opacity: 0, height: 0 }}
        animate={{ opacity: 1, height: 'auto' }}
        exit={{ opacity: 0, height: 0 }}
        className="fixed top-0 left-0 right-0 z-50"
      >
        <div className={`h-2 transition-colors duration-300 ${
          isDark ? 'bg-gray-800' : 'bg-gray-100'
        }`}>
          <motion.div
            className="h-full bg-gradient-to-r from-green-500 via-emerald-500 to-green-600 relative overflow-hidden shadow-lg"
            initial={{ width: 0 }}
            animate={{ width: `${campaignProgress.percentage}%` }}
            transition={{ 
              duration: 0.8, 
              ease: [0.4, 0, 0.2, 1]
            }}
          >
            {campaignProgress.isActive && (
              <motion.div
                className="absolute inset-0 bg-gradient-to-r from-transparent via-white/40 to-transparent"
                animate={{ x: [-200, 400] }}
                transition={{ 
                  duration: 2, 
                  repeat: Infinity, 
                  ease: "linear" 
                }}
              />
            )}
            <div className="absolute inset-0 bg-gradient-to-t from-green-600/20 to-transparent" />
          </motion.div>
        </div>
        
        {campaignProgress.percentage > 0 && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            className={`absolute top-3 right-4 px-3 py-1 rounded-full text-xs font-bold shadow-lg transition-colors duration-300 ${
              isDark 
                ? 'bg-gray-800 text-green-400 border border-green-500/30' 
                : 'bg-white text-green-600 border border-green-200'
            }`}
          >
            {campaignProgress.currentCampaign}: {campaignProgress.percentage}%
          </motion.div>
        )}
      </motion.div>
    )
  }

  // Stat Card Component with advanced animations
  const StatCard = ({ title, value, icon: Icon, color, delay = 0 }) => {
    const colorMap = {
      blue: {
        bg: isDark ? 'bg-blue-900/30' : 'bg-blue-50',
        icon: 'text-blue-500',
        gradient: 'from-blue-500 to-blue-600'
      },
      green: {
        bg: isDark ? 'bg-green-900/30' : 'bg-green-50',
        icon: 'text-green-500',
        gradient: 'from-green-500 to-green-600'
      },
      purple: {
        bg: isDark ? 'bg-purple-900/30' : 'bg-purple-50',
        icon: 'text-purple-500',
        gradient: 'from-purple-500 to-purple-600'
      },
      orange: {
        bg: isDark ? 'bg-orange-900/30' : 'bg-orange-50',
        icon: 'text-orange-500',
        gradient: 'from-orange-500 to-orange-600'
      }
    }

    const colors = colorMap[color]

    return (
      <motion.div
        initial={{ opacity: 0, y: 20, scale: 0.9 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ 
          delay,
          duration: 0.6,
          ease: [0.4, 0, 0.2, 1]
        }}
        whileHover={{ 
          y: -8,
          scale: 1.02,
          transition: { duration: 0.2 }
        }}
        className={`relative overflow-hidden rounded-2xl shadow-xl p-6 cursor-pointer transition-all duration-300 ${
          isDark 
            ? 'bg-gray-800/80 backdrop-blur-xl border border-gray-700/50 hover:border-gray-600/50' 
            : 'bg-white/80 backdrop-blur-xl border border-gray-200/50 hover:border-gray-300/50'
        }`}
      >
        {/* Animated background gradient */}
        <motion.div
          className={`absolute inset-0 bg-gradient-to-br ${colors.gradient} opacity-5`}
          whileHover={{ opacity: 0.1 }}
          transition={{ duration: 0.3 }}
        />
        
        <div className="relative z-10 flex items-center justify-between">
          <div className="flex-1">
            <motion.p 
              className={`text-sm font-medium mb-2 transition-colors duration-300 ${
                isDark ? 'text-gray-400' : 'text-gray-600'
              }`}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: delay + 0.2 }}
            >
              {title}
            </motion.p>
            <motion.p 
              className={`text-3xl font-bold transition-colors duration-300 ${
                isDark ? 'text-white' : 'text-gray-900'
              }`}
              initial={{ opacity: 0, scale: 0.5 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ 
                delay: delay + 0.3,
                type: "spring",
                stiffness: 200
              }}
            >
              {value}
            </motion.p>
          </div>
          
          <motion.div
            className={`p-4 rounded-xl ${colors.bg} transition-colors duration-300`}
            whileHover={{ 
              scale: 1.1,
              rotate: 5,
              transition: { duration: 0.2 }
            }}
            initial={{ opacity: 0, rotate: -180 }}
            animate={{ opacity: 1, rotate

# ===== AJSENDER-DEPLOYMENT-PART-2.SH =====

: 0 }}
            transition={{ 
              delay: delay + 0.4,
              duration: 0.8,
              ease: [0.4, 0, 0.2, 1]
            }}
          >
            <Icon className={`w-8 h-8 ${colors.icon}`} />
          </motion.div>
        </div>
        
        {/* Subtle shine effect */}
        <motion.div
          className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent opacity-0"
          whileHover={{ 
            opacity: 1,
            x: ['-100%', '100%'],
            transition: { duration: 0.6, ease: "easeInOut" }
          }}
        />
      </motion.div>
    )
  }

  // Status Badge Component
  const StatusBadge = ({ status, label }) => {
    const statusConfig = {
      running: { color: 'green', icon: CheckCircle },
      authenticated: { color: 'green', icon: Wifi },
      connected: { color: 'green', icon: CheckCircle },
      disconnected: { color: 'red', icon: XCircle },
      connecting: { color: 'yellow', icon: Clock }
    }

    const config = statusConfig[status] || statusConfig.disconnected
    const Icon = config.icon

    return (
      <motion.div
        initial={{ opacity: 0, scale: 0.8 }}
        animate={{ opacity: 1, scale: 1 }}
        className={`inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium transition-all duration-300 ${
          config.color === 'green' 
            ? isDark ? 'bg-green-900/30 text-green-400 border border-green-500/30' : 'bg-green-100 text-green-700 border border-green-200'
            : config.color === 'red'
            ? isDark ? 'bg-red-900/30 text-red-400 border border-red-500/30' : 'bg-red-100 text-red-700 border border-red-200'
            : isDark ? 'bg-yellow-900/30 text-yellow-400 border border-yellow-500/30' : 'bg-yellow-100 text-yellow-700 border border-yellow-200'
        }`}
      >
        <motion.div
          animate={{ 
            scale: config.color === 'yellow' ? [1, 1.2, 1] : 1,
            rotate: config.color === 'yellow' ? [0, 180, 360] : 0 
          }}
          transition={{ 
            duration: config.color === 'yellow' ? 2 : 0,
            repeat: config.color === 'yellow' ? Infinity : 0
          }}
        >
          <Icon className="w-3 h-3" />
        </motion.div>
        {label}
      </motion.div>
    )
  }

  return (
    <div className={`min-h-screen transition-all duration-500 ${
      isDark 
        ? 'bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900' 
        : 'bg-gradient-to-br from-gray-50 via-white to-gray-100'
    }`}>
      {/* Animated Progress Bar */}
      <AnimatePresence>
        <AnimatedProgressBar />
      </AnimatePresence>

      {/* Header */}
      <motion.header 
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className={`sticky top-0 z-40 backdrop-blur-xl border-b transition-all duration-300 ${
          isDark 
            ? 'bg-gray-900/80 border-gray-700/50' 
            : 'bg-white/80 border-gray-200/50'
        }`}
      >
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <motion.div 
              className="flex items-center gap-3"
              whileHover={{ scale: 1.02 }}
            >
              <motion.div
                className="p-2 rounded-xl bg-gradient-to-r from-green-500 to-emerald-600 shadow-lg"
                whileHover={{ 
                  rotate: [0, -10, 10, 0],
                  transition: { duration: 0.5 }
                }}
              >
                <Send className="w-6 h-6 text-white" />
              </motion.div>
              <div>
                <h1 className={`text-xl font-bold transition-colors duration-300 ${
                  isDark ? 'text-white' : 'text-gray-900'
                }`}>
                  AJ Sender
                </h1>
                <p className={`text-sm transition-colors duration-300 ${
                  isDark ? 'text-gray-400' : 'text-gray-600'
                }`}>
                  WhatsApp Bulk Messaging
                </p>
              </div>
            </motion.div>
            
            <div className="flex items-center gap-4">
              {/* System Status */}
              <div className="flex items-center gap-3">
                <StatusBadge 
                  status={systemStatus.backend === 'running' ? 'running' : 'disconnected'} 
                  label="Backend" 
                />
                <StatusBadge 
                  status={systemStatus.authenticated ? 'authenticated' : 'disconnected'} 
                  label="WhatsApp" 
                />
              </div>

              {/* Theme Toggle */}
              <motion.button
                onClick={() => setIsDark(!isDark)}
                className={`p-2 rounded-lg transition-all duration-300 ${
                  isDark 
                    ? 'bg-gray-700 hover:bg-gray-600 text-yellow-400' 
                    : 'bg-gray-100 hover:bg-gray-200 text-gray-700'
                }`}
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                <motion.div
                  animate={{ rotate: isDark ? 180 : 0 }}
                  transition={{ duration: 0.5 }}
                >
                  {isDark ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
                </motion.div>
              </motion.button>
            </div>
          </div>
        </div>
      </motion.header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Campaign Progress Banner */}
        <AnimatePresence>
          {campaignProgress.isActive && (
            <motion.div
              initial={{ opacity: 0, y: -20, height: 0 }}
              animate={{ opacity: 1, y: 0, height: 'auto' }}
              exit={{ opacity: 0, y: -20, height: 0 }}
              className={`mb-8 p-6 rounded-2xl shadow-xl transition-colors duration-300 ${
                isDark 
                  ? 'bg-gradient-to-r from-green-900/40 to-emerald-900/40 border border-green-500/30' 
                  : 'bg-gradient-to-r from-green-50 to-emerald-50 border border-green-200'
              }`}
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <motion.div
                    animate={{ rotate: 360 }}
                    transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
                  >
                    <RefreshCw className="w-6 h-6 text-green-500" />
                  </motion.div>
                  <div>
                    <h3 className={`font-semibold text-lg transition-colors duration-300 ${
                      isDark ? 'text-white' : 'text-gray-900'
                    }`}>
                      Campaign in Progress
                    </h3>
                    <p className={`text-sm transition-colors duration-300 ${
                      isDark ? 'text-gray-400' : 'text-gray-600'
                    }`}>
                      {campaignProgress.currentCampaign} • {campaignProgress.sentCount} of {campaignProgress.totalContacts} sent
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <div className={`text-2xl font-bold transition-colors duration-300 ${
                    isDark ? 'text-green-400' : 'text-green-600'
                  }`}>
                    {campaignProgress.percentage}%
                  </div>
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <StatCard
            title="Total Contacts"
            value={metrics.totalContacts.toLocaleString()}
            icon={Users}
            color="blue"
            delay={0}
          />
          <StatCard
            title="Campaigns"
            value={metrics.totalCampaigns.toLocaleString()}
            icon={MessageSquare}
            color="green"
            delay={0.1}
          />
          <StatCard
            title="Messages"
            value={metrics.totalMessages.toLocaleString()}
            icon={Send}
            color="purple"
            delay={0.2}
          />
          <StatCard
            title="Success Rate"
            value={`${metrics.totalMessages > 0 ? Math.round((metrics.sentMessages / metrics.totalMessages) * 100) : 0}%`}
            icon={TrendingUp}
            color="orange"
            delay={0.3}
          />
        </div>

        {/* Quick Actions */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5 }}
          className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8"
        >
          {[
            { title: 'Upload Contacts', icon: Upload, description: 'Import contacts from CSV', href: '/contacts' },
            { title: 'Create Campaign', icon: Plus, description: 'Start a new message campaign', href: '/campaigns' },
            { title: 'View Analytics', icon: BarChart3, description: 'Track campaign performance', href: '/analytics' }
          ].map((action, index) => (
            <motion.a
              key={action.title}
              href={action.href}
              whileHover={{ y: -4, scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              className={`block p-6 rounded-2xl shadow-lg transition-all duration-300 group cursor-pointer ${
                isDark 
                  ? 'bg-gray-800/80 backdrop-blur-xl border border-gray-700/50 hover:border-gray-600/50' 
                  : 'bg-white/80 backdrop-blur-xl border border-gray-200/50 hover:border-gray-300/50'
              }`}
            >
              <div className="flex items-start gap-4">
                <motion.div
                  className={`p-3 rounded-xl transition-all duration-300 ${
                    isDark ? 'bg-gray-700 group-hover:bg-gray-600' : 'bg-gray-100 group-hover:bg-gray-200'
                  }`}
                  whileHover={{ rotate: 5, scale: 1.1 }}
                >
                  <action.icon className={`w-6 h-6 transition-colors duration-300 ${
                    isDark ? 'text-gray-300' : 'text-gray-700'
                  }`} />
                </motion.div>
                <div className="flex-1">
                  <h3 className={`font-semibold mb-2 transition-colors duration-300 ${
                    isDark ? 'text-white' : 'text-gray-900'
                  }`}>
                    {action.title}
                  </h3>
                  <p className={`text-sm transition-colors duration-300 ${
                    isDark ? 'text-gray-400' : 'text-gray-600'
                  }`}>
                    {action.description}
                  </p>
                </div>
              </div>
            </motion.a>
          ))}
        </motion.div>

        {/* Footer */}
        <motion.footer
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.8 }}
          className={`text-center py-8 border-t transition-colors duration-300 ${
            isDark ? 'border-gray-700' : 'border-gray-200'
          }`}
        >
          <motion.div
            className="flex items-center justify-center gap-2 mb-2"
            whileHover={{ scale: 1.05 }}
          >
            <span className={`text-sm transition-colors duration-300 ${
              isDark ? 'text-gray-400' : 'text-gray-600'
            }`}>
              Made with
            </span>
            <motion.div
              animate={{ 
                scale: [1, 1.2, 1],
                color: ['#ef4444', '#f97316', '#eab308', '#22c55e', '#3b82f6', '#8b5cf6', '#ef4444']
              }}
              transition={{ 
                duration: 2,
                repeat: Infinity,
                ease: "easeInOut"
              }}
            >
              <Heart className="w-4 h-4 fill-current" />
            </motion.div>
            <span className={`text-sm transition-colors duration-300 ${
              isDark ? 'text-gray-400' : 'text-gray-600'
            }`}>
              for my girl
            </span>
          </motion.div>
          <p className={`text-xs transition-colors duration-300 ${
            isDark ? 'text-gray-500' : 'text-gray-500'
          }`}>
            AJ Sender v2.0 - WhatsApp Bulk Messaging Platform
          </p>
        </motion.footer>
      </main>
    </div>
  )
}

export default Dashboard
