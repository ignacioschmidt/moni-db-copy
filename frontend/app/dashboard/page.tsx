'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { DashboardLayout } from '@/components/dashboard-layout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { AccountBalance } from '@/lib/types'
import { Wallet, DollarSign } from 'lucide-react'

export default function DashboardPage() {
  const [balances, setBalances] = useState<AccountBalance[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadBalances()
  }, [])

  const loadBalances = async () => {
    const { data, error } = await supabase
      .from('account_balances_v')
      .select('*')
      .order('account_name')

    if (!error && data) {
      setBalances(data)
    }
    setLoading(false)
  }

  const totalByCurrency = balances.reduce((acc, balance) => {
    const currency = balance.currency
    if (!acc[currency]) {
      acc[currency] = 0
    }
    acc[currency] += Number(balance.balance)
    return acc
  }, {} as Record<string, number>)

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Resumen</h1>
          <p className="text-slate-600 dark:text-slate-400 mt-1">
            Vista general de tus finanzas
          </p>
        </div>

        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">
                Total de Cuentas
              </CardTitle>
              <Wallet className="h-4 w-4 text-slate-600" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{balances.length}</div>
            </CardContent>
          </Card>

          {Object.entries(totalByCurrency).map(([currency, total]) => (
            <Card key={currency}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">
                  Total en {currency}
                </CardTitle>
                <DollarSign className="h-4 w-4 text-slate-600" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {new Intl.NumberFormat('es-AR', {
                    style: 'currency',
                    currency: currency,
                  }).format(total)}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Cuentas</CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="text-center py-8 text-slate-600">Cargando...</div>
            ) : balances.length === 0 ? (
              <div className="text-center py-8 text-slate-600">
                No hay cuentas creadas aún.
              </div>
            ) : (
              <div className="space-y-3">
                {balances.map((balance) => (
                  <div
                    key={balance.account_id}
                    className="flex items-center justify-between p-3 rounded-lg border border-slate-200 dark:border-slate-700"
                  >
                    <div>
                      <p className="font-medium">{balance.account_name}</p>
                      <p className="text-sm text-slate-600 dark:text-slate-400">
                        {balance.currency}
                      </p>
                    </div>
                    <div className="text-right">
                      <p className="font-semibold">
                        {new Intl.NumberFormat('es-AR', {
                          style: 'currency',
                          currency: balance.currency,
                        }).format(Number(balance.balance))}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  )
}
