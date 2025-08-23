import React, { useState, useRef } from 'react'
import { Upload, FileText, CheckCircle, XCircle, AlertCircle, Download, Heart } from 'lucide-react'
import { motion } from 'framer-motion'

interface CSVUploadProps {
  onContactsUploaded?: (data: any) => void
}

const CSVUpload: React.FC<CSVUploadProps> = ({ onContactsUploaded }) => {
  const [uploading, setUploading] = useState(false)
  const [result, setResult] = useState<any>(null)
  const [error, setError] = useState<string | null>(null)
  const [dragOver, setDragOver] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const handleFileSelect = (file: File | undefined) => {
    if (!file) return
    
    if (!file.name.toLowerCase().endsWith('.csv')) {
      setError('Please select a CSV file')
      return
    }

    uploadFile(file)
  }

  const uploadFile = async (file: File) => {
    setUploading(true)
    setError(null)
    setResult(null)

    const formData = new FormData()
    formData.append('csvFile', file)

    try {
      const response = await fetch('/api/contacts/upload', {
        method: 'POST',
        body: formData,
      })

      const data = await response.json()

      if (response.ok) {
        setResult(data)
        if (onContactsUploaded) {
          onContactsUploaded(data)
        }
      } else {
        setError(data.error || 'Upload failed')
      }
    } catch (err) {
      setError('Failed to upload file. Please check your connection.')
      console.error('Upload error:', err)
    } finally {
      setUploading(false)
    }
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    setDragOver(false)
    
    const files = Array.from(e.dataTransfer.files)
    if (files.length > 0) {
      handleFileSelect(files[0])
    }
  }

  const downloadTemplate = () => {
    const csvContent = 'phone_number,name\n+1234567890,John Doe\n+9876543210,Jane Smith'
    const blob = new Blob([csvContent], { type: 'text/csv' })
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = 'contacts_template.csv'
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
  }

  return (
    <motion.div 
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="bg-white/80 backdrop-blur-sm rounded-xl shadow-lg p-6 card-hover border border-white/20"
    >
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-semibold gradient-text flex items-center">
          <Heart className="w-5 h-5 mr-2 text-pink-500 heart-animation" />
          Upload Contacts
        </h2>
        <button
          onClick={downloadTemplate}
          className="flex items-center text-blue-600 hover:text-blue-700 text-sm transition-colors"
        >
          <Download className="w-4 h-4 mr-1" />
          Download Template
        </button>
      </div>

      {/* Upload Area */}
      <motion.div
        whileHover={{ scale: 1.02 }}
        className={`border-2 border-dashed rounded-xl p-8 text-center transition-all duration-300 ${
          dragOver
            ? 'border-pink-400 bg-pink-50'
            : uploading
            ? 'border-gray-300 bg-gray-50'
            : 'border-gray-300 hover:border-pink-300 hover:bg-pink-50/50'
        }`}
        onDrop={handleDrop}
        onDragOver={(e) => {
          e.preventDefault()
          setDragOver(true)
        }}
        onDragLeave={(e) => {
          e.preventDefault()
          setDragOver(false)
        }}
      >
        {uploading ? (
          <div className="flex flex-col items-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-pink-600 mb-3"></div>
            <p className="text-gray-600">Uploading contacts... ✨</p>
          </div>
        ) : (
          <div className="flex flex-col items-center">
            <Upload className="w-12 h-12 text-pink-400 mb-3" />
            <p className="text-lg font-medium text-gray-700 mb-2">
              Drop your CSV file here, or{' '}
              <button
                onClick={() => fileInputRef.current?.click()}
                className="text-pink-600 hover:text-pink-700 underline"
              >
                browse
              </button>
            </p>
            <p className="text-sm text-gray-500">
              Share your contact list ✨
            </p>
          </div>
        )}
      </motion.div>

      <input
        ref={fileInputRef}
        type="file"
        accept=".csv"
        onChange={(e) => handleFileSelect(e.target.files?.[0])}
        className="hidden"
      />

      {/* Format Info */}
      <div className="mt-4 bg-gradient-to-r from-blue-50 to-pink-50 border border-blue-200 rounded-xl p-4">
        <div className="flex items-start">
          <FileText className="w-5 h-5 text-blue-400 mt-0.5" />
          <div className="ml-3">
            <p className="text-sm font-medium text-blue-700">CSV Format Requirements:</p>
            <ul className="text-sm text-blue-600 mt-1 space-y-1">
              <li>• Include headers: <code className="bg-blue-200 px-1 rounded">phone_number</code> and <code className="bg-blue-200 px-1 rounded">name</code></li>
              <li>• Phone numbers should include country code (e.g., +1234567890)</li>
              <li>• Alternative column names: phone, number, Phone, Number, Name, first_name</li>
              <li>• Maximum file size: 10MB</li>
            </ul>
          </div>
        </div>
      </div>

      {/* Error Message */}
      {error && (
        <motion.div 
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          className="mt-4 bg-red-50 border border-red-200 rounded-xl p-4"
        >
          <div className="flex">
            <XCircle className="w-5 h-5 text-red-400" />
            <div className="ml-3">
              <p className="text-sm text-red-800">{error}</p>
            </div>
          </div>
        </motion.div>
      )}

      {/* Success Result */}
      {result && (
        <motion.div 
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          className="mt-4 bg-gradient-to-r from-green-50 to-blue-50 border border-green-200 rounded-xl p-4"
        >
          <div className="flex">
            <CheckCircle className="w-5 h-5 text-green-400" />
            <div className="ml-3">
              <p className="text-sm text-green-800 font-medium">
                {result.message} 💕
              </p>
              <div className="text-sm text-green-700 mt-2 space-y-1">
                <p>• {result.inserted} contacts added</p>
                {result.skipped > 0 && (
                  <p>• {result.skipped} contacts were already in your contact list</p>
                )}
                {result.errors && result.errors.length > 0 && (
                  <details className="mt-2">
                    <summary className="cursor-pointer text-yellow-700 flex items-center">
                      <AlertCircle className="w-4 h-4 mr-1" />
                      {result.errors.length} minor issues
                    </summary>
                    <ul className="mt-2 ml-5 space-y-1">
                      {result.errors.slice(0, 5).map((error: string, index: number) => (
                        <li key={index} className="text-yellow-600 text-xs">
                          {error}
                        </li>
                      ))}
                      {result.errors.length > 5 && (
                        <li className="text-yellow-600 text-xs">
                          ... and {result.errors.length - 5} more
                        </li>
                      )}
                    </ul>
                  </details>
                )}
              </div>
            </div>
          </div>
        </motion.div>
      )}
    </motion.div>
  )
}

export default CSVUpload
