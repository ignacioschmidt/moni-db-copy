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
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Badge } from '@/components/ui/badge'
import { Category, CategoryGroup } from '@/lib/types'
import { Plus, Trash2 } from 'lucide-react'

export default function CategoriesPage() {
  const [groups, setGroups] = useState<CategoryGroup[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [loading, setLoading] = useState(true)
  const [openGroup, setOpenGroup] = useState(false)
  const [openCategory, setOpenCategory] = useState(false)

  const [groupForm, setGroupForm] = useState({
    name: '',
    kind: 'expense' as 'expense' | 'income',
  })

  const [categoryForm, setCategoryForm] = useState({
    name: '',
    group_id: '',
  })

  useEffect(() => {
    loadData()
  }, [])

  const loadData = async () => {
    const [groupsRes, categoriesRes] = await Promise.all([
      supabase.from('category_groups').select('*').eq('is_active', true).order('name'),
      supabase.from('categories').select('*').eq('is_active', true).order('name'),
    ])

    if (groupsRes.data) setGroups(groupsRes.data)
    if (categoriesRes.data) setCategories(categoriesRes.data)
    setLoading(false)
  }

  const handleCreateGroup = async (e: React.FormEvent) => {
    e.preventDefault()

    const { data: { session } } = await supabase.auth.getSession()
    if (!session) return

    const { error } = await supabase.from('category_groups').insert({
      user_id: session.user.id,
      ...groupForm,
      is_active: true,
    })

    if (!error) {
      setOpenGroup(false)
      setGroupForm({ name: '', kind: 'expense' })
      loadData()
    }
  }

  const handleCreateCategory = async (e: React.FormEvent) => {
    e.preventDefault()

    const { data: { session } } = await supabase.auth.getSession()
    if (!session) return

    const { error } = await supabase.from('categories').insert({
      user_id: session.user.id,
      ...categoryForm,
      is_active: true,
    })

    if (!error) {
      setOpenCategory(false)
      setCategoryForm({ name: '', group_id: '' })
      loadData()
    }
  }

  const handleDeleteGroup = async (id: string) => {
    if (!confirm('¿Eliminar este grupo? Las categorías asociadas también se desactivarán.')) return

    await supabase.from('category_groups').update({ is_active: false }).eq('id', id)
    await supabase.from('categories').update({ is_active: false }).eq('group_id', id)
    loadData()
  }

  const handleDeleteCategory = async (id: string) => {
    if (!confirm('¿Eliminar esta categoría?')) return

    const { error } = await supabase.from('categories').update({ is_active: false }).eq('id', id)
    if (!error) loadData()
  }

  const expenseGroups = groups.filter(g => g.kind === 'expense')
  const incomeGroups = groups.filter(g => g.kind === 'income')

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Categorías</h1>
            <p className="text-slate-600 dark:text-slate-400 mt-1">
              Organiza tus ingresos y gastos
            </p>
          </div>
          <div className="flex gap-2">
            <Dialog open={openGroup} onOpenChange={setOpenGroup}>
              <DialogTrigger asChild>
                <Button variant="outline">
                  <Plus className="mr-2 h-4 w-4" />
                  Nuevo Grupo
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Crear Grupo de Categorías</DialogTitle>
                </DialogHeader>
                <form onSubmit={handleCreateGroup} className="space-y-4">
                  <div>
                    <Label htmlFor="group_name">Nombre del Grupo</Label>
                    <Input
                      id="group_name"
                      value={groupForm.name}
                      onChange={(e) => setGroupForm({ ...groupForm, name: e.target.value })}
                      placeholder="Ej: Transporte"
                      required
                    />
                  </div>
                  <div>
                    <Label htmlFor="kind">Tipo</Label>
                    <Select
                      value={groupForm.kind}
                      onValueChange={(value) => setGroupForm({ ...groupForm, kind: value as 'expense' | 'income' })}
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="expense">Gasto</SelectItem>
                        <SelectItem value="income">Ingreso</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="flex gap-2 justify-end">
                    <Button type="button" variant="outline" onClick={() => setOpenGroup(false)}>
                      Cancelar
                    </Button>
                    <Button type="submit">Crear</Button>
                  </div>
                </form>
              </DialogContent>
            </Dialog>

            <Dialog open={openCategory} onOpenChange={setOpenCategory}>
              <DialogTrigger asChild>
                <Button>
                  <Plus className="mr-2 h-4 w-4" />
                  Nueva Categoría
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Crear Categoría</DialogTitle>
                </DialogHeader>
                <form onSubmit={handleCreateCategory} className="space-y-4">
                  <div>
                    <Label htmlFor="group_id">Grupo</Label>
                    <Select
                      value={categoryForm.group_id}
                      onValueChange={(value) => setCategoryForm({ ...categoryForm, group_id: value })}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="Seleccionar grupo" />
                      </SelectTrigger>
                      <SelectContent>
                        {groups.map((group) => (
                          <SelectItem key={group.id} value={group.id}>
                            {group.name} ({group.kind === 'expense' ? 'Gasto' : 'Ingreso'})
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label htmlFor="cat_name">Nombre de la Categoría</Label>
                    <Input
                      id="cat_name"
                      value={categoryForm.name}
                      onChange={(e) => setCategoryForm({ ...categoryForm, name: e.target.value })}
                      placeholder="Ej: Combustible"
                      required
                    />
                  </div>
                  <div className="flex gap-2 justify-end">
                    <Button type="button" variant="outline" onClick={() => setOpenCategory(false)}>
                      Cancelar
                    </Button>
                    <Button type="submit">Crear</Button>
                  </div>
                </form>
              </DialogContent>
            </Dialog>
          </div>
        </div>

        <Tabs defaultValue="expense">
          <TabsList>
            <TabsTrigger value="expense">Gastos</TabsTrigger>
            <TabsTrigger value="income">Ingresos</TabsTrigger>
          </TabsList>

          <TabsContent value="expense" className="space-y-4 mt-6">
            {loading ? (
              <div className="text-center py-12 text-slate-600">Cargando...</div>
            ) : expenseGroups.length === 0 ? (
              <div className="text-center py-12 text-slate-600">
                No hay grupos de gastos. Crea uno para comenzar.
              </div>
            ) : (
              expenseGroups.map((group) => (
                <Card key={group.id}>
                  <CardHeader className="flex flex-row items-center justify-between space-y-0">
                    <div className="flex items-center gap-2">
                      <CardTitle>{group.name}</CardTitle>
                      <Badge variant="outline">Gasto</Badge>
                    </div>
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={() => handleDeleteGroup(group.id)}
                    >
                      <Trash2 className="h-4 w-4 text-destructive" />
                    </Button>
                  </CardHeader>
                  <CardContent>
                    <div className="flex flex-wrap gap-2">
                      {categories
                        .filter((cat) => cat.group_id === group.id)
                        .map((cat) => (
                          <div
                            key={cat.id}
                            className="flex items-center gap-2 px-3 py-1.5 rounded-md bg-slate-100 dark:bg-slate-800 text-sm"
                          >
                            <span>{cat.name}</span>
                            <button
                              onClick={() => handleDeleteCategory(cat.id)}
                              className="text-slate-500 hover:text-destructive"
                            >
                              ×
                            </button>
                          </div>
                        ))}
                      {categories.filter((cat) => cat.group_id === group.id).length === 0 && (
                        <p className="text-sm text-slate-600 dark:text-slate-400">
                          Sin categorías en este grupo
                        </p>
                      )}
                    </div>
                  </CardContent>
                </Card>
              ))
            )}
          </TabsContent>

          <TabsContent value="income" className="space-y-4 mt-6">
            {loading ? (
              <div className="text-center py-12 text-slate-600">Cargando...</div>
            ) : incomeGroups.length === 0 ? (
              <div className="text-center py-12 text-slate-600">
                No hay grupos de ingresos. Crea uno para comenzar.
              </div>
            ) : (
              incomeGroups.map((group) => (
                <Card key={group.id}>
                  <CardHeader className="flex flex-row items-center justify-between space-y-0">
                    <div className="flex items-center gap-2">
                      <CardTitle>{group.name}</CardTitle>
                      <Badge variant="outline">Ingreso</Badge>
                    </div>
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={() => handleDeleteGroup(group.id)}
                    >
                      <Trash2 className="h-4 w-4 text-destructive" />
                    </Button>
                  </CardHeader>
                  <CardContent>
                    <div className="flex flex-wrap gap-2">
                      {categories
                        .filter((cat) => cat.group_id === group.id)
                        .map((cat) => (
                          <div
                            key={cat.id}
                            className="flex items-center gap-2 px-3 py-1.5 rounded-md bg-slate-100 dark:bg-slate-800 text-sm"
                          >
                            <span>{cat.name}</span>
                            <button
                              onClick={() => handleDeleteCategory(cat.id)}
                              className="text-slate-500 hover:text-destructive"
                            >
                              ×
                            </button>
                          </div>
                        ))}
                      {categories.filter((cat) => cat.group_id === group.id).length === 0 && (
                        <p className="text-sm text-slate-600 dark:text-slate-400">
                          Sin categorías en este grupo
                        </p>
                      )}
                    </div>
                  </CardContent>
                </Card>
              ))
            )}
          </TabsContent>
        </Tabs>
      </div>
    </DashboardLayout>
  )
}
