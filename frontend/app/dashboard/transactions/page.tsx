'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { DashboardLayout } from '@/components/dashboard-layout'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { Account, Category } from '@/lib/types'
import { Plus, TrendingUp, TrendingDown, ArrowLeftRight } from 'lucide-react'
import { format } from 'date-fns'

export default function TransactionsPage() {
  const [accounts, setAccounts] = useState<Account[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [ledger, setLedger] = useState<Record<string, unknown>[]>([])
  const [loading, setLoading] = useState(true)
  const [open, setOpen] = useState(false)
  const [txType, setTxType] = useState<'income' | 'expense' | 'transfer'>('expense')

  const [formData, setFormData] = useState({
    posted_at: format(new Date(), 'yyyy-MM-dd'),
    account_id: '',
    category_id: '',
    amount: '',
    description: '',
    counterparty: '',
    from_account_id: '',
    to_account_id: '',
  })

  useEffect(() => {
    loadData()
  }, [])

  const loadData = async () => {
    const [accountsRes, categoriesRes, ledgerRes] = await Promise.all([
      supabase.from('accounts').select('*').eq('is_active', true).order('name'),
      supabase.from('categories').select('*').eq('is_active', true).order('name'),
      supabase.from('account_ledger_v').select('*').order('posted_at', { ascending: false }).limit(50),
    ])

    if (accountsRes.data) setAccounts(accountsRes.data)
    if (categoriesRes.data) setCategories(categoriesRes.data)
    if (ledgerRes.data) setLedger(ledgerRes.data)
    setLoading(false)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    const amount = parseFloat(formData.amount)
    if (isNaN(amount)) return

    let error

    if (txType === 'income') {
      const { error: err } = await supabase.rpc('add_income', {
        p_user_id: null,
        p_posted_at: formData.posted_at,
        p_account_id: formData.account_id,
        p_category_id: formData.category_id,
        p_amount: amount,
        p_description: formData.description || null,
        p_counterparty: formData.counterparty || null,
        p_external_id: null,
        p_status: 'cleared',
      })
      error = err
    } else if (txType === 'expense') {
      const { error: err } = await supabase.rpc('add_expense', {
        p_user_id: null,
        p_posted_at: formData.posted_at,
        p_account_id: formData.account_id,
        p_category_id: formData.category_id,
        p_amount: amount,
        p_description: formData.description || null,
        p_counterparty: formData.counterparty || null,
        p_external_id: null,
        p_status: 'cleared',
      })
      error = err
    } else {
      const { error: err } = await supabase.rpc('add_transfer', {
        p_user_id: null,
        p_posted_at: formData.posted_at,
        p_from_account_id: formData.from_account_id,
        p_to_account_id: formData.to_account_id,
        p_amount_out: amount,
        p_amount_in: null,
        p_fx_mode: null,
        p_fx_rate_used: null,
        p_description: formData.description || null,
        p_external_id: null,
        p_status: 'cleared',
      })
      error = err
    }

    if (!error) {
      setOpen(false)
      setFormData({
        posted_at: format(new Date(), 'yyyy-MM-dd'),
        account_id: '',
        category_id: '',
        amount: '',
        description: '',
        counterparty: '',
        from_account_id: '',
        to_account_id: '',
      })
      loadData()
    }
  }

  const incomeCategories = categories.filter(c => {
    const group = categories.find(cat => cat.id === c.group_id)
    return group
  })

  const expenseCategories = categories.filter(c => {
    const group = categories.find(cat => cat.id === c.group_id)
    return group
  })

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Transacciones</h1>
            <p className="text-slate-600 dark:text-slate-400 mt-1">
              Registra ingresos, gastos y transferencias
            </p>
          </div>
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="mr-2 h-4 w-4" />
                Nueva Transacción
              </Button>
            </DialogTrigger>
            <DialogContent className="max-w-2xl">
              <DialogHeader>
                <DialogTitle>Nueva Transacción</DialogTitle>
              </DialogHeader>
              <Tabs value={txType} onValueChange={(v) => setTxType(v as 'income' | 'expense' | 'transfer')}>
                <TabsList className="grid w-full grid-cols-3">
                  <TabsTrigger value="income">Ingreso</TabsTrigger>
                  <TabsTrigger value="expense">Gasto</TabsTrigger>
                  <TabsTrigger value="transfer">Transferencia</TabsTrigger>
                </TabsList>
                <form onSubmit={handleSubmit} className="space-y-4 mt-4">
                  <div>
                    <Label htmlFor="posted_at">Fecha</Label>
                    <Input
                      id="posted_at"
                      type="date"
                      value={formData.posted_at}
                      onChange={(e) => setFormData({ ...formData, posted_at: e.target.value })}
                      required
                    />
                  </div>

                  {txType !== 'transfer' && (
                    <>
                      <div>
                        <Label htmlFor="account_id">Cuenta</Label>
                        <Select
                          value={formData.account_id}
                          onValueChange={(value) => setFormData({ ...formData, account_id: value })}
                        >
                          <SelectTrigger>
                            <SelectValue placeholder="Seleccionar cuenta" />
                          </SelectTrigger>
                          <SelectContent>
                            {accounts.map((acc) => (
                              <SelectItem key={acc.id} value={acc.id}>
                                {acc.name} ({acc.currency})
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                      <div>
                        <Label htmlFor="category_id">Categoría</Label>
                        <Select
                          value={formData.category_id}
                          onValueChange={(value) => setFormData({ ...formData, category_id: value })}
                        >
                          <SelectTrigger>
                            <SelectValue placeholder="Seleccionar categoría" />
                          </SelectTrigger>
                          <SelectContent>
                            {(txType === 'income' ? incomeCategories : expenseCategories).map((cat) => (
                              <SelectItem key={cat.id} value={cat.id}>
                                {cat.name}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                    </>
                  )}

                  {txType === 'transfer' && (
                    <>
                      <div>
                        <Label htmlFor="from_account_id">Cuenta Origen</Label>
                        <Select
                          value={formData.from_account_id}
                          onValueChange={(value) => setFormData({ ...formData, from_account_id: value })}
                        >
                          <SelectTrigger>
                            <SelectValue placeholder="Seleccionar cuenta" />
                          </SelectTrigger>
                          <SelectContent>
                            {accounts.map((acc) => (
                              <SelectItem key={acc.id} value={acc.id}>
                                {acc.name} ({acc.currency})
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                      <div>
                        <Label htmlFor="to_account_id">Cuenta Destino</Label>
                        <Select
                          value={formData.to_account_id}
                          onValueChange={(value) => setFormData({ ...formData, to_account_id: value })}
                        >
                          <SelectTrigger>
                            <SelectValue placeholder="Seleccionar cuenta" />
                          </SelectTrigger>
                          <SelectContent>
                            {accounts.map((acc) => (
                              <SelectItem key={acc.id} value={acc.id}>
                                {acc.name} ({acc.currency})
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                    </>
                  )}

                  <div>
                    <Label htmlFor="amount">Monto</Label>
                    <Input
                      id="amount"
                      type="number"
                      step="0.01"
                      value={formData.amount}
                      onChange={(e) => setFormData({ ...formData, amount: e.target.value })}
                      required
                    />
                  </div>
                  <div>
                    <Label htmlFor="description">Descripción</Label>
                    <Textarea
                      id="description"
                      value={formData.description}
                      onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                      placeholder="Opcional"
                    />
                  </div>
                  {txType !== 'transfer' && (
                    <div>
                      <Label htmlFor="counterparty">Contraparte</Label>
                      <Input
                        id="counterparty"
                        value={formData.counterparty}
                        onChange={(e) => setFormData({ ...formData, counterparty: e.target.value })}
                        placeholder="Opcional"
                      />
                    </div>
                  )}
                  <div className="flex gap-2 justify-end">
                    <Button type="button" variant="outline" onClick={() => setOpen(false)}>
                      Cancelar
                    </Button>
                    <Button type="submit">Guardar</Button>
                  </div>
                </form>
              </Tabs>
            </DialogContent>
          </Dialog>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Últimos Movimientos</CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="text-center py-8 text-slate-600">Cargando...</div>
            ) : ledger.length === 0 ? (
              <div className="text-center py-8 text-slate-600">
                No hay movimientos registrados aún.
              </div>
            ) : (
              <div className="space-y-2">
                {ledger.map((item, idx) => {
                  const account = accounts.find(a => a.id === item.account_id)
                  const delta = Number(item.delta)
                  const itemType = String(item.type)
                  const description = item.description ? String(item.description) : itemType
                  const postedAt = item.posted_at ? String(item.posted_at) : ''
                  return (
                    <div
                      key={idx}
                      className="flex items-center justify-between p-3 rounded-lg border border-slate-200 dark:border-slate-700"
                    >
                      <div className="flex items-center gap-3">
                        <div className={`p-2 rounded-full ${
                          delta > 0
                            ? 'bg-green-100 dark:bg-green-900/20'
                            : 'bg-red-100 dark:bg-red-900/20'
                        }`}>
                          {itemType === 'transfer' ? (
                            <ArrowLeftRight className="h-4 w-4" />
                          ) : delta > 0 ? (
                            <TrendingUp className="h-4 w-4 text-green-600 dark:text-green-400" />
                          ) : (
                            <TrendingDown className="h-4 w-4 text-red-600 dark:text-red-400" />
                          )}
                        </div>
                        <div>
                          <p className="font-medium">{description}</p>
                          <p className="text-sm text-slate-600 dark:text-slate-400">
                            {account?.name} • {postedAt && format(new Date(postedAt), 'dd/MM/yyyy')}
                          </p>
                        </div>
                      </div>
                      <div className="text-right">
                        <p className={`font-semibold ${
                          delta > 0 ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'
                        }`}>
                          {delta > 0 ? '+' : ''}{delta.toFixed(2)}
                        </p>
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  )
}
