import {useEffect, useState} from 'react'

type Fortune = {
    id: number
    message: string
}
type FortuneManagementProps = {
    apiBaseUrl: string
}

function FortuneManagement({
                               apiBaseUrl
                           }: FortuneManagementProps) {
    const [fortunes, setFortunes] = useState<Fortune[]>([])
    const [message, setMessage] = useState('')
    const [error, setError] = useState('')
    const loadFortunes = async () => {
        try {
            setError('')
            const response = await fetch(`${apiBaseUrl}/api/admin/fortunes`)
            if (!response.ok) {
                throw new Error(`Failed to load fortunes: ${response.status}`)
            }
            const data: Fortune[] = await response.json()
            setFortunes(data)
        } catch (error) {
            setError('Unable to load fortunes.')
            console.error(error)
        }
    }
    const addFortune = async () => {
        const normalizedMessage = message.trim()
        if (!normalizedMessage) {
            return
        }
        try {
            setError('')
            const response = await fetch(`${apiBaseUrl}/api/admin/fortunes`, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({message: normalizedMessage})
            })
            if (!response.ok) {
                throw new Error(`Failed to add fortune: ${response.status}`)
            }
            const created: Fortune = await response.json()
            setFortunes(current => [...current, created])
            setMessage('')
        } catch (error) {
            setError('Unable to add fortune.')
            console.error(error)
        }
    }
    const deleteFortune = async (id: number) => {
        try {
            setError('')
            const response = await fetch(`${apiBaseUrl}/api/admin/fortunes/${id}`, {
                method: 'DELETE'
            })
            if (!response.ok) {
                throw new Error(`Failed to delete fortune: ${response.status}`)
            }
            setFortunes(
                current => current.filter(
                    fortune => fortune.id !== id
                )
            )
        } catch (error) {
            setError('Unable to delete fortune.')
            console.error(error)
        }
    }
    useEffect(() => {
        void loadFortunes()
    }, [apiBaseUrl])
    return (
        <section>
            <h2>Fortune Management</h2>
            <div>
                <input
                    type="text"
                    value={message}
                    placeholder="Fortune message"
                    aria-label="Fortune message"
                    onChange={event => setMessage(event.target.value)}
                />
                <button
                    type="button"
                    onClick={addFortune}
                    disabled={!message.trim()}
                >
                    Add Fortune
                </button>
            </div>
            {error && (
                <p role="alert">
                    {error}
                </p>
            )}
            <ul>
                {fortunes.map(fortune => (
                    <li key={fortune.id}>
                        <span>
                            {fortune.id}: {fortune.message}
                        </span>{' '}
                        <button
                            type="button"
                            onClick={() => deleteFortune(fortune.id)}
                        >
                            Delete
                        </button>
                    </li>
                ))}
            </ul>
        </section>
    )
}

export default FortuneManagement
