import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { PublicClientApplication } from '@azure/msal-browser'
import { MsalProvider } from '@azure/msal-react'
import './index.css'
import App from './App.tsx'
import { msalConfig } from './authConfig'

const msalInstance = new PublicClientApplication(msalConfig)

await msalInstance.initialize()

const response = await msalInstance.handleRedirectPromise()

if (response?.account) {
    msalInstance.setActiveAccount(response.account)
} else {
    const accounts = msalInstance.getAllAccounts()

    if (accounts.length > 0) {
        msalInstance.setActiveAccount(accounts[0])
    }
}

createRoot(document.getElementById('root')!).render(
    <StrictMode>
        <MsalProvider instance={msalInstance}>
            <App />
        </MsalProvider>
    </StrictMode>,
)
