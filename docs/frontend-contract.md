# Moni — Frontend & Backend Contract (v1)

> **Propósito:** manual único (a prueba de junior/agent) para consumir el backend **Moni DB (Supabase)** desde apps y automatizaciones. Define **qué se puede leer**, **cómo se escribe** (solo RPC), reglas de negocio, y el **flujo de edición/eliminación** abstraído para el usuario.

---

## 0) Alcance y principios

- **DB-first:** Postgres + Supabase (Auth, RLS, RPC, pg_cron).
- **RLS por usuario:** todo filtrado por `auth.uid()`; sin sesión válida no hay datos.
- **Escritura inmutable:** **solo** mediante RPC (`add_*`).
- **Edición/eliminación desde UI:** se implementan como *ajustes contables* bajo el capó.
- **Sin API intermedia** salvo casos con secretos/webhooks/jobs (ver §8).

---

## 1) Autenticación & Cliente Supabase

### 1.1 Variables del cliente
- `SUPABASE_URL` — URL del proyecto.
- `SUPABASE_ANON_KEY` — **anon key** pública.
- **Nunca** usar `SERVICE_ROLE` en el cliente.

### 1.2 Sesión
```ts
import { createClient } from '@supabase/supabase-js'
export const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_ANON_KEY!)

// OAuth (p.ej. Google)
await supabase.auth.signInWithOAuth({ provider: 'google' })

// Sesión actual
const { data: { session } } = await supabase.auth.getSession()
```

---

## 2) Lectura (READ)

### 2.1 Vistas/tablas permitidas
- **Balances por cuenta** → `account_balances_v (account_id, account_name, currency, balance)`
- **Ledger por cuenta** → `account_ledger_v (posted_at, account_id, delta, type, description)`
- **Catálogos** → `currencies (code, name)`, `account_types (type_code, name, kind)`
- **Categorías del usuario** → `category_groups (id, name, kind)`, `categories (id, name, group_id)`

### 2.2 Ejemplos
```ts
// Balances
await supabase.from('account_balances_v')
  .select('account_id, account_name, currency, balance')
  .order('account_name', { ascending: true })

// Ledger (paginado 0-49)
await supabase.from('account_ledger_v')
  .select('posted_at, account_id, delta, type, description')
  .range(0, 49)
  .order('posted_at', { ascending: true })

// Categorías
await supabase.from('category_groups').select('id, name, kind').order('name')
await supabase.from('categories').select('id, name, group_id').order('name')
```

> **Regla de UI:** los saldos y reportes deben basarse en `account_balances_v`/`account_ledger_v`, no recalcular en cliente.

---

## 3) Escritura (WRITE) — **solo RPC**

> **Nunca** insertar/actualizar directo en `transactions` desde cliente.

### 3.1 Ingreso — `add_income`
**Forma contable:** `debit_account` (+) + `credit_category(income)`.
```ts
await supabase.rpc('add_income', {
  p_user_id: null,                // null = usar auth.uid()
  p_posted_at: '2025-10-07',
  p_account_id: '<ACCOUNT_ID>',   // recibe el dinero
  p_category_id: '<CATEGORY_ID_INCOME>',
  p_amount: 100000,               // positivo
  p_description: 'Sueldo',
  p_counterparty: 'Empresa',
  p_external_id: 'payroll_2025_10', // opcional: idempotencia
  p_status: 'cleared'             // 'cleared' | 'pending'
})
```

### 3.2 Gasto — `add_expense`
**Forma contable:** `debit_category(expense)` + `credit_account` (-).
```ts
await supabase.rpc('add_expense', {
  p_user_id: null,
  p_posted_at: '2025-10-08',
  p_account_id: '<ACCOUNT_ID>',      // desde donde sale
  p_category_id: '<CATEGORY_ID_EXPENSE>',
  p_amount: 30000,
  p_description: 'Supermercado',
  p_counterparty: 'Coto',
  p_external_id: 'ticket_000123',
  p_status: 'cleared'
})
```

### 3.3 Transferencia — `add_transfer`
**Forma contable:** `credit_account(from)` (-) + `debit_account(to)` (+).
- **Misma moneda:** **no** enviar campos FX.
- **Distintas monedas:** enviar `p_amount_in` **o** `p_fx_mode: 'override'` + `p_fx_rate_used`.
```ts
// Cross-currency con monto destino explícito (override)
await supabase.rpc('add_transfer', {
  p_user_id: null,
  p_posted_at: '2025-10-08',
  p_from_account_id: '<ARS_ACC>',
  p_to_account_id: '<USD_ACC>',
  p_amount_out: 10000, // ARS
  p_amount_in: 10,     // USD
  p_fx_mode: 'override',
  p_fx_rate_used: 1000, // 10000/10
  p_description: 'Compra USD',
  p_external_id: 'fx_2025_10_08_1',
  p_status: 'cleared'
})
```

> **Idempotencia:** si `external_id` se repite para el mismo usuario, la RPC devuelve el **mismo `id`** (no duplica).

---

## 4) Edición / Eliminación (abstraído como ajustes)

**Objetivo UX:** el usuario “edita” o “borra” sin conocer contabilidad.  
**Backend:** crea *asientos de ajuste* para revertir y (si aplica) reemplazar.

### 4.1 Flujo esperado desde el cliente (contrato)
- **Editar transacción** → llamar RPC `adjust_transaction` con `{ tx_id, new_values }`.
  - El backend: (1) inserta **ajuste inverso** de la original; (2) inserta **nueva** transacción corregida; (3) retorna `ids`.
- **Eliminar transacción** → llamar RPC `adjust_transaction` con `{ tx_id, action: 'void' }`.
  - El backend: inserta **ajuste inverso** de la original y no crea reemplazo.

> **Nota:** hoy **no existe** `adjust_transaction` en DB. Está **diseñado** aquí como contrato para implementarlo luego. Mientras tanto, en ambientes de test, se puede hacer *soft delete* con `is_deleted` (si se decide agregar) ajustando vistas para excluir borrados.

### 4.2 Reglas de validación (aplican igual que altas)
- Pertinencia: todas las FKs deben ser del mismo `user_id`.
- Formas válidas por `type` (expense/income/transfer/adjustment).
- FX coherente en transferencias cross-currency.

### 4.3 Mensajes de error a mapear en UI
- `Debit/Credit account/category does not belong to this user`
- `Expense must use an EXPENSE category on the debit side`
- `Income must use an INCOME category on the credit side`
- `Transfer requires two different accounts`
- `Same-currency transfer must not set amount_counter/fx fields`
- `Cross-currency transfer: provide amount_counter or fx_mode`
- `fx_rate_used must be > 0`

---

## 5) Reglas Do / Don’t

**Do**
- Usar siempre RPC `add_*` para crear movimientos.
- Consumir balances/ledger desde vistas.
- En UI de transferencias, ofrecer: “usar tasa del sistema” **o** “ingresar monto destino (override)”.
- Usar `external_id` para importaciones/reintentos.

**Don’t**
- No usar `service_role` en el cliente.
- No escribir directo en `transactions`.
- No permitir categorías incoherentes (expense vs income) en formularios.

---

## 6) Casos de uso típicos (end-to-end)

1) **Onboarding**  
- Leer `account_types`, `currencies` para formularios.
- Crear cuentas del usuario (INSERT en `accounts` pasa RLS por `auth.uid()`).
- Clonar categorías desde plantillas con función del backend (si está expuesta) **o** UI para crear grupos/categorías.

2) **Carga de gasto**  
- UI pide: cuenta (origen), categoría de gasto, monto, fecha, descripción.
- Llamar `add_expense`.
- Refrescar `account_balances_v` y `account_ledger_v`.

3) **Editar gasto**  
- UI permite cambiar monto/fecha/categoría.
- Llamar `adjust_transaction({ tx_id, new_values })` una vez implementado.

4) **Transferencia cross-currency**  
- UI pide cuenta origen/destino, monto que sale; ofrece: a) calcular con tasa del sistema; b) ingresar monto destino (override).
- Llamar `add_transfer` con la variante elegida.

---

## 7) Versionado del contrato

- Todo cambio de RPC, vistas, columnas o validaciones **debe**:
  1) quedar reflejado en este archivo;
  2) acompañarse de migración versionada (`schema.sql`/`supabase db diff`).
- Mantener sección de *changelog* al tope del doc.

---

## 8) ¿Cuándo usar API intermedia (Edge/Server)?

Agregar capa solo si:
- Se usan **secretos** de terceros (webhooks, OAuth de bancos, etc.).
- **Jobs** largos/asincrónicos (OCR, scraping, imports masivos).
- Agregaciones multi-tenant con **service_role** (nunca en cliente).
- **Rate limits**/planes/billing a nivel organización.

Si no aplica, el cliente habla directo con Supabase REST/RPC.

---

## 9) Checklist para implementación front/agent

- [ ] Configurar Supabase client con `anon key` y login funcional.
- [ ] Listar `account_balances_v` sin errores.
- [ ] Ejecutar `add_income` y ver reflejo en balances/ledger.
- [ ] Ejecutar `add_expense`.
- [ ] Ejecutar `add_transfer` same-currency y cross-currency.
- [ ] Manejar mensajes de validación del trigger y mostrarlos claro.
- [ ] Usar `external_id` en importaciones.
- [ ] (Cuando exista) usar `adjust_transaction` para editar/borrar.

