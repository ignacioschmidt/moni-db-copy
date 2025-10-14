# Moni DB (Supabase)

**Fuente de verdad del backend de Moni.**\
Incluye esquema de Postgres, RLS, reglas de negocio, RPC y cronjobs.\
Para arquitectura y decisiones ver [`docs/blueprint.md`](./docs/blueprint.md).

---

## Estado y objetivos

- **Stack:** Supabase (Postgres + Auth + RLS + RPC + pg\_cron)
- **Módulos:** cuentas, categorías, transacciones, FX rates, catálogos, vistas
- **Contrato:** escritura **solo** vía RPC (`add_income`, `add_expense`, `add_transfer`);\
  lectura por vistas/SELECT con sesión válida (RLS)
- **Snapshot:** `schema.sql` (esquema completo, sin datos)

---

## Estructura del repo

```
moni-db/
├── README.md
├── schema.sql                 # snapshot del esquema (sin datos)
├── docs/
│   ├── blueprint.md           # arquitectura + decisiones (backend blueprint)
│   └── frontend-contract.md   # contrato de uso para app/agents (RPC, payloads)
└── supabase/                  # generado por CLI (no commitear .temp/)
    └── .temp/
```

> **Regla de oro:** `schema.sql` es la **fuente de verdad** para restaurar el backend.

---

## Uso rápido

### Dump (exportar esquema)

```bash
# requiere haber hecho `supabase link`
supabase db dump -f schema.sql --schema public
```

### Restore (importar esquema)

**Opcion A: psql**

```bash
psql "<CONN_STRING>" -f schema.sql
```

**Opcion B: Supabase CLI local**

```bash
supabase db reset --db-url "<CONN_STRING>" --file schema.sql
```

> `schema.sql` no incluye datos.\
> Si se agregan catálogos o plantillas, usar un `seed.sql` aparte.

---

## Migraciones (cambios controlados)

1. Crear rama feature.
2. Generar migración:

```bash
supabase db diff -f feat_<descripcion>
```

3. Abrir PR y pedir revisión.
4. Aplicar tras aprobar:

```bash
supabase db push
```

---

## Contrato para Frontend / Agents (resumen)

**Lectura (con sesión):**

- Balances por cuenta → `account_balances_v`
- Mayor/ledger → `account_ledger_v`
- Catálogos → `currencies`, `account_types`
- Categorías del usuario → `category_groups`, `categories`

**Escritura (siempre por RPC):**

```js
rpc('add_income', {
  posted_at,
  account_id,
  category_id,
  amount,
  description?,
  counterparty?,
  external_id?,
  status?
})

rpc('add_expense', {
  posted_at,
  account_id,
  category_id,
  amount,
  description?,
  counterparty?,
  external_id?,
  status?
})

rpc('add_transfer', {
  posted_at,
  from_account_id,
  to_account_id,
  amount_out,
  amount_in?,
  fx_mode?,
  fx_rate_used?,
  description?,
  external_id?,
  status?
})
```

**Prohibido:** insertar/actualizar directo en `transactions` desde el cliente.\
Detalles y ejemplos ampliados en [`docs/frontend-contract.md`](./docs/frontend-contract.md).

---

## Seguridad

- RLS por usuario con `auth.uid()` en tablas de datos (`accounts`, `categories`, `category_groups`, `transactions`, …).
- Triggers/funciones sensibles con `SECURITY DEFINER` y `search_path` fijado a `public`.
- Trigger `validate_transaction_rules` **BEFORE INSERT/UPDATE** en `transactions` (forma contable + coherencias FX).

**Sanity checks manuales (post-deploy):**

- Gasto sin categoría → debe fallar.
- Transferencia misma moneda con FX → debe fallar.
- FK de otro `user_id` → debe fallar.
- Doble import con mismo `external_id` → debe devolver el mismo `id`.

---

## Cron FX

- Función `refresh_fx_rates` poblada por `pg_cron` diario.
- Guarda pares mínimos (USD-ARS oficial, EUR-USD, BRL-ARS, USD-MXN) y derivados necesarios.

---

## Contribución / PR

- Abrir PR con cambios de DB generados por `supabase db diff`.
- Mantener comentarios (`COMMENT ON`) para API Docs en columnas/tablas nuevas.
- No introducir capas API intermedias salvo necesidad explícita (secretos, webhooks, jobs largos, etc.).

---

## Licencia

Privado. Uso interno del proyecto Moni.

