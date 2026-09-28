import { useState } from 'react'

function App() {

  const [message, setMessage] = useState('')

  const callApi = async () => {

    try {
      const apiBaseUrl =
            import.meta.env.VITE_API_BASE_URL

      const response = await fetch(
            `${apiBaseUrl}/api/hello`
      )
      const data = await response.json()

      setMessage(data.message)

    } catch (error) {

      setMessage('error')

      console.error(error)
    }
  }

  return (
      <div>
        <h1>Azure Container Apps Express Demo</h1>

        <button onClick={callApi}>
          API呼び出し
        </button>

        <p>message: {message}</p>
      </div>
  )
}

export default App