# Moni - Frontend

Frontend prototype for Moni, a personal financial management tool built with Next.js, TypeScript, shadcn/ui, and Supabase.

## Features

### Authentication
- Email/password login and signup
- Protected routes with session management
- Automatic redirect to login for unauthenticated users

### Dashboard
- Overview of all accounts and balances
- Total balance by currency
- Quick access to all main features

### Accounts Management
- Create and manage financial accounts (bank accounts, wallets, etc.)
- Support for multiple currencies (ARS, USD, EUR, BRL, MXN)
- Different account types (checking, savings, credit card, investment, etc.)
- Soft delete functionality

### Transactions
- Record income, expenses, and transfers
- Date and amount tracking
- Category assignment
- Description and counterparty fields
- Real-time ledger view with latest movements
- Visual indicators for transaction types

### Categories
- Organize expenses and income into groups
- Create custom category groups
- Add multiple categories per group
- Separate views for expense and income categories
- Easy management with delete functionality

### Analytics
- Monthly financial overview
- Income vs Expenses comparison (bar chart)
- Expense breakdown by category (pie chart)
- Detailed category analysis with percentages
- Month selector for historical data

## Tech Stack

- **Framework**: Next.js 15 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **UI Components**: shadcn/ui
- **Database**: Supabase (PostgreSQL)
- **Charts**: Recharts
- **Date Handling**: date-fns
- **Icons**: lucide-react

## Getting Started

### Prerequisites

- Node.js 18+ installed
- Supabase project configured (see backend schema.sql)

### Installation

1. Install dependencies:
```bash
npm install
```

2. Configure environment variables:
Create `.env.local` file with:
```
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

3. Run the development server:
```bash
npm run dev
```

4. Open [http://localhost:3000](http://localhost:3000) in your browser

### Build for Production

```bash
npm run build
npm start
```

## Project Structure

```
frontend/
├── app/
│   ├── dashboard/
│   │   ├── accounts/       # Accounts management
│   │   ├── analytics/      # Financial analytics
│   │   ├── categories/     # Categories management
│   │   ├── transactions/   # Transaction recording
│   │   └── page.tsx        # Dashboard overview
│   ├── login/              # Authentication
│   ├── globals.css         # Global styles
│   └── layout.tsx          # Root layout
├── components/
│   ├── ui/                 # shadcn/ui components
│   └── dashboard-layout.tsx # Main layout with sidebar
├── lib/
│   ├── supabase.ts         # Supabase client
│   ├── types.ts            # TypeScript types
│   └── utils.ts            # Utility functions
└── public/                 # Static assets
```

## Backend Integration

This frontend connects to the Moni backend (Supabase) using:

- **Views for reading**: `account_balances_v`, `account_ledger_v`, `incomes_v`, `expenses_v`
- **RPC functions for writing**: `add_income`, `add_expense`, `add_transfer`
- **Direct table access**: `accounts`, `categories`, `category_groups`, `currencies`, `account_types`

All data access is protected by Row Level Security (RLS) policies ensuring users only see their own data.

## Key Design Decisions

- **Client-side rendering** for dashboard pages to handle real-time data
- **shadcn/ui components** for consistent, accessible UI
- **Type-safe** with TypeScript throughout
- **Responsive design** with mobile-first approach
- **Clean architecture** with separation of concerns

## Future Enhancements

- Import transactions from bank statements
- Budget planning and alerts
- Multi-currency conversion handling
- Export data to CSV/Excel
- Dark mode toggle
- More detailed analytics and reports
- Mobile app version
