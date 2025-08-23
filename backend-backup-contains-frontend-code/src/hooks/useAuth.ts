
import { useState, useEffect } from 'react'
import toast from 'react-hot-toast'

interface User {
  id: string
  name: string
  phone: string
  profilePicture?: string
}

interface AuthState {
  isAuthenticated: boolean
  user: User | null
  isLoading: boolean
}

export const useAuth = () => {
  const [authState, setAuthState] = useState<AuthState>({
    isAuthenticated: false,
    user: null,
    isLoading: true
  })

  useEffect(() => {
    // Check for stored authentication
    const storedAuth = localStorage.getItem('aj-sender-auth')
    if (storedAuth) {
      try {
        const parsed = JSON.parse(storedAuth)
        setAuthState({
          isAuthenticated: true,
          user: parsed.user,
          isLoading: false
        })
      } catch (error) {
        localStorage.removeItem('aj-sender-auth')
        setAuthState(prev => ({ ...prev, isLoading: false }))
      }
    } else {
      setAuthState(prev => ({ ...prev, isLoading: false }))
    }
  }, [])

  const loginWithWhatsApp = async () => {
    try {
      setAuthState(prev => ({ ...prev, isLoading: true }))
      
      // Simulate WhatsApp Web authentication
      await new Promise(resolve => setTimeout(resolve, 2000))
      
      // Simulate successful authentication
      const mockUser: User = {
        id: 'user_' + Date.now(),
        name: 'AJ Ricardo',
        phone: '+1234567890',
        profilePicture: 'https://ai-lumi-prd.oss-us-east-1.aliyuncs.com/62/62ab365aa10617a22711d82b9f4a6513.webp'
      }

      const authData = {
        user: mockUser,
        timestamp: Date.now()
      }

      localStorage.setItem('aj-sender-auth', JSON.stringify(authData))
      
      setAuthState({
        isAuthenticated: true,
        user: mockUser,
        isLoading: false
      })

      toast.success('Successfully connected to WhatsApp!')
    } catch (error) {
      console.error('WhatsApp login failed:', error)
      toast.error('Failed to connect to WhatsApp. Please try again.')
      setAuthState(prev => ({ ...prev, isLoading: false }))
    }
  }

  const logout = () => {
    localStorage.removeItem('aj-sender-auth')
    setAuthState({
      isAuthenticated: false,
      user: null,
      isLoading: false
    })
    toast.success('Disconnected from WhatsApp')
  }

  return {
    ...authState,
    loginWithWhatsApp,
    logout
  }
}
