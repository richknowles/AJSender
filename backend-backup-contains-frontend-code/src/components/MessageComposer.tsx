
import React from 'react'
import { MessageCircle, Type } from 'lucide-react'
import { useTheme } from '../contexts/ThemeContext'

interface MessageComposerProps {
  message: string
  onChange: (message: string) => void
}

const MessageComposer: React.FC<MessageComposerProps> = ({ message, onChange }) => {
  const { isDark } = useTheme()
  const maxLength = 1000
  const remainingChars = maxLength - message.length

  return (
    <div className={`rounded-xl shadow-sm p-6 transition-all duration-300 ${
      isDark 
        ? 'bg-gray-800 shadow-gray-900/20' 
        : 'bg-white shadow-gray-200/20'
    }`}>
      <div className="flex items-center mb-4">
        <MessageCircle className="h-5 w-5 text-green-600 mr-2" />
        <h2 className={`text-lg font-semibold transition-colors duration-300 ${
          isDark ? 'text-white' : 'text-gray-900'
        }`}>
          Compose Message
        </h2>
      </div>
      
      <div className="space-y-4">
        <div>
          <label className={`block text-sm font-medium mb-2 transition-colors duration-300 ${
            isDark ? 'text-gray-300' : 'text-gray-700'
          }`}>
            Message Content
          </label>
          <textarea
            value={message}
            onChange={(e) => onChange(e.target.value)}
            placeholder="Type your WhatsApp message here..."
            rows={6}
            maxLength={maxLength}
            className={`w-full px-3 py-2 rounded-lg resize-none transition-all duration-300 focus:ring-2 focus:ring-green-500 focus:border-transparent ${
              isDark 
                ? 'bg-gray-700 border-gray-600 text-white placeholder-gray-400' 
                : 'bg-white border-gray-300 text-gray-900 placeholder-gray-500'
            }`}
          />
        </div>
        
        <div className="flex items-center justify-between">
          <div className="flex items-center text-sm">
            <Type className={`h-4 w-4 mr-1 transition-colors duration-300 ${
              isDark ? 'text-gray-400' : 'text-gray-500'
            }`} />
            <span className={`transition-colors duration-300 ${
              isDark ? 'text-gray-400' : 'text-gray-500'
            }`}>
              Character count
            </span>
          </div>
          <span className={`text-sm font-medium transition-colors duration-300 ${
            remainingChars < 50 
              ? 'text-red-500' 
              : remainingChars < 100 
                ? 'text-yellow-500' 
                : 'text-green-500'
          }`}>
            {message.length}/{maxLength}
          </span>
        </div>
        
        {message && (
          <div className={`p-3 rounded-lg border-l-4 border-green-500 transition-all duration-300 ${
            isDark ? 'bg-green-900/20' : 'bg-green-50'
          }`}>
            <p className={`text-sm font-medium mb-1 transition-colors duration-300 ${
              isDark ? 'text-green-300' : 'text-green-800'
            }`}>
              Message Preview:
            </p>
            <p className={`text-sm transition-colors duration-300 ${
              isDark ? 'text-green-200' : 'text-green-700'
            }`}>
              {message}
            </p>
          </div>
        )}
      </div>
    </div>
  )
}

export default MessageComposer
