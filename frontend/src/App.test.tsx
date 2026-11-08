import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

function createTestAccessToken(roles?: string[]) {
    const header = {
        alg: 'none',
        typ: 'JWT',
    }

    const payload = roles
        ? { roles }
        : {}

    const encode = (value: object) =>
        btoa(JSON.stringify(value))
            .replace(/\+/g, '-')
            .replace(/\//g, '_')
            .replace(/=+$/, '')

    return `${encode(header)}.${encode(payload)}.test-signature`
}

const mockAccount = {
    homeAccountId: 'test-home-account-id',
    environment: 'login.microsoftonline.com',
    tenantId: 'test-tenant-id',
    username: 'test@example.com',
    localAccountId: 'test-local-account-id',
    idTokenClaims: {
        roles: [] as string[],
    },
}

let accessToken = createTestAccessToken()

const acquireTokenSilent = vi.fn(
    async () => ({
        accessToken,
    })
)

vi.mock('@azure/msal-react', () => ({
    useMsal: () => ({
        instance: {
            getActiveAccount: () => mockAccount,
            acquireTokenSilent,
            loginRedirect: vi.fn(),
            logoutRedirect: vi.fn(),
            acquireTokenRedirect: vi.fn(),
        },
        accounts: [mockAccount],
    }),
}))

vi.mock('./FortuneManagement', () => ({
    default: () => (
        <div>Fortune Management</div>
    )
}))
import App from './App'

describe('App', () => {

    it('displays a fortune returned by the API', async () => {
        const fetchMock = vi.fn().mockResolvedValue({
            ok: true,
            status: 200,
            json: async () => ({
                fortune: 'Deployments should be boring.'
            })
        })

        vi.stubGlobal('fetch', fetchMock)

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

        expect(fetchMock).toHaveBeenCalledWith(
            'http://localhost:8080/api/fortune',
            {
                headers: {
                    Authorization: `Bearer ${accessToken}`,
                },
            }
        )
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

    it('displays Fortune Management for a Fortune.Admin user', async () => {
        accessToken = createTestAccessToken([
            'Fortune.Admin',
        ])

        render(<App />)

        expect(
            await screen.findByText(
                'Fortune Management'
            )
        ).toBeInTheDocument()
    })

    it('does not display Fortune Management for a non-admin user', async () => {
        accessToken = createTestAccessToken()

        render(<App />)

        await vi.waitFor(() => {
            expect(
                acquireTokenSilent
            ).toHaveBeenCalled()
        })

        expect(
            screen.queryByText(
                'Fortune Management'
            )
        ).not.toBeInTheDocument()
    })
})
