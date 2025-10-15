'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { DashboardLayout } from '@/components/dashboard-layout'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Account, AccountType, Currency } from '@/lib/types'
import { Plus, Trash2 } from 'lucide-react'

export default function AccountsPage() {
  const [accounts, setAccounts] = useState<Account[]>([])
  const [currencies, setCurrencies] = useState<Currency[]>([])
  const [accountTypes, setAccountTypes] = useState<AccountType[]>([])
  const [loading, setLoading] = useState(true)
  const [open, setOpen] = useState(false)

  const [formData, setFormData] = useState({
    name: '',
    currency: 'ARS',
    type_code: 'checking',
    institution: '',
  })

  useEffect(() => {
    loadData()
  }, [])

  const loadData = async () => {
    const [accountsRes, currenciesRes, typesRes] = await Promise.all([
      supabase.from('accounts').select('*').order('name'),
      supabase.from('currencies').select('*').order('code'),
      supabase.from('account_types').select('*').order('name'),
    ])

    if (accountsRes.data) setAccounts(accountsRes.data)
    if (currenciesRes.data) setCurrencies(currenciesRes.data)
    if (typesRes.data) setAccountTypes(typesRes.data)
    setLoading(false)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    const { data: { session } } = await supabase.auth.getSession()
    if (!session) return

    const { error } = await supabase.from('accounts').insert({
      user_id: session.user.id,
      ...formData,
      is_active: true,
    })

    if (!error) {
      setOpen(false)
      setFormData({ name: '', currency: 'ARS', type_code: 'checking', institution: '' })
      loadData()
    }
  }

  const handleDelete = async (id: string) => {
    if (!confirm('¿Estás seguro de eliminar esta cuenta?')) return

    const { error } = await supabase
      .from('accounts')
      .update({ is_active: false })
      .eq('id', id)

    if (!error) {
      loadData()
    }
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Cuentas</h1>
            <p className="text-slate-600 dark:text-slate-400 mt-1">
              Gestiona tus cuentas bancarias, billeteras y más
            </p>
          </div>
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="mr-2 h-4 w-4" />
                Nueva Cuenta
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Crear Nueva Cuenta</DialogTitle>
              </DialogHeader>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <Label htmlFor="name">Nombre</Label>
                  <Input
                    id="name"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    placeholder="Ej: Cuenta Corriente"
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="currency">Moneda</Label>
                  <Select
                    value={formData.currency}
                    onValueChange={(value) => setFormData({ ...formData, currency: value })}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {currencies.map((curr) => (
                        <SelectItem key={curr.code} value={curr.code}>
                          {curr.code} - {curr.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label htmlFor="type">Tipo</Label>
                  <Select
                    value={formData.type_code}
                    onValueChange={(value) => setFormData({ ...formData, type_code: value })}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {accountTypes.map((type) => (
                        <SelectItem key={type.type_code} value={type.type_code}>
                          {type.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label htmlFor="institution">Institución (opcional)</Label>
                  <Input
                    id="institution"
                    value={formData.institution}
                    onChange={(e) => setFormData({ ...formData, institution: e.target.value })}
                    placeholder="Ej: Banco Galicia"
                  />
                </div>
                <div className="flex gap-2 justify-end">
                  <Button type="button" variant="outline" onClick={() => setOpen(false)}>
                    Cancelar
                  </Button>
                  <Button type="submit">Crear</Button>
                </div>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {loading ? (
            <div className="col-span-full text-center py-12 text-slate-600">
              Cargando...
            </div>
          ) : accounts.length === 0 ? (
            <div className="col-span-full text-center py-12 text-slate-600">
              No hay cuentas creadas. Crea tu primera cuenta para comenzar.
            </div>
          ) : (
            accounts.filter(a => a.is_active).map((account) => (
              <Card key={account.id}>
                <CardHeader className="flex flex-row items-center justify-between space-y-0">
                  <CardTitle className="text-lg">{account.name}</CardTitle>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => handleDelete(account.id)}
                  >
                    <Trash2 className="h-4 w-4 text-destructive" />
                  </Button>
                </CardHeader>
                <CardContent>
                  <div className="space-y-1 text-sm">
                    <p className="text-slate-600 dark:text-slate-400">
                      <span className="font-medium">Moneda:</span> {account.currency}
                    </p>
                    <p className="text-slate-600 dark:text-slate-400">
                      <span className="font-medium">Tipo:</span> {account.type_code}
                    </p>
                    {account.institution && (
                      <p className="text-slate-600 dark:text-slate-400">
                        <span className="font-medium">Institución:</span> {account.institution}
                      </p>
                    )}
                  </div>
                </CardContent>
              </Card>
            ))
          )}
        </div>
      </div>
    </DashboardLayout>
  )
}
