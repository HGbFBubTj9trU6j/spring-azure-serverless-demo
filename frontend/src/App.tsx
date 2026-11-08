import { useEffect, useState } from 'react'
import './App.css'
import FortuneManagement from './FortuneManagement'
import { useMsal } from '@azure/msal-react'
import { InteractionRequiredAuthError } from '@azure/msal-browser'
import { apiScopes } from './authConfig'

type AccessTokenClaims = {
    roles?: string[]
}

function parseAccessTokenClaims(
    accessToken: string
): AccessTokenClaims {
    const payload = accessToken.split('.')[1]

    if (!payload) {
        return {}
    }

    const base64 = payload
        .replace(/-/g, '+')
        .replace(/_/g, '/')

    const paddedBase64 =
        base64 + '='.repeat((4 - base64.length % 4) % 4)

    return JSON.parse(
        atob(paddedBase64)
    ) as AccessTokenClaims
}

function App() {

    const { instance, accounts } = useMsal()

    const signIn = async () => {
        await instance.loginRedirect({
            scopes: apiScopes,
        })
    }

    const account =
        instance.getActiveAccount() ?? accounts[0]

    const [isFortuneAdmin, setIsFortuneAdmin] = useState(false)

    const signOut = async () => {
        await instance.logoutRedirect({
            account,
            postLogoutRedirectUri: window.location.origin,
        })
    }

    const getAccessToken = async () => {
        if (!account) {
            throw new Error('User is not signed in.')
        }

        try {
            const response = await instance.acquireTokenSilent({
                scopes: apiScopes,
                account,
            })

            return response.accessToken
        } catch (error) {
            if (error instanceof InteractionRequiredAuthError) {
                await instance.acquireTokenRedirect({
                    scopes: apiScopes,
                    account,
                })

                return undefined
            }

            throw error
        }
    }

    useEffect(() => {
        if (!account) {
            setIsFortuneAdmin(false)
            return
        }

        const loadAuthorization = async () => {
            try {
                const accessToken = await getAccessToken()

                if (!accessToken) {
                    setIsFortuneAdmin(false)
                    return
                }

                const claims =
                    parseAccessTokenClaims(accessToken)

                setIsFortuneAdmin(
                    claims.roles?.includes(
                        'Fortune.Admin'
                    ) ?? false
                )
            } catch (error) {
                console.error(
                    'Failed to determine authorization.',
                    error
                )

                setIsFortuneAdmin(false)
            }
        }

        void loadAuthorization()
    }, [account])

    const [fortune, setFortune] = useState('')

    const buildVersion =
        import.meta.env.VITE_BUILD_VERSION || 'unknown'
    // SWA 配置時は build-frontend.ps1 が
    // VITE_API_BASE_URL を注入する。
    // ローカル実行時は Spring Boot の
    // localhost:8080 を使用する。
    const apiBaseUrl =
        import.meta.env.VITE_API_BASE_URL ||
        'http://localhost:8080'

    const callApi = async () => {

        try {

            const accessToken = await getAccessToken()
            if (!accessToken) {
                return
            }

            const response = await fetch(
                `${apiBaseUrl}/api/fortune`,
                {
                    headers: {
                        Authorization: `Bearer ${accessToken}`,
                    },
                }
            )

            if (!response.ok) {
                throw new Error(`Failed to get fortune: ${response.status}`)
            }

            const data = await response.json()

            setFortune(data.fortune)

        } catch (error) {

            setFortune('Unable to get a fortune.')

            console.error(error)
        }
    }

    return (
        <div>
            <h1>Azure Container Apps Express Demo</h1>
            {account ? (
                <>
                    <p>Signed in as: {account.username}</p>
                    <button onClick={signOut}>
                        Sign out
                    </button>
                </>
            ) : (
                <button onClick={signIn}>
                    Sign in
                </button>
            )}
            <button onClick={callApi}>
                Get Fortune
            </button>

            <p className="fortune">Fortune: {fortune}</p>
            <hr />

            {isFortuneAdmin && (
                <FortuneManagement
                    apiBaseUrl={apiBaseUrl}
                    getAccessToken={getAccessToken}
                />
            )}

            <hr />

            <small>
                Version: {buildVersion}
            </small>

        </div>
    )
}

export default App
