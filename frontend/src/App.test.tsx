import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

vi.mock('./FortuneManagement', () => ({
    default: () => null
}))
import App from './App'

describe('App', () => {

    it('displays a fortune returned by the API', async () => {
        vi.stubGlobal(
            'fetch',
            vi.fn().mockResolvedValue({
                ok: true,
                status: 200,
                json: async () => ({
                    fortune: 'Deployments should be boring.'
                })
            })
        )
        const user = userEvent.setup()

        render(<App />)

        await user.click(
            screen.getByRole('button', {
                name: 'Get Fortune'
            })
        )

        expect(
            await screen.findByText(
                'Fortune: Deployments should be boring.'
            )
        ).toBeInTheDocument()
    })
    it('displays an error message when the API request fails', async () => {
        vi.stubGlobal(
            'fetch',
            vi.fn().mockResolvedValue({
                ok: false,
                status: 500
            })
        )
        vi.spyOn(console, 'error')
            .mockImplementation(() => undefined)
        const user = userEvent.setup()
        render(<App />)
        await user.click(
            screen.getByRole('button', {
                name: 'Get Fortune'
            })
        )
        expect(
            await screen.findByText(
                'Fortune: Unable to get a fortune.'
            )
        ).toBeInTheDocument()
    })
})
