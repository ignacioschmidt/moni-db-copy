# Moni — Backend (Supabase) • Blueprint & Ops Guide (v2)

> **Objetivo:** Dejar el backend **blindado** (restaurable 1:1), comprensible **a prueba de junior/agent**, y con un **contrato claro** para el frontend y automatizaciones. Este doc reemplaza/integra el blueprint v1.

---

## 0) Resumen ejecutivo

- **Stack:** Supabase (Postgres + Auth + RLS + RPC + pg\_cron).
- **Estado actual:** `accounts`, `categories`, `category_groups`, `transactions`, `fx_rates`, catálogos de tipos y plantillas; vistas (`account_ledger_v`, `account_balances_v`, `incomes_v`, `expenses_v`, `transfers_v`); RPCs (`add_income`, `add_expense`, `add_transfer`); trigger `validate_transaction_rules`; cron `refresh_fx_rates`.
- **Snapshot:** `schema.sql` en la raíz del repo (**fuente de verdad** del backend). Opcional: `seed.sql` para catálogos.
- **Contrato de acceso:** Lectura por vistas/SELECT con RLS; escritura **solo** vía RPC `add_*`.

---

## 1) Propósito y principios

- **DB-first:** la base y sus reglas viven en Postgres.
- **Simplicidad operativa:** evitar capas intermedias salvo criterio (ver §9).
- **Propiedad por usuario:** RLS con `auth.uid()`; nadie ve datos de otro.
- **Idempotencia:** `transactions.external_id` para importaciones/sync.
- **Auditable:** todo cambio de esquema mediante migraciones/versionado.

---

## 2) Estructura del repo `moni-db`

```
moni-db/
├── schema.sql            # snapshot completo del esquema (sin datos)
├── docs/
│   ├── blueprint.md      # (este doc) arquitectura + decisiones
│   └── frontend-contract.md  # contrato de uso para app/agents
├── .github/
│   ├── CODEOWNERS        # dueño revisor (opcional)
│   └── PULL_REQUEST_TEMPLATE/db.md
├── .cursorrules          # reglas mínimas para agentes (opcional)
├── .gitignore
└── supabase/             # generado por CLI; no versionar .temp
    └── .temp/
```

> **Regla de oro:** `schema.sql` es **la** fuente de verdad para reconstruir.

---

## 3) Módulos funcionales (qué hace cada uno)

- **Auth & Perfil**: `auth.users`, `profiles`, `user_settings` (timezone, base\_currency, theme, locale, etc.).
- **Catálogos**: `currencies`, `account_types`, `category_group_templates`, `category_templates`.
- **FX**: `fx_rates` + función `refresh_fx_rates` (vía cron diario). Guarda pares mínimos (USD‑ARS oficial, EUR‑USD, BRL‑ARS, USD‑MXN) y derivados necesarios.
- **Cuentas**: `accounts` (asset/liability, currency, institution, sync\_flags).
- **Categorías**: `category_groups(kind: expense|income)`, `categories` (per‑user, con grupo obligatorio; si falta, cae en **Otros** por función de saneo).
- **Transacciones**: `transactions` con forma **contable** (debit/credit account/category según tipo). Vistas de conveniencia: `incomes_v`, `expenses_v`, `transfers_v`, `account_ledger_v`, `account_balances_v`.

---

## 4) Reglas de negocio críticas

- **Tipos**: `expense`, `income`, `transfer`, `adjustment`.
- **Formas válidas** (enforced por constraints + trigger):
  - *Expense*: `debit_category(expense)` + `credit_account`.
  - *Income*: `debit_account` + `credit_category(income)`.
  - *Transfer*: `debit_account != credit_account`; si **misma moneda** → sin FX; si **distinta** → `amount_counter` o `fx_mode` + `fx_rate_used`.
  - *Adjustment*: asiento puente (apertura/cierre) con una pata **account** y la otra **category**.
- **Pertinencia**: toda FK debe pertenecer al **mismo **``.

---

## 5) Contrato para Frontend / Agents (resumen)

- **Lectura** (con sesión):
  - Balances por cuenta → `account_balances_v`.
  - Mayor (movimientos) → `account_ledger_v`.
  - Catálogos → `currencies`, `account_types`.
  - Categorías del usuario → `category_groups`, `categories`.
- **Escritura** (siempre por RPC):
  - `rpc('add_income', { posted_at, account_id, category_id, amount, description?, counterparty?, external_id?, status? })`
  - `rpc('add_expense', { posted_at, account_id, category_id, amount, description?, counterparty?, external_id?, status? })`
  - `rpc('add_transfer', { posted_at, from_account_id, to_account_id, amount_out, amount_in?, fx_mode?, fx_rate_used?, description?, external_id?, status? })`
- **Prohibido**: escribir directo en `transactions` desde el cliente.

> Detalle ampliado y ejemplos: ver `docs/frontend-contract.md`.

---

## 6) Backup & Restore (operativa)

### 6.1 Sacar snapshot (CLI v2)

```bash
# conectado con `supabase link`
supabase db dump -f schema.sql --schema public
```

### 6.2 Restaurar (local o remoto)

**Con psql:**

```bash
psql "<CONN_STRING>" -f schema.sql
```

**Con Supabase CLI (local dev):**

```bash
supabase db reset --db-url "<CONN_STRING>" --file schema.sql
```

> **Nota:** `schema.sql` no trae datos. Si querés catálogos: usar `seed.sql` (opcional).

---

## 7) Cambios controlados (migraciones)

1. Hacer cambios en una rama.
2. Generar migración:

```bash
supabase db diff -f feat_<descripcion>
```

3. Commit + PR → revisión del owner.
4. Aplicar migración (solo tras aprobar):

```bash
supabase db push
```

> Así evitamos “drift” entre lo que está en producción y lo versionado.

---

## 8) RLS & Seguridad

- Políticas **own‑row** por `auth.uid()` para `accounts`, `categories`, `category_groups`, `transactions`, etc.
- Funciones sensibles `` y `search_path` fijado a `public`.
- `validate_transaction_rules` se ejecuta **BEFORE INSERT/UPDATE** en `transactions`.

**Tests manuales sugeridos** (post‑deploy):

- Insert de gasto sin categoría → debe fallar.
- Transfer same‑currency con FX → debe fallar.
- Insert con FK de otro `user_id` → debe fallar.
- Doble import con mismo `external_id` → devuelve el mismo `id`.

---

## 9) ¿Cuándo agregar API intermedia?

**Agregar capa** (Edge/API) solo si se cumple al menos uno:

- Claves de terceros/secretos de servidor o webhooks que no deben ir al cliente.
- Jobs largos/colas (OCR, scraping, imports masivos) o fan‑out de eventos.
- Agregaciones multi‑tenant que requieren `service_role` sin exponerlo.
- Rate‑limits/billing por plan/organización.
- Composición de múltiples orígenes (banco + broker + ERP) con reconciliación.

Si no se cumple: **el cliente usa Supabase REST/RPC directo**.

---

## 10) Apéndice — Cómo leer `schema.sql`

- ``: estructura, constraints, `COMMENT ON`.
- ``: RPC/validaciones, mirar `SECURITY DEFINER`.
- ``: lo que debe consumir el front para leer.
- ``: RLS; buscar `USING` y `CHECK` con `auth.uid()`.
- ``: performance por `user_id`, `posted_at`, etc.

---

