
import React from 'react'
import { Users, CheckCircle, XCircle, Clock } from 'lucide-react'
import { motion } from 'framer-motion'
import { useTheme } from '../contexts/ThemeContext'

interface StatsCardsProps {
  stats: {
    total: number
    sent: number
    failed: number
    pending: number
  }
}

const StatsCards: React.FC<StatsCardsProps> = ({ stats }) => {
  const { isDark } = useTheme()
  
  const cards = [
    {
      title: 'Total Recipients',
      value: stats.total,
      icon: Users,
      color: 'blue',
      bgColor: isDark ? 'bg-blue-900/20' : 'bg-blue-50',
      iconColor: 'text-blue-600'
    },
    {
      title: 'Successfully Sent',
      value: stats.sent,
      icon: CheckCircle,
      color: 'green',
      bgColor: isDark ? 'bg-green-900/20' : 'bg-green-50',
      iconColor: 'text-green-600'
    },
    {
      title: 'Failed',
      value: stats.failed,
      icon: XCircle,
      color: 'red',
      bgColor: isDark ? 'bg-red-900/20' : 'bg-red-50',
      iconColor: 'text-red-600'
    },
    {
      title: 'Pending',
      value: stats.pending,
      icon: Clock,
      color: 'yellow',
      bgColor: isDark ? 'bg-yellow-900/20' : 'bg-yellow-50',
      iconColor: 'text-yellow-600'
    }
  ]

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      {cards.map((card, index) => {
        const Icon = card.icon
        
        return (
          <motion.div
            key={card.title}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.1 }}
            className={`rounded-xl shadow-sm p-6 transition-all duration-300 ${
              isDark 
                ? 'bg-gray-800 shadow-gray-900/20' 
                : 'bg-white shadow-gray-200/20'
            }`}
          >
            <div className="flex items-center">
              <div className={`p-3 rounded-lg ${card.bgColor} transition-colors duration-300`}>
                <Icon className={`h-6 w-6 ${card.iconColor}`} />
              </div>
              <div className="ml-4">
                <p className={`text-sm font-medium transition-colors duration-300 ${
                  isDark ? 'text-gray-400' : 'text-gray-600'
                }`}>
                  {card.title}
                </p>
                <p className={`text-2xl font-bold transition-colors duration-300 ${
                  isDark ? 'text-white' : 'text-gray-900'
                }`}>
                  {card.value.toLocaleString()}
                </p>
              </div>
            </div>
          </motion.div>
        )
      })}
    </div>
  )
}

export default StatsCards
