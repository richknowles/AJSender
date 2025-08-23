import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'

const root = document.getElementById('root')
if (root) {
  ReactDOM.createRoot(root).render(React.createElement(App))
} else {
  console.error('Root element not found!')
}
