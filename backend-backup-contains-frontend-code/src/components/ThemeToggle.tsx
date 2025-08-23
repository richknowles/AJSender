
import React from 'react'
import { Sun, Moon } from 'lucide-react'
import { motion } from 'framer-motion'
import { useTheme } from '../contexts/ThemeContext'

const ThemeToggle: React.FC = () => {
  const { theme, toggleTheme, isDark } = useTheme()

  return (
    <motion.button
      onClick={toggleTheme}
      className={`
        relative p-2 rounded-lg transition-all duration-300 ease-in-out
        ${isDark 
          ? 'bg-gray-700 hover:bg-gray-600 text-yellow-400' 
          : 'bg-gray-100 hover:bg-gray-200 text-gray-700'
        }
        focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2
        ${isDark ? 'focus:ring-offset-gray-800' : 'focus:ring-offset-white'}
      `}
      whileHover={{ scale: 1.05 }}
      whileTap={{ scale: 0.95 }}
      title={`Switch to ${isDark ? 'light' : 'dark'} mode`}
    >
      <motion.div
        initial={false}
        animate={{ 
          rotate: isDark ? 180 : 0,
          scale: isDark ? 0.8 : 1 
        }}
        transition={{ 
          type: "spring", 
          stiffness: 200, 
          damping: 20 
        }}
      >
        {isDark ? (
          <Sun className="h-5 w-5" />
        ) : (
          <Moon className="h-5 w-5" />
        )}
      </motion.div>
      
      {/* Subtle glow effect */}
      <motion.div
        className={`
          absolute inset-0 rounded-lg opacity-0 transition-opacity duration-300
          ${isDark 
            ? 'bg-yellow-400 shadow-yellow-400/20' 
            : 'bg-blue-500 shadow-blue-500/20'
          }
        `}
        animate={{ opacity: isDark ? 0.1 : 0 }}
      />
    </motion.button>
  )
}

export default ThemeToggle
