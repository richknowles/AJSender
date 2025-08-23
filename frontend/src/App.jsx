import { useState, useEffect } from 'react'

function App() {
  const [backendStatus, setBackendStatus] = useState('checking...')
  const [whatsappStatus, setWhatsappStatus] = useState('checking...')
  const [qrCode, setQrCode] = useState(null)
  const [contacts, setContacts] = useState([])
  const [message, setMessage] = useState('')
  const [isUploading, setIsUploading] = useState(false)
  const [isSending, setIsSending] = useState(false)

  useEffect(() => {
    checkServiceStatus()
    const interval = setInterval(checkServiceStatus, 5000)
    return () => clearInterval(interval)
  }, [])

  const checkServiceStatus = async () => {
    // Check backend
    try {
      const backendRes = await fetch('/api/status')
      setBackendStatus(backendRes.ok ? 'running' : 'error')
    } catch {
      setBackendStatus('offline')
    }

    // Check WhatsApp with detailed status
    try {
      const whatsappRes = await fetch('/whatsapp/health')
      if (whatsappRes.ok) {
        const data = await whatsappRes.json()
        setWhatsappStatus(data.waReady ? 'connected' : 'disconnected')
        
        // Get QR code if not ready
        if (!data.waReady) {
          try {
            const qrRes = await fetch('/whatsapp/qr')
            const qrData = await qrRes.json()
            setQrCode(qrData.qrCode)
          } catch {
            setQrCode(null)
          }
        } else {
          setQrCode(null)
        }
      } else {
        setWhatsappStatus('offline')
      }
    } catch {
      setWhatsappStatus('offline')
    }
  }

  const handleFileUpload = async (event) => {
    const file = event.target.files[0]
    if (!file || !file.name.toLowerCase().endsWith('.csv')) {
      alert('Please select a CSV file')
      return
    }

    setIsUploading(true)
    const formData = new FormData()
    formData.append('csv', file)

    try {
      const response = await fetch('/whatsapp/upload-csv', {
        method: 'POST',
        body: formData
      })

      if (response.ok) {
        const data = await response.json()
        setContacts(data.contacts)
        alert(`SUCCESS: Loaded ${data.count} contacts`)
      } else {
        alert('Upload failed')
      }
    } catch (error) {
      alert('Upload error: ' + error.message)
    } finally {
      setIsUploading(false)
    }
  }

  const handleSendMessages = async () => {
    if (contacts.length === 0) {
      alert('Please upload contacts first')
      return
    }
    if (!message.trim()) {
      alert('Please enter a message')
      return
    }
    if (whatsappStatus !== 'connected') {
      alert('WhatsApp not connected. Scan QR code first.')
      return
    }

    setIsSending(true)

    try {
      const response = await fetch('/whatsapp/send-bulk', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contacts, message })
      })

      if (response.ok) {
        const data = await response.json()
        alert(`MESSAGES SENT! Success: ${data.summary.sent}, Failed: ${data.summary.failed}`)
      } else {
        alert('Send failed')
      }
    } catch (error) {
      alert('Send error: ' + error.message)
    } finally {
      setIsSending(false)
    }
  }

  return (
    <div style={{ 
      padding: '40px', 
      fontFamily: 'Arial, sans-serif',
      maxWidth: '900px',
      margin: '0 auto'
    }}>
      <h1 style={{ textAlign: 'center', color: '#333' }}>
        AJ Sender - WhatsApp Bulk Messaging
      </h1>

      {/* UPDATED STATUS SECTION */}
      <div style={{ 
        background: '#f8f9fa', 
        padding: '20px', 
        borderRadius: '8px',
        marginBottom: '20px'
      }}>
        <h2>System Status</h2>
        <p>Backend: <strong style={{ color: backendStatus === 'running' ? 'green' : 'red' }}>{backendStatus}</strong></p>
        <p>WhatsApp: <strong style={{ color: whatsappStatus === 'connected' ? 'green' : 'orange' }}>{whatsappStatus}</strong></p>
        {contacts.length > 0 && <p>Contacts loaded: <strong>{contacts.length}</strong></p>}
      </div>

      {/* QR CODE SECTION - NEW FEATURE */}
      {qrCode && (
        <div style={{ 
          background: 'white', 
          padding: '20px', 
          border: '2px solid #007bff',
          borderRadius: '8px',
          textAlign: 'center',
          marginBottom: '20px'
        }}>
          <h2>🔗 Connect WhatsApp</h2>
          <p>Scan this QR code with WhatsApp on your phone</p>
          <div>
          <img src={qrCode} alt="WhatsApp QR Code" style={{ maxWidth: '250px' }} />
          <p><small>WhatsApp</small></p>
          <p><small>Settings &gt; Linked Devices &gt; Link a Device</small></p>
          </div>
        </div>
      )}

      {/* CONTACT UPLOAD SECTION - UPDATED */}
      <div style={{ 
        background: 'white', 
        padding: '20px', 
        border: '1px solid #ddd',
        borderRadius: '8px',
        marginBottom: '20px'
      }}>
        <h2>📋 Upload Contact List</h2>
        <p>Upload CSV with format: phone,name</p>
        <input 
          type="file" 
          accept=".csv"
          onChange={handleFileUpload}
          disabled={isUploading}
          style={{ marginBottom: '10px' }}
        />
        {isUploading && <p style={{ color: 'blue' }}>Processing CSV...</p>}
        {contacts.length > 0 && (
          <div style={{ 
            background: '#e8f5e8', 
            padding: '10px', 
            borderRadius: '4px',
            maxHeight: '100px',
            overflowY: 'auto'
          }}>
            <strong>Contacts Preview:</strong>
            {contacts.slice(0, 5).map((c, i) => (
              <div key={i}>{c.phone} {c.name ? `(${c.name})` : ''}</div>
            ))}
            {contacts.length > 5 && <div>... and {contacts.length - 5} more</div>}
          </div>
        )}
      </div>

      {/* MESSAGE COMPOSITION - UPDATED */}
      <div style={{ 
        background: 'white', 
        padding: '20px', 
        border: '1px solid #ddd',
        borderRadius: '8px',
        marginBottom: '20px'
      }}>
        <h2>✉️ Compose Message</h2>
        <textarea 
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="Enter your WhatsApp message..."
          style={{
            width: '100%',
            height: '100px',
            padding: '10px',
            border: '1px solid #ccc',
            borderRadius: '4px'
          }}
        />
        <div style={{ marginTop: '15px', textAlign: 'center' }}>
          <button 
            onClick={handleSendMessages}
            disabled={isSending || whatsappStatus !== 'connected'}
            style={{
              padding: '15px 30px',
              fontSize: '16px',
              backgroundColor: isSending ? '#ccc' : '#28a745',
              color: 'white',
              border: 'none',
              borderRadius: '8px',
              cursor: isSending ? 'not-allowed' : 'pointer'
            }}
          >
            {isSending ? '⏳ SENDING MESSAGES...' : '🚀 SEND BULK MESSAGES'}
          </button>
        </div>
        <p style={{ textAlign: 'center', marginTop: '10px', fontSize: '14px' }}>
          Recipients: {contacts.length} | Characters: {message.length}
        </p>
      </div>

      <div style={{ textAlign: 'center', color: '#666', fontSize: '14px' }}>
        <p>AJ Sender v2.0 - Active WhatsApp Integration</p>
      </div>
    </div>
  )
}

export default App
