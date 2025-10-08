# Moni DB (Supabase)

**Fuente de verdad del backend de Moni.** Incluye esquema de Postgres, reglas de negocio, RLS, RPC y cronjobs.  
Para la visión y decisiones de arquitectura, ver `docs/blueprint.md`.

---

## Estado y objetivos

- **Stack:** Supabase (Postgres + Auth + RLS + RPC + pg_cron).
- **Módulos:** cuentas, categorías, transacciones, FX rates, catálogos, vistas.
- **Contrato:** escritura **solo** vía RPC (`add_income`, `add_expense`, `add_transfer`); lectura por vistas y SELECT con sesión válida.
- **Snapshot:** `schema.sql` (esquema completo, sin datos).

---

## Estructura del repo
