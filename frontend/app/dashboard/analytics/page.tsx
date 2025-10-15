'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { DashboardLayout } from '@/components/dashboard-layout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts'
import { format, startOfMonth, endOfMonth } from 'date-fns'

const COLORS = ['#3b82f6', '#ef4444', '#10b981', '#f59e0b', '#8b5cf6', '#ec4899']

export default function AnalyticsPage() {
  const [incomes, setIncomes] = useState<Record<string, unknown>[]>([])
  const [expenses, setExpenses] = useState<Record<string, unknown>[]>([])
  const [categories, setCategories] = useState<Record<string, unknown>[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedMonth, setSelectedMonth] = useState(format(new Date(), 'yyyy-MM'))

  useEffect(() => {
    loadData()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedMonth])

  const loadData = async () => {
    const startDate = format(startOfMonth(new Date(selectedMonth)), 'yyyy-MM-dd')
    const endDate = format(endOfMonth(new Date(selectedMonth)), 'yyyy-MM-dd')

    const [incomesRes, expensesRes, categoriesRes] = await Promise.all([
      supabase.from('incomes_v').select('*').gte('posted_at', startDate).lte('posted_at', endDate),
      supabase.from('expenses_v').select('*').gte('posted_at', startDate).lte('posted_at', endDate),
      supabase.from('categories').select('*').eq('is_active', true),
    ])

    if (incomesRes.data) setIncomes(incomesRes.data)
    if (expensesRes.data) setExpenses(expensesRes.data)
    if (categoriesRes.data) setCategories(categoriesRes.data)
    setLoading(false)
  }

  const totalIncome = incomes.reduce((sum, tx) => sum + Number(tx.amount), 0)
  const totalExpense = expenses.reduce((sum, tx) => sum + Number(tx.amount), 0)
  const balance = totalIncome - totalExpense

  const expensesByCategory: Record<string, number> = {}
  expenses.forEach(tx => {
    const category = categories.find(c => c.id === tx.category_id)
    if (category && typeof category.name === 'string') {
      const categoryName = category.name
      const amount = typeof tx.amount === 'number' || typeof tx.amount === 'string' ? Number(tx.amount) : 0
      if (!expensesByCategory[categoryName]) {
        expensesByCategory[categoryName] = 0
      }
      expensesByCategory[categoryName] += amount
    }
  })

  const expensesChartData = Object.entries(expensesByCategory).map(([name, value]) => ({
    name,
    value: Number(value.toFixed(2)),
  }))

  const monthlyData = [
    { name: 'Ingresos', value: Number(totalIncome.toFixed(2)) },
    { name: 'Gastos', value: Number(totalExpense.toFixed(2)) },
  ]

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Análisis</h1>
            <p className="text-slate-600 dark:text-slate-400 mt-1">
              Visualiza tus patrones financieros
            </p>
          </div>
          <div className="w-48">
            <Select value={selectedMonth} onValueChange={setSelectedMonth}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {Array.from({ length: 12 }, (_, i) => {
                  const date = new Date()
                  date.setMonth(date.getMonth() - i)
                  const value = format(date, 'yyyy-MM')
                  const label = format(date, 'MMMM yyyy')
                  return (
                    <SelectItem key={value} value={value}>
                      {label}
                    </SelectItem>
                  )
                })}
              </SelectContent>
            </Select>
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-3">
          <Card>
            <CardHeader>
              <CardTitle className="text-sm font-medium">Ingresos Totales</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-green-600 dark:text-green-400">
                ${totalIncome.toFixed(2)}
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-sm font-medium">Gastos Totales</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-red-600 dark:text-red-400">
                ${totalExpense.toFixed(2)}
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-sm font-medium">Balance</CardTitle>
            </CardHeader>
            <CardContent>
              <div className={`text-2xl font-bold ${
                balance >= 0 ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'
              }`}>
                ${balance.toFixed(2)}
              </div>
            </CardContent>
          </Card>
        </div>

        <div className="grid gap-6 md:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle>Ingresos vs Gastos</CardTitle>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="text-center py-12 text-slate-600">Cargando...</div>
              ) : monthlyData.every(d => d.value === 0) ? (
                <div className="text-center py-12 text-slate-600">
                  No hay datos para este mes
                </div>
              ) : (
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={monthlyData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="value" fill="#3b82f6" />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Gastos por Categoría</CardTitle>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="text-center py-12 text-slate-600">Cargando...</div>
              ) : expensesChartData.length === 0 ? (
                <div className="text-center py-12 text-slate-600">
                  No hay gastos en este mes
                </div>
              ) : (
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={expensesChartData}
                      cx="50%"
                      cy="50%"
                      labelLine={false}
                      label={(entry) => `${entry.name}: $${entry.value}`}
                      outerRadius={80}
                      fill="#8884d8"
                      dataKey="value"
                    >
                      {expensesChartData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              )}
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Detalle de Categorías</CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="text-center py-8 text-slate-600">Cargando...</div>
            ) : expensesChartData.length === 0 ? (
              <div className="text-center py-8 text-slate-600">
                No hay gastos para mostrar
              </div>
            ) : (
              <div className="space-y-3">
                {expensesChartData
                  .sort((a, b) => b.value - a.value)
                  .map((item, idx) => {
                    const percentage = ((item.value / totalExpense) * 100).toFixed(1)
                    return (
                      <div
                        key={idx}
                        className="flex items-center justify-between p-3 rounded-lg border border-slate-200 dark:border-slate-700"
                      >
                        <div className="flex items-center gap-3">
                          <div
                            className="w-4 h-4 rounded-full"
                            style={{ backgroundColor: COLORS[idx % COLORS.length] }}
                          />
                          <span className="font-medium">{item.name}</span>
                        </div>
                        <div className="flex items-center gap-4">
                          <span className="text-sm text-slate-600 dark:text-slate-400">
                            {percentage}%
                          </span>
                          <span className="font-semibold">${item.value.toFixed(2)}</span>
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
