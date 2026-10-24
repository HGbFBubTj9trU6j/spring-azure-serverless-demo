import { useState } from 'react'
import './App.css'
import FortuneManagement from './FortuneManagement'

function App() {

    const [fortune, setFortune] = useState('')

    const buildVersion =
        import.meta.env.VITE_BUILD_VERSION
    // SWA 配置時は build-frontend.ps1 が
    // VITE_API_BASE_URL を注入する。
    // ローカル実行時は Spring Boot の
    // localhost:8080 を使用する。
    const apiBaseUrl =
        import.meta.env.VITE_API_BASE_URL ||
        'http://localhost:8080'

    const callApi = async () => {

        try {

            const response = await fetch(
                `${apiBaseUrl}/api/fortune`
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

            <button onClick={callApi}>
                Get Fortune
            </button>

            <p className="fortune">Fortune: {fortune}</p>
            <hr />

            <FortuneManagement apiBaseUrl={apiBaseUrl} />

            <hr />

            <small>
                Version: {buildVersion}
            </small>

        </div>
    )
}

export default App
