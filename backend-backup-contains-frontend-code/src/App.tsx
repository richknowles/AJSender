
import React from 'react'
import { Toaster } from 'react-hot-toast'
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom'
import { ThemeProvider } from './contexts/ThemeContext'
import { useAuth } from './hooks/useAuth'
import Dashboard from './pages/Dashboard'
import BatchHistory from './pages/BatchHistory'
import Layout from './components/Layout'
import WhatsAppLogin from './components/WhatsAppLogin'

function AppContent() {
  const { isAuthenticated, isLoading, loginWithWhatsApp } = useAuth()

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-green-600"></div>
      </div>
    )
  }

  if (!isAuthenticated) {
    return <WhatsAppLogin onLogin={loginWithWhatsApp} isLoading={isLoading} />
  }

  return (
    <Router>
      <Layout>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/history" element={<BatchHistory />} />
        </Routes>
      </Layout>
    </Router>
  )
}

function App() {
  return (
    <ThemeProvider>
      <Toaster 
        position="top-right"
        toastOptions={{
          duration: 5000,
          style: { 
            background: 'var(--toast-bg)',
            color: 'var(--toast-color)',
            borderRadius: '10px',
            padding: '16px'
          },
          success: { 
            style: { background: '#10b981' },
            iconTheme: { primary: '#fff', secondary: '#10b981' }
          },
          error: { 
            style: { background: '#ef4444' },
            iconTheme: { primary: '#fff', secondary: '#ef4444' }
          }
        }}
      />
      
      <AppContent />
      
      <style>{`
        :root {
          --toast-bg: #363636;
          --toast-color: #fff;
        }
        
        .dark {
          --toast-bg: #1f2937;
          --toast-color: #f9fafb;
        }
        
        .light {
          --toast-bg: #363636;
          --toast-color: #fff;
        }
      `}</style>
    </ThemeProvider>
  )
}

export default App
