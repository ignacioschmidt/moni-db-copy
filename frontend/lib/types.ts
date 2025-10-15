export interface Account {
  id: string
  user_id: string
  name: string
  currency: string
  type_code: string
  institution?: string
  is_active: boolean
  created_at: string
}

export interface Category {
  id: string
  user_id: string
  group_id: string
  name: string
  is_active: boolean
  created_at: string
}

export interface CategoryGroup {
  id: string
  user_id: string
  name: string
  kind: 'expense' | 'income'
  is_active: boolean
  created_at: string
}

export interface Transaction {
  id: string
  user_id: string
  type: 'expense' | 'income' | 'transfer' | 'adjustment'
  posted_at: string
  amount: number
  amount_counter?: number
  description?: string
  counterparty?: string
  status: 'cleared' | 'pending'
  created_at: string
}

export interface AccountBalance {
  account_id: string
  account_name: string
  currency: string
  balance: number
}

export interface AccountLedger {
  posted_at: string
  account_id: string
  delta: number
  type: string
  description?: string
}

export interface Currency {
  code: string
  name: string
  symbol: string
}

export interface AccountType {
  type_code: string
  name: string
  kind: 'asset' | 'liability'
}
