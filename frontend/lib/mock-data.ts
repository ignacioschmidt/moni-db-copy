export const mockAccounts = [
  {
    id: '1',
    user_id: 'mock-user',
    name: 'Cuenta Corriente',
    currency: 'ARS',
    type_code: 'checking',
    institution: 'Banco Galicia',
    is_active: true,
    created_at: '2025-01-01T00:00:00Z'
  },
  {
    id: '2',
    user_id: 'mock-user',
    name: 'Cuenta USD',
    currency: 'USD',
    type_code: 'savings',
    institution: 'Banco Galicia',
    is_active: true,
    created_at: '2025-01-01T00:00:00Z'
  },
  {
    id: '3',
    user_id: 'mock-user',
    name: 'Mercado Pago',
    currency: 'ARS',
    type_code: 'wallet',
    institution: 'Mercado Pago',
    is_active: true,
    created_at: '2025-01-01T00:00:00Z'
  }
]

export const mockBalances = [
  { account_id: '1', account_name: 'Cuenta Corriente', currency: 'ARS', balance: 150000 },
  { account_id: '2', account_name: 'Cuenta USD', currency: 'USD', balance: 500 },
  { account_id: '3', account_name: 'Mercado Pago', currency: 'ARS', balance: 25000 }
]

export const mockCurrencies = [
  { code: 'ARS', name: 'Peso Argentino', symbol: '$' },
  { code: 'USD', name: 'Dólar Estadounidense', symbol: 'US$' },
  { code: 'EUR', name: 'Euro', symbol: '€' },
  { code: 'BRL', name: 'Real Brasileño', symbol: 'R$' },
  { code: 'MXN', name: 'Peso Mexicano', symbol: 'MX$' }
]

export const mockAccountTypes = [
  { type_code: 'checking', name: 'Cuenta Corriente', kind: 'asset' as const },
  { type_code: 'savings', name: 'Caja de Ahorro', kind: 'asset' as const },
  { type_code: 'credit_card', name: 'Tarjeta de Crédito', kind: 'liability' as const },
  { type_code: 'wallet', name: 'Billetera Digital', kind: 'asset' as const },
  { type_code: 'investment', name: 'Inversión', kind: 'asset' as const }
]

export const mockCategoryGroups = [
  { id: '1', user_id: 'mock-user', name: 'Alimentación', kind: 'expense' as const, is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '2', user_id: 'mock-user', name: 'Transporte', kind: 'expense' as const, is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '3', user_id: 'mock-user', name: 'Vivienda', kind: 'expense' as const, is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '4', user_id: 'mock-user', name: 'Salario', kind: 'income' as const, is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '5', user_id: 'mock-user', name: 'Freelance', kind: 'income' as const, is_active: true, created_at: '2025-01-01T00:00:00Z' }
]

export const mockCategories = [
  { id: '1', user_id: 'mock-user', group_id: '1', name: 'Supermercado', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '2', user_id: 'mock-user', group_id: '1', name: 'Restaurantes', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '3', user_id: 'mock-user', group_id: '2', name: 'Combustible', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '4', user_id: 'mock-user', group_id: '2', name: 'Transporte Público', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '5', user_id: 'mock-user', group_id: '3', name: 'Alquiler', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '6', user_id: 'mock-user', group_id: '3', name: 'Servicios', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '7', user_id: 'mock-user', group_id: '4', name: 'Sueldo', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '8', user_id: 'mock-user', group_id: '5', name: 'Proyectos', is_active: true, created_at: '2025-01-01T00:00:00Z' }
]

export const mockLedger = [
  { posted_at: '2025-10-14', account_id: '1', delta: -15000, type: 'expense', description: 'Supermercado Coto' },
  { posted_at: '2025-10-13', account_id: '1', delta: 200000, type: 'income', description: 'Sueldo Octubre' },
  { posted_at: '2025-10-12', account_id: '3', delta: -3500, type: 'expense', description: 'Uber' },
  { posted_at: '2025-10-11', account_id: '1', delta: -80000, type: 'expense', description: 'Alquiler' },
  { posted_at: '2025-10-10', account_id: '2', delta: 100, type: 'income', description: 'Freelance proyecto web' },
  { posted_at: '2025-10-09', account_id: '3', delta: 10000, type: 'transfer', description: 'Transferencia desde banco' },
  { posted_at: '2025-10-08', account_id: '1', delta: -5000, type: 'expense', description: 'Combustible' },
  { posted_at: '2025-10-07', account_id: '1', delta: -12000, type: 'expense', description: 'Restaurant' }
]

export const mockIncomes = [
  { posted_at: '2025-10-13', account_id: '1', category_id: '7', amount: 200000, description: 'Sueldo Octubre' },
  { posted_at: '2025-10-10', account_id: '2', category_id: '8', amount: 100, description: 'Freelance proyecto web' },
  { posted_at: '2025-09-13', account_id: '1', category_id: '7', amount: 200000, description: 'Sueldo Septiembre' }
]

export const mockExpenses = [
  { posted_at: '2025-10-14', account_id: '1', category_id: '1', amount: 15000, description: 'Supermercado Coto' },
  { posted_at: '2025-10-12', account_id: '3', category_id: '4', amount: 3500, description: 'Uber' },
  { posted_at: '2025-10-11', account_id: '1', category_id: '5', amount: 80000, description: 'Alquiler' },
  { posted_at: '2025-10-08', account_id: '1', category_id: '3', amount: 5000, description: 'Combustible' },
  { posted_at: '2025-10-07', account_id: '1', category_id: '2', amount: 12000, description: 'Restaurant' }
]

export const mockUser = {
  id: 'mock-user-id',
  email: 'demo@moni.app'
}
