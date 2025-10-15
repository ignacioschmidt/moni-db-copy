import {
  mockAccounts,
  mockBalances,
  mockCurrencies,
  mockAccountTypes,
  mockCategories,
  mockCategoryGroups,
  mockLedger,
  mockIncomes,
  mockExpenses,
  mockUser
} from './mock-data'

const USE_MOCK = true

const mockSupabase = {
  from: (table: string) => ({
    select: (columns = '*') => ({
      eq: (column: string, value: unknown) => ({
        order: (col: string, opts?: { ascending?: boolean }) => ({
          data: getMockData(table),
          error: null
        }),
        limit: (n: number) => ({
          data: getMockData(table).slice(0, n),
          error: null
        }),
        data: getMockData(table),
        error: null
      }),
      order: (col: string, opts?: { ascending?: boolean }) => ({
        data: getMockData(table),
        error: null
      }),
      gte: (col: string, value: unknown) => ({
        lte: (col2: string, value2: unknown) => ({
          data: getMockData(table),
          error: null
        })
      }),
      limit: (n: number) => ({
        data: getMockData(table).slice(0, n),
        error: null
      }),
      data: getMockData(table),
      error: null
    }),
    insert: (data: unknown) => ({
      data: null,
      error: null
    }),
    update: (data: unknown) => ({
      eq: (column: string, value: unknown) => ({
        data: null,
        error: null
      })
    })
  }),
  rpc: (fn: string, params: Record<string, unknown>) => ({
    data: crypto.randomUUID(),
    error: null
  }),
  auth: {
    signInWithPassword: async (credentials: { email: string; password: string }) => ({
      data: { user: mockUser, session: { user: mockUser } },
      error: null
    }),
    signUp: async (credentials: { email: string; password: string }) => ({
      data: { user: mockUser, session: { user: mockUser } },
      error: null
    }),
    signOut: async () => ({
      error: null
    }),
    getSession: async () => ({
      data: { session: { user: mockUser } },
      error: null
    })
  }
}

function getMockData(table: string) {
  switch (table) {
    case 'accounts':
      return mockAccounts
    case 'account_balances_v':
      return mockBalances
    case 'currencies':
      return mockCurrencies
    case 'account_types':
      return mockAccountTypes
    case 'categories':
      return mockCategories
    case 'category_groups':
      return mockCategoryGroups
    case 'account_ledger_v':
      return mockLedger
    case 'incomes_v':
      return mockIncomes
    case 'expenses_v':
      return mockExpenses
    default:
      return []
  }
}

export const supabase = USE_MOCK ? mockSupabase : null as any
