
import React from 'react'
import { Link, useLocation } from 'react-router-dom'
import { Send, History, LogOut, User } from 'lucide-react'
import { useTheme } from '../contexts/ThemeContext'
import { useAuth } from '../hooks/useAuth'
import ThemeToggle from './ThemeToggle'

interface LayoutProps {
  children: React.ReactNode
}

const Layout: React.FC<LayoutProps> = ({ children }) => {
  const location = useLocation()
  const { isDark } = useTheme()
  const { user, logout } = useAuth()

  const navItems = [
    { path: '/', label: 'Dashboard', icon: Send },
    { path: '/history', label: 'History', icon: History }
  ]

  return (
    <div className={`min-h-screen transition-colors duration-300 ${
      isDark ? 'bg-gray-900' : 'bg-gray-50'
    }`}>
      {/* Header */}
      <header className={`shadow-sm border-b transition-colors duration-300 ${
        isDark 
          ? 'bg-gray-800 border-gray-700' 
          : 'bg-white border-gray-200'
      }`}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              {/* Custom AJ Sender Logo */}
              <div className={`relative p-2 rounded-xl transition-all duration-300 ${
                isDark 
                  ? 'bg-gradient-to-br from-green-500 to-green-600 shadow-green-500/20' 
                  : 'bg-gradient-to-br from-green-500 to-green-600 shadow-green-500/30'
              } shadow-lg`}>
                <div className="relative w-6 h-6">
                  {/* A Letter */}
                  <div className="absolute inset-0 flex items-center justify-center">
                    <svg width="24" height="24" viewBox="0 0 32 32" className="text-white">
                      <path 
                        d="M8 24L12 12L16 24M10 20H14M20 12V24M20 12C20 10.9 20.9 10 22 10S24 10.9 24 12V24" 
                        stroke="currentColor" 
                        strokeWidth="2.5" 
                        fill="none" 
                        strokeLinecap="round" 
                        strokeLinejoin="round"
                      />
                    </svg>
                  </div>
                  
                  {/* Message bubble accent */}
                  <div className="absolute -top-0.5 -right-0.5 w-2 h-2 bg-white rounded-full opacity-90">
                    <div className="w-full h-full bg-green-400 rounded-full animate-pulse"></div>
                  </div>
                </div>
              </div>
              
              <h1 className={`ml-3 text-xl font-bold transition-colors duration-300 ${
                isDark ? 'text-white' : 'text-gray-900'
              }`}>
                AJ Sender
              </h1>
            </div>
            
            <div className="flex items-center space-x-4">
              {/* User Profile */}
              {user && (
                <div className="flex items-center space-x-3">
                  <div className="flex items-center space-x-2">
                    {user.profilePicture ? (
                      <img 
                        src={user.profilePicture} 
                        alt={user.name}
                        className="h-8 w-8 rounded-full"
                      />
                    ) : (
                      <div className={`h-8 w-8 rounded-full flex items-center justify-center transition-colors duration-300 ${
                        isDark ? 'bg-gray-700' : 'bg-gray-200'
                      }`}>
                        <User className="h-4 w-4" />
                      </div>
                    )}
                    <div className="hidden sm:block">
                      <p className={`text-sm font-medium transition-colors duration-300 ${
                        isDark ? 'text-white' : 'text-gray-900'
                      }`}>
                        {user.name}
                      </p>
                      <p className={`text-xs transition-colors duration-300 ${
                        isDark ? 'text-gray-400' : 'text-gray-500'
                      }`}>
                        {user.phone}
                      </p>
                    </div>
                  </div>
                  
                  <button
                    onClick={logout}
                    className={`p-2 rounded-lg transition-all duration-300 ${
                      isDark 
                        ? 'text-gray-400 hover:text-gray-200 hover:bg-gray-700' 
                        : 'text-gray-500 hover:text-gray-700 hover:bg-gray-100'
                    }`}
                    title="Disconnect WhatsApp"
                  >
                    <LogOut className="h-4 w-4" />
                  </button>
                </div>
              )}
              
              <ThemeToggle />
            </div>
          </div>
        </div>
      </header>

      {/* Navigation */}
      <nav className={`shadow-sm transition-colors duration-300 ${
        isDark ? 'bg-gray-800' : 'bg-white'
      }`}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex space-x-8">
            {navItems.map((item) => {
              const Icon = item.icon
              const isActive = location.pathname === item.path
              
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  className={`flex items-center py-4 px-1 border-b-2 font-medium text-sm transition-all duration-300 ${
                    isActive
                      ? 'border-green-500 text-green-600'
                      : `border-transparent transition-colors duration-300 ${
                          isDark 
                            ? 'text-gray-400 hover:text-gray-200 hover:border-gray-600' 
                            : 'text-gray-500 hover:text-gray-700 hover:border-gray-300'
                        }`
                  }`}
                >
                  <Icon className="h-4 w-4 mr-2" />
                  {item.label}
                </Link>
              )
            })}
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
        {children}
      </main>

      {/* Footer */}
      <footer className={`border-t mt-12 transition-colors duration-300 ${
        isDark ? 'border-gray-700 bg-gray-800' : 'border-gray-200 bg-white'
      }`}>
        <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col sm:flex-row justify-between items-center">
            <div className="flex items-center space-x-3 mb-4 sm:mb-0">
              {/* Custom AJ Sender Logo */}
              <div className={`relative p-1.5 rounded-lg transition-all duration-300 ${
                isDark 
                  ? 'bg-gradient-to-br from-green-500 to-green-600' 
                  : 'bg-gradient-to-br from-green-500 to-green-600'
              }`}>
                <div className="relative w-4 h-4">
                  <div className="absolute inset-0 flex items-center justify-center">
                    <svg width="16" height="16" viewBox="0 0 32 32" className="text-white">
                      <path 
                        d="M8 24L12 12L16 24M10 20H14M20 12V24M20 12C20 10.9 20.9 10 22 10S24 10.9 24 12V24" 
                        stroke="currentColor" 
                        strokeWidth="3" 
                        fill="none" 
                        strokeLinecap="round" 
                        strokeLinejoin="round"
                      />
                    </svg>
                  </div>
                </div>
              </div>
              
              <span className={`font-semibold transition-colors duration-300 ${
                isDark ? 'text-white' : 'text-gray-900'
              }`}>
                AJ Sender
              </span>
            </div>
            
            <p className={`text-sm transition-colors duration-300 ${
              isDark ? 'text-gray-400' : 'text-gray-600'
            }`}>
              © 2025 AJ Ricardo Inc. •{' '}
              <a 
                href="https://ajricardo.com" 
                target="_blank" 
                rel="noopener noreferrer"
                className="text-green-600 hover:text-green-700 transition-colors duration-300"
              >
                ajricardo.com
              </a>
            </p>
          </div>
        </div>
      </footer>
    </div>
  )
}

export default Layout
