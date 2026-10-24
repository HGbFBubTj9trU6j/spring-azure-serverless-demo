import { afterEach, describe, expect, it, vi } from 'vitest'
import {
    render,
    screen,
    waitFor,
    within
} from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import FortuneManagement from './FortuneManagement'

describe('FortuneManagement', () => {

    afterEach(() => {
        vi.unstubAllGlobals()
        vi.restoreAllMocks()
    })

    it('allows a user to view, add, and delete a fortune', async () => {
        const fetchMock = vi.fn()
            .mockResolvedValueOnce({
                ok: true,
                status: 200,
                json: async () => [
                    {
                        id: 1,
                        message: 'When in doubt, check the logs.'
                    }
                ]
            })
            .mockResolvedValueOnce({
                ok: true,
                status: 201,
                json: async () => ({
                    id: 6,
                    message: 'Ship small, learn fast.'
                })
            })
            .mockResolvedValueOnce({
                ok: true,
                status: 204
            })

        vi.stubGlobal('fetch', fetchMock)

        const user = userEvent.setup()

        render(
            <FortuneManagement
                apiBaseUrl="http://localhost:8080"
            />
        )

        expect(
            await screen.findByText(
                '1: When in doubt, check the logs.'
            )
        ).toBeInTheDocument()

        await user.type(
            screen.getByRole('textbox', {
                name: 'Fortune message'
            }),
            'Ship small, learn fast.'
        )

        await user.click(
            screen.getByRole('button', {
                name: 'Add Fortune'
            })
        )

        const createdFortune =
            await screen.findByText(
                '6: Ship small, learn fast.'
            )

        expect(createdFortune).toBeInTheDocument()

        const createdFortuneItem =
            createdFortune.closest('li')

        expect(createdFortuneItem).not.toBeNull()

        await user.click(
            within(createdFortuneItem!)
                .getByRole('button', {
                    name: 'Delete'
                })
        )

        await waitFor(() => {
            expect(
                screen.queryByText(
                    '6: Ship small, learn fast.'
                )
            ).not.toBeInTheDocument()
        })
    })

    it('displays an error when fortunes cannot be loaded', async () => {
        vi.stubGlobal(
            'fetch',
            vi.fn().mockResolvedValue({
                ok: false,
                status: 500
            })
        )

        vi.spyOn(console, 'error')
            .mockImplementation(() => undefined)

        render(
            <FortuneManagement
                apiBaseUrl="http://localhost:8080"
            />
        )

        expect(
            await screen.findByRole('alert')
        ).toHaveTextContent(
            'Unable to load fortunes.'
        )
    })
})
