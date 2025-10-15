'use client'

import { ReactNode, useEffect, useState } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabase'
import { Button } from '@/components/ui/button'
import {
  LayoutDashboard,
  Wallet,
  ArrowLeftRight,
  Tags,
  PieChart,
  LogOut
} from 'lucide-react'

interface DashboardLayoutProps {
  children: ReactNode
}

const navItems = [
  { href: '/dashboard', label: 'Resumen', icon: LayoutDashboard },
  { href: '/dashboard/accounts', label: 'Cuentas', icon: Wallet },
  { href: '/dashboard/transactions', label: 'Transacciones', icon: ArrowLeftRight },
  { href: '/dashboard/categories', label: 'Categorías', icon: Tags },
  { href: '/dashboard/analytics', label: 'Análisis', icon: PieChart },
]

export function DashboardLayout({ children }: DashboardLayoutProps) {
  const pathname = usePathname()
  const router = useRouter()
  const [user, setUser] = useState<{ email?: string } | null>(null)

  useEffect(() => {
    const checkUser = async () => {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) {
        router.push('/login')
      } else {
        setUser(session.user)
      }
    }
    checkUser()
  }, [router])

  const handleLogout = async () => {
    await supabase.auth.signOut()
    router.push('/login')
  }

  if (!user) {
    return <div className="flex items-center justify-center min-h-screen">Cargando...</div>
  }

  return (
    <div className="min-h-screen bg-slate-50 dark:bg-slate-900">
      <aside className="fixed left-0 top-0 z-40 h-screen w-64 bg-white dark:bg-slate-800 border-r border-slate-200 dark:border-slate-700">
        <div className="flex h-full flex-col">
          <div className="flex h-16 items-center border-b border-slate-200 dark:border-slate-700 px-6">
            <h1 className="text-2xl font-bold">Moni</h1>
          </div>
          <nav className="flex-1 space-y-1 p-4">
            {navItems.map((item) => {
              const Icon = item.icon
              const isActive = pathname === item.href
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                    isActive
                      ? 'bg-slate-100 dark:bg-slate-700 text-slate-900 dark:text-slate-100'
                      : 'text-slate-600 dark:text-slate-400 hover:bg-slate-50 dark:hover:bg-slate-700/50'
                  }`}
                >
                  <Icon className="h-5 w-5" />
                  {item.label}
                </Link>
              )
            })}
          </nav>
          <div className="border-t border-slate-200 dark:border-slate-700 p-4">
            <div className="mb-3 px-3">
              <p className="text-sm text-slate-600 dark:text-slate-400 truncate">
                {user.email}
              </p>
            </div>
            <Button
              variant="outline"
              className="w-full justify-start"
              onClick={handleLogout}
            >
              <LogOut className="mr-2 h-4 w-4" />
              Cerrar sesión
            </Button>
          </div>
        </div>
      </aside>
      <main className="pl-64">
        <div className="container mx-auto p-6">
          {children}
        </div>
      </main>
    </div>
  )
}
