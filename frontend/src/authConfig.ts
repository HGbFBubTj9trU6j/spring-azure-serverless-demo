import type { Configuration } from '@azure/msal-browser'

export const msalConfig: Configuration = {
    auth: {
        clientId: import.meta.env.VITE_ENTRA_CLIENT_ID,
        authority: `https://login.microsoftonline.com/${import.meta.env.VITE_ENTRA_TENANT_ID}`,
        redirectUri: window.location.origin,
    },
}

export const apiScopes = [
    import.meta.env.VITE_API_SCOPE,
]
