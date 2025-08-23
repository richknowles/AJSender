
import React, { useRef, useState } from 'react'
import { Upload, FileText, CheckCircle, AlertCircle } from 'lucide-react'
import { motion } from 'framer-motion'
import toast from 'react-hot-toast'
import { useTheme } from '../contexts/ThemeContext'

interface CSVUploaderProps {
  onUpload: (phoneNumbers: string[]) => void
}

const CSVUploader: React.FC<CSVUploaderProps> = ({ onUpload }) => {
  const { isDark } = useTheme()
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [isDragging, setIsDragging] = useState(false)
  const [uploadedFile, setUploadedFile] = useState<string | null>(null)

  const validatePhoneNumber = (phone: string): boolean => {
    const cleaned = phone.replace(/\D/g, '')
    return cleaned.length >= 10 && cleaned.length <= 15
  }

  const parseCSV = (text: string): string[] => {
    const lines = text.split('\n')
    const phoneNumbers: string[] = []
    
    lines.forEach((line, index) => {
      const trimmed = line.trim()
      if (trimmed) {
        const values = trimmed.split(',')
        values.forEach(value => {
          const phone = value.trim().replace(/['"]/g, '')
          if (phone && validatePhoneNumber(phone)) {
            phoneNumbers.push(phone)
          }
        })
      }
    })
    
    return [...new Set(phoneNumbers)] // Remove duplicates
  }

  const handleFileUpload = (file: File) => {
    if (!file.name.endsWith('.csv')) {
      toast.error('Please upload a CSV file')
      return
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const text = e.target?.result as string
        const phoneNumbers = parseCSV(text)
        
        if (phoneNumbers.length === 0) {
          toast.error('No valid phone numbers found in the CSV file')
          return
        }
        
        setUploadedFile(file.name)
        onUpload(phoneNumbers)
        toast.success(`Successfully loaded ${phoneNumbers.length} phone numbers`)
      } catch (error) {
        toast.error('Error parsing CSV file')
      }
    }
    reader.readAsText(file)
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(false)
    
    const files = Array.from(e.dataTransfer.files)
    if (files.length > 0) {
      handleFileUpload(files[0])
    }
  }

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files
    if (files && files.length > 0) {
      handleFileUpload(files[0])
    }
  }

  return (
    <div className={`rounded-xl shadow-sm p-6 transition-all duration-300 ${
      isDark 
        ? 'bg-gray-800 shadow-gray-900/20' 
        : 'bg-white shadow-gray-200/20'
    }`}>
      <div className="flex items-center mb-4">
        <Upload className="h-5 w-5 text-blue-600 mr-2" />
        <h2 className={`text-lg font-semibold transition-colors duration-300 ${
          isDark ? 'text-white' : 'text-gray-900'
        }`}>
          Upload Phone Numbers
        </h2>
      </div>
      
      <motion.div
        className={`border-2 border-dashed rounded-lg p-8 text-center transition-all duration-300 ${
          isDragging
            ? isDark
              ? 'border-blue-400 bg-blue-900/20'
              : 'border-blue-400 bg-blue-50'
            : isDark
              ? 'border-gray-600 hover:border-gray-500'
              : 'border-gray-300 hover:border-gray-400'
        }`}
        onDrop={handleDrop}
        onDragOver={(e) => {
          e.preventDefault()
          setIsDragging(true)
        }}
        onDragLeave={() => setIsDragging(false)}
        whileHover={{ scale: 1.01 }}
        whileTap={{ scale: 0.99 }}
      >
        <input
          ref={fileInputRef}
          type="file"
          accept=".csv"
          onChange={handleFileSelect}
          className="hidden"
        />
        
        {uploadedFile ? (
          <div className="space-y-3">
            <CheckCircle className="h-12 w-12 text-green-500 mx-auto" />
            <div>
              <p className={`font-medium transition-colors duration-300 ${
                isDark ? 'text-green-300' : 'text-green-600'
              }`}>
                File uploaded successfully!
              </p>
              <p className={`text-sm transition-colors duration-300 ${
                isDark ? 'text-gray-400' : 'text-gray-500'
              }`}>
                {uploadedFile}
              </p>
            </div>
          </div>
        ) : (
          <div className="space-y-3">
            <FileText className={`h-12 w-12 mx-auto transition-colors duration-300 ${
              isDragging 
                ? 'text-blue-500' 
                : isDark 
                  ? 'text-gray-400' 
                  : 'text-gray-400'
            }`} />
            <div>
              <p className={`font-medium transition-colors duration-300 ${
                isDark ? 'text-white' : 'text-gray-900'
              }`}>
                Drop your CSV file here, or{' '}
                <button
                  onClick={() => fileInputRef.current?.click()}
                  className="text-blue-600 hover:text-blue-700 underline"
                >
                  browse
                </button>
              </p>
              <p className={`text-sm mt-1 transition-colors duration-300 ${
                isDark ? 'text-gray-400' : 'text-gray-500'
              }`}>
                CSV files with phone numbers only
              </p>
            </div>
          </div>
        )}
      </motion.div>
      
      <div className={`mt-4 p-3 rounded-lg transition-all duration-300 ${
        isDark ? 'bg-blue-900/20' : 'bg-blue-50'
      }`}>
        <div className="flex items-start">
          <AlertCircle className={`h-4 w-4 mt-0.5 mr-2 flex-shrink-0 transition-colors duration-300 ${
            isDark ? 'text-blue-300' : 'text-blue-600'
          }`} />
          <div className="text-sm">
            <p className={`font-medium transition-colors duration-300 ${
              isDark ? 'text-blue-300' : 'text-blue-800'
            }`}>
              CSV Format Requirements:
            </p>
            <ul className={`mt-1 space-y-1 transition-colors duration-300 ${
              isDark ? 'text-blue-200' : 'text-blue-700'
            }`}>
              <li>• One phone number per line or comma-separated</li>
              <li>• Include country code (e.g., +1234567890)</li>
              <li>• Numbers should be 10-15 digits long</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}

export default CSVUploader
