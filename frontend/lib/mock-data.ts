export const mockAccounts = [
  {
    id: '1',
    user_id: 'mock-user',
    name: 'Santander Cuenta Sueldo',
    currency: 'ARS',
    type_code: 'checking',
    institution: 'Banco Santander',
    is_active: true,
    created_at: '2025-01-01T00:00:00Z'
  },
  {
    id: '2',
    user_id: 'mock-user',
    name: 'Ualá',
    currency: 'ARS',
    type_code: 'wallet',
    institution: 'Ualá',
    is_active: true,
    created_at: '2025-01-01T00:00:00Z'
  },
  {
    id: '3',
    user_id: 'mock-user',
    name: 'NaranjaX',
    currency: 'ARS',
    type_code: 'credit_card',
    institution: 'NaranjaX',
    is_active: true,
    created_at: '2025-01-01T00:00:00Z'
  },
  {
    id: '4',
    user_id: 'mock-user',
    name: 'Inviu',
    currency: 'ARS',
    type_code: 'investment',
    institution: 'Inviu',
    is_active: true,
    created_at: '2025-01-01T00:00:00Z'
  }
]

export const mockBalances = [
  { account_id: '1', account_name: 'Santander Cuenta Sueldo', currency: 'ARS', balance: 850000 },
  { account_id: '2', account_name: 'Ualá', currency: 'ARS', balance: 180000 },
  { account_id: '3', account_name: 'NaranjaX', currency: 'ARS', balance: -45000 },
  { account_id: '4', account_name: 'Inviu', currency: 'ARS', balance: 1200000 }
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
  { id: '1', user_id: 'mock-user', name: 'Casa', kind: 'expense' as const, is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '2', user_id: 'mock-user', name: 'Auto', kind: 'expense' as const, is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '3', user_id: 'mock-user', name: 'Casamiento', kind: 'expense' as const, is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '4', user_id: 'mock-user', name: 'Tenis', kind: 'expense' as const, is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '5', user_id: 'mock-user', name: 'Salario', kind: 'income' as const, is_active: true, created_at: '2025-01-01T00:00:00Z' }
]

export const mockCategories = [
  { id: '1', user_id: 'mock-user', group_id: '1', name: 'Alquiler', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '2', user_id: 'mock-user', group_id: '1', name: 'Expensas', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '3', user_id: 'mock-user', group_id: '1', name: 'Luz', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '4', user_id: 'mock-user', group_id: '1', name: 'Super', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '5', user_id: 'mock-user', group_id: '2', name: 'Nafta', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '6', user_id: 'mock-user', group_id: '2', name: 'Seguro', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '7', user_id: 'mock-user', group_id: '3', name: 'Salón', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '8', user_id: 'mock-user', group_id: '3', name: 'Fotografía', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '9', user_id: 'mock-user', group_id: '3', name: 'Catering', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '10', user_id: 'mock-user', group_id: '4', name: 'Clases', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '11', user_id: 'mock-user', group_id: '4', name: 'Equipamiento', is_active: true, created_at: '2025-01-01T00:00:00Z' },
  { id: '12', user_id: 'mock-user', group_id: '5', name: 'Sueldo Mensual', is_active: true, created_at: '2025-01-01T00:00:00Z' }
]

export const mockLedger = [
  { posted_at: '2025-10-14', account_id: '2', delta: -85000, type: 'expense', description: 'Carrefour - compra semanal' },
  { posted_at: '2025-10-13', account_id: '2', delta: -45000, type: 'expense', description: 'YPF - Nafta' },
  { posted_at: '2025-10-11', account_id: '3', delta: -120000, type: 'expense', description: 'Expensas condominio' },
  { posted_at: '2025-10-10', account_id: '2', delta: -28000, type: 'expense', description: 'Club tenis - mensualidad' },
  { posted_at: '2025-10-08', account_id: '2', delta: -92000, type: 'expense', description: 'Día - compra semanal' },
  { posted_at: '2025-10-07', account_id: '3', delta: -380000, type: 'expense', description: 'Salón casamiento - seña' },
  { posted_at: '2025-10-05', account_id: '2', delta: -38000, type: 'expense', description: 'YPF - Nafta' },
  { posted_at: '2025-10-03', account_id: '1', delta: 200000, type: 'transfer', description: 'Transferencia a Ualá' },
  { posted_at: '2025-10-03', account_id: '2', delta: 200000, type: 'transfer', description: 'Transferencia desde Santander' },
  { posted_at: '2025-10-01', account_id: '1', delta: 3000000, type: 'income', description: 'Sueldo Octubre' },
  { posted_at: '2025-10-01', account_id: '1', delta: -650000, type: 'expense', description: 'Alquiler' },
  { posted_at: '2025-10-01', account_id: '1', delta: -75000, type: 'expense', description: 'Edesur - Luz' },
  { posted_at: '2025-09-28', account_id: '2', delta: -90000, type: 'expense', description: 'Carrefour - compra semanal' },
  { posted_at: '2025-09-25', account_id: '2', delta: -42000, type: 'expense', description: 'YPF - Nafta' },
  { posted_at: '2025-09-20', account_id: '2', delta: -85000, type: 'expense', description: 'Día - compra semanal' },
  { posted_at: '2025-09-15', account_id: '3', delta: -95000, type: 'expense', description: 'Seguro auto - cuota mensual' },
  { posted_at: '2025-09-10', account_id: '2', delta: -28000, type: 'expense', description: 'Club tenis - mensualidad' },
  { posted_at: '2025-09-01', account_id: '1', delta: 3000000, type: 'income', description: 'Sueldo Septiembre' },
  { posted_at: '2025-09-01', account_id: '1', delta: -650000, type: 'expense', description: 'Alquiler' }
]

export const mockIncomes = [
  { posted_at: '2025-10-01', account_id: '1', category_id: '12', amount: 3000000, description: 'Sueldo Octubre' },
  { posted_at: '2025-09-01', account_id: '1', category_id: '12', amount: 3000000, description: 'Sueldo Septiembre' },
  { posted_at: '2025-08-01', account_id: '1', category_id: '12', amount: 3000000, description: 'Sueldo Agosto' }
]

export const mockExpenses = [
  { posted_at: '2025-10-14', account_id: '2', category_id: '4', amount: 85000, description: 'Carrefour - compra semanal' },
  { posted_at: '2025-10-13', account_id: '2', category_id: '5', amount: 45000, description: 'YPF - Nafta' },
  { posted_at: '2025-10-11', account_id: '3', category_id: '2', amount: 120000, description: 'Expensas condominio' },
  { posted_at: '2025-10-10', account_id: '2', category_id: '10', amount: 28000, description: 'Club tenis - mensualidad' },
  { posted_at: '2025-10-08', account_id: '2', category_id: '4', amount: 92000, description: 'Día - compra semanal' },
  { posted_at: '2025-10-07', account_id: '3', category_id: '7', amount: 380000, description: 'Salón casamiento - seña' },
  { posted_at: '2025-10-05', account_id: '2', category_id: '5', amount: 38000, description: 'YPF - Nafta' },
  { posted_at: '2025-10-01', account_id: '1', category_id: '1', amount: 650000, description: 'Alquiler' },
  { posted_at: '2025-10-01', account_id: '1', category_id: '3', amount: 75000, description: 'Edesur - Luz' },
  { posted_at: '2025-09-28', account_id: '2', category_id: '4', amount: 90000, description: 'Carrefour - compra semanal' },
  { posted_at: '2025-09-25', account_id: '2', category_id: '5', amount: 42000, description: 'YPF - Nafta' },
  { posted_at: '2025-09-20', account_id: '2', category_id: '4', amount: 85000, description: 'Día - compra semanal' },
  { posted_at: '2025-09-15', account_id: '3', category_id: '6', amount: 95000, description: 'Seguro auto - cuota mensual' },
  { posted_at: '2025-09-10', account_id: '2', category_id: '10', amount: 28000, description: 'Club tenis - mensualidad' },
  { posted_at: '2025-09-01', account_id: '1', category_id: '1', amount: 650000, description: 'Alquiler' }
]

export const mockUser = {
  id: 'mock-user-id',
  email: 'demo@moni.app'
}
