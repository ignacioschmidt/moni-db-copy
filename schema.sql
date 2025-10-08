


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."_resolve_user"("p_user_id" "uuid") RETURNS "uuid"
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
  select coalesce(p_user_id, auth.uid())
$$;


ALTER FUNCTION "public"."_resolve_user"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."_resolve_user"("p_user_id" "uuid") IS 'Helper: returns p_user_id or auth.uid() when null. search_path fixed.';



CREATE OR REPLACE FUNCTION "public"."add_expense"("p_user_id" "uuid", "p_posted_at" "date", "p_account_id" "uuid", "p_category_id" "uuid", "p_amount" numeric, "p_description" "text" DEFAULT NULL::"text", "p_counterparty" "text" DEFAULT NULL::"text", "p_external_id" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT 'cleared'::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user uuid := public._resolve_user(p_user_id);
  v_id   uuid;
begin
  if p_external_id is not null then
    select id into v_id
    from public.transactions
    where user_id = v_user and external_id = p_external_id
    limit 1;
    if v_id is not null then
      return v_id; -- idempotencia: ya existe
    end if;
  end if;

  insert into public.transactions (
    user_id, type, posted_at, status,
    amount,
    debit_category_id,    -- gasto
    credit_account_id,    -- cuenta que paga
    description, counterparty, external_id
  )
  values (
    v_user, 'expense', p_posted_at, p_status,
    p_amount,
    p_category_id,
    p_account_id,
    p_description, p_counterparty, p_external_id
  )
  returning id into v_id;

  return v_id;
end;
$$;


ALTER FUNCTION "public"."add_expense"("p_user_id" "uuid", "p_posted_at" "date", "p_account_id" "uuid", "p_category_id" "uuid", "p_amount" numeric, "p_description" "text", "p_counterparty" "text", "p_external_id" "text", "p_status" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."add_expense"("p_user_id" "uuid", "p_posted_at" "date", "p_account_id" "uuid", "p_category_id" "uuid", "p_amount" numeric, "p_description" "text", "p_counterparty" "text", "p_external_id" "text", "p_status" "text") IS 'Insert EXPENSE: account pays (credit_account_id), category is expense (debit_category_id). Returns transaction id.';



CREATE OR REPLACE FUNCTION "public"."add_income"("p_user_id" "uuid", "p_posted_at" "date", "p_account_id" "uuid", "p_category_id" "uuid", "p_amount" numeric, "p_description" "text" DEFAULT NULL::"text", "p_counterparty" "text" DEFAULT NULL::"text", "p_external_id" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT 'cleared'::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user uuid := public._resolve_user(p_user_id);
  v_id   uuid;
begin
  if p_external_id is not null then
    select id into v_id
    from public.transactions
    where user_id = v_user and external_id = p_external_id
    limit 1;
    if v_id is not null then
      return v_id;
    end if;
  end if;

  insert into public.transactions (
    user_id, type, posted_at, status,
    amount,
    debit_account_id,      -- cuenta que recibe
    credit_category_id,    -- categoría de ingreso
    description, counterparty, external_id
  )
  values (
    v_user, 'income', p_posted_at, p_status,
    p_amount,
    p_account_id,
    p_category_id,
    p_description, p_counterparty, p_external_id
  )
  returning id into v_id;

  return v_id;
end;
$$;


ALTER FUNCTION "public"."add_income"("p_user_id" "uuid", "p_posted_at" "date", "p_account_id" "uuid", "p_category_id" "uuid", "p_amount" numeric, "p_description" "text", "p_counterparty" "text", "p_external_id" "text", "p_status" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."add_income"("p_user_id" "uuid", "p_posted_at" "date", "p_account_id" "uuid", "p_category_id" "uuid", "p_amount" numeric, "p_description" "text", "p_counterparty" "text", "p_external_id" "text", "p_status" "text") IS 'Insert INCOME: account receives (debit_account_id), category is income (credit_category_id). Returns transaction id.';



CREATE OR REPLACE FUNCTION "public"."add_transfer"("p_user_id" "uuid", "p_posted_at" "date", "p_from_account_id" "uuid", "p_to_account_id" "uuid", "p_amount_out" numeric, "p_amount_in" numeric DEFAULT NULL::numeric, "p_fx_mode" "text" DEFAULT NULL::"text", "p_fx_rate_used" numeric DEFAULT NULL::numeric, "p_description" "text" DEFAULT NULL::"text", "p_external_id" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT 'cleared'::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user uuid := public._resolve_user(p_user_id);
  v_id   uuid;
begin
  if p_external_id is not null then
    select id into v_id
    from public.transactions
    where user_id = v_user and external_id = p_external_id
    limit 1;
    if v_id is not null then
      return v_id;
    end if;
  end if;

  insert into public.transactions (
    user_id, type, posted_at, status,
    amount,                    -- monto que SALE
    amount_counter,            -- monto que ENTRA (si multi-moneda)
    fx_mode, fx_rate_used,
    credit_account_id,         -- from
    debit_account_id,          -- to
    description, external_id
  )
  values (
    v_user, 'transfer', p_posted_at, p_status,
    p_amount_out,
    p_amount_in,
    p_fx_mode, p_fx_rate_used,
    p_from_account_id,
    p_to_account_id,
    p_description, p_external_id
  )
  returning id into v_id;

  return v_id;
end;
$$;


ALTER FUNCTION "public"."add_transfer"("p_user_id" "uuid", "p_posted_at" "date", "p_from_account_id" "uuid", "p_to_account_id" "uuid", "p_amount_out" numeric, "p_amount_in" numeric, "p_fx_mode" "text", "p_fx_rate_used" numeric, "p_description" "text", "p_external_id" "text", "p_status" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."add_transfer"("p_user_id" "uuid", "p_posted_at" "date", "p_from_account_id" "uuid", "p_to_account_id" "uuid", "p_amount_out" numeric, "p_amount_in" numeric, "p_fx_mode" "text", "p_fx_rate_used" numeric, "p_description" "text", "p_external_id" "text", "p_status" "text") IS 'Insert TRANSFER: from credit_account_id to debit_account_id. Supports cross-currency via amount_counter/fx fields. Returns transaction id.';



CREATE OR REPLACE FUNCTION "public"."clone_category_templates_for_user"("p_user_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
declare
  v_groups_inserted int := 0;
  v_cats_inserted   int := 0;
begin
  -- 1) Crear grupos (uno por template activo)
  with tmpl_parents as (
    select id, name, kind
    from public.category_group_templates
    where is_active = true
  ),
  ins_groups as (
    insert into public.category_groups (user_id, name, kind, is_active)
    select p_user_id, t.name, t.kind, true
    from tmpl_parents t
    where not exists (
      select 1 from public.category_groups g
      where g.user_id = p_user_id
        and g.name    = t.name
        and g.kind    = t.kind
    )
    returning id
  )
  select count(*) into v_groups_inserted from ins_groups;

  -- 2) Mapear template → grupo del usuario y crear categorías hijas
  with parent_map as (
    select tgt.id as group_template_id, g.id as group_id
    from public.category_group_templates tgt
    join public.category_groups g
      on g.user_id = p_user_id
     and g.name    = tgt.name
     and g.kind    = tgt.kind
    where tgt.is_active = true
  ),
  tmpl_children as (
    select ct.id, ct.group_template_id, ct.name
    from public.category_templates ct
    where ct.is_active = true
  ),
  ins_cats as (
    insert into public.categories (user_id, group_id, name, is_active)
    select p_user_id, pm.group_id, c.name, true
    from tmpl_children c
    join parent_map pm on pm.group_template_id = c.group_template_id
    where not exists (
      select 1 from public.categories x
      where x.user_id = p_user_id
        and x.group_id = pm.group_id
        and x.name = c.name
    )
    returning id
  )
  select count(*) into v_cats_inserted from ins_cats;

  return json_build_object('groups_created', v_groups_inserted, 'categories_created', v_cats_inserted);
end;
$$;


ALTER FUNCTION "public"."clone_category_templates_for_user"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."clone_category_templates_for_user"("p_user_id" "uuid") IS 'Clona templates activos: crea category_groups (name,kind) y categories (name) del usuario usando group_template_id.';



CREATE OR REPLACE FUNCTION "public"."clone_selected_category_templates_for_user"("p_user_id" "uuid", "p_template_ids" "uuid"[]) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
declare
  v_groups_inserted int := 0;
  v_cats_inserted   int := 0;
begin
  -- hijos seleccionados
  with sel_children as (
    select ct.id, ct.group_template_id, ct.name
    from public.category_templates ct
    where ct.is_active = true
      and ct.id = any(p_template_ids)
  ),
  -- padres necesarios
  needed_parents as (
    select distinct sc.group_template_id from sel_children sc
  ),
  parent_rows as (
    select tgt.id, tgt.name, tgt.kind
    from public.category_group_templates tgt
    join needed_parents np on np.group_template_id = tgt.id
    where tgt.is_active = true
  ),
  ins_groups as (
    insert into public.category_groups (user_id, name, kind, is_active)
    select p_user_id, pr.name, pr.kind, true
    from parent_rows pr
    where not exists (
      select 1 from public.category_groups g
      where g.user_id = p_user_id and g.name = pr.name and g.kind = pr.kind
    )
    returning id
  )
  select count(*) into v_groups_inserted from ins_groups;

  with parent_map as (
    select tgt.id as group_template_id, g.id as group_id
    from public.category_group_templates tgt
    join public.category_groups g
      on g.user_id = p_user_id and g.name = tgt.name and g.kind = tgt.kind
    where tgt.is_active = true
  ),
  ins_cats as (
    insert into public.categories (user_id, group_id, name, is_active)
    select p_user_id, pm.group_id, sc.name, true
    from sel_children sc
    join parent_map pm on pm.group_template_id = sc.group_template_id
    where not exists (
      select 1 from public.categories x
      where x.user_id = p_user_id and x.group_id = pm.group_id and x.name = sc.name
    )
    returning id
  )
  select count(*) into v_cats_inserted from ins_cats;

  return json_build_object('groups_created', v_groups_inserted, 'categories_created', v_cats_inserted);
end;
$$;


ALTER FUNCTION "public"."clone_selected_category_templates_for_user"("p_user_id" "uuid", "p_template_ids" "uuid"[]) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."clone_selected_category_templates_for_user"("p_user_id" "uuid", "p_template_ids" "uuid"[]) IS 'Clona sólo los category_templates dados; crea el grupo del user si falta.';



CREATE OR REPLACE FUNCTION "public"."ensure_other_groups"("p_user_id" "uuid") RETURNS TABLE("others_expense_id" "uuid", "others_income_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_user_id is null then
    raise exception 'p_user_id is required';
  end if;

  -- Otros (Gastos)
  insert into public.category_groups (user_id, name, kind)
  select p_user_id, 'Otros (Gastos)', 'expense'
  where not exists (
    select 1 from public.category_groups
    where user_id = p_user_id and name='Otros (Gastos)' and kind='expense'
  );
  -- Otros (Ingresos)
  insert into public.category_groups (user_id, name, kind)
  select p_user_id, 'Otros (Ingresos)', 'income'
  where not exists (
    select 1 from public.category_groups
    where user_id = p_user_id and name='Otros (Ingresos)' and kind='income'
  );

  return query
  select 
    (select id from public.category_groups where user_id=p_user_id and name='Otros (Gastos)'   and kind='expense' limit 1),
    (select id from public.category_groups where user_id=p_user_id and name='Otros (Ingresos)' and kind='income'  limit 1);
end;
$$;


ALTER FUNCTION "public"."ensure_other_groups"("p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."ensure_other_groups"("p_user_id" "uuid") IS 'Ensures fallback groups "Otros (Gastos)" and "Otros (Ingresos)" exist for the given User ID; returns their IDs.';



CREATE OR REPLACE FUNCTION "public"."refresh_fx_rates"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'extensions'
    AS $$
declare
  -- payloads crudos de los endpoints
  ar_oficial jsonb;  -- USD/ARS oficial
  eur_ars    jsonb;  -- EUR/ARS
  brl_ars    jsonb;  -- BRL/ARS
  usd_mxn    jsonb;  -- USD/MXN (México)

  -- rates y fechas normalizadas (promedio compra/venta, fecha UTC)
  usd_ars_rate numeric; usd_ars_date date;
  eur_ars_rate numeric; eur_ars_date date;
  brl_ars_rate numeric; brl_ars_date date;
  usd_mxn_rate numeric; usd_mxn_date date;

  d date;
begin
  -- ========== PROVIDER (API) ==========
  -- USD -> ARS (oficial)
  select content::jsonb into ar_oficial
  from extensions.http_get('https://dolarapi.com/v1/dolares/oficial');
  usd_ars_rate := ((ar_oficial->>'compra')::numeric + (ar_oficial->>'venta')::numeric) / 2;
  usd_ars_date := coalesce((ar_oficial->>'fechaActualizacion')::timestamptz::date, now()::date);
  if usd_ars_rate is not null and usd_ars_rate > 0 then
    insert into public.fx_rates (base, quote, as_of_date, rate, source)
    values ('USD','ARS', usd_ars_date, usd_ars_rate, 'provider')
    on conflict (base,quote,as_of_date) do update
      set rate = excluded.rate, fetched_at = now(), source = 'provider';
  end if;

  -- EUR -> ARS
  select content::jsonb into eur_ars
  from extensions.http_get('https://dolarapi.com/v1/cotizaciones/eur');
  eur_ars_rate := ((eur_ars->>'compra')::numeric + (eur_ars->>'venta')::numeric) / 2;
  eur_ars_date := coalesce((eur_ars->>'fechaActualizacion')::timestamptz::date, now()::date);
  if eur_ars_rate is not null and eur_ars_rate > 0 then
    insert into public.fx_rates (base, quote, as_of_date, rate, source)
    values ('EUR','ARS', eur_ars_date, eur_ars_rate, 'provider')
    on conflict (base,quote,as_of_date) do update
      set rate = excluded.rate, fetched_at = now(), source = 'provider';
  end if;

  -- BRL -> ARS
  select content::jsonb into brl_ars
  from extensions.http_get('https://dolarapi.com/v1/cotizaciones/brl');
  brl_ars_rate := ((brl_ars->>'compra')::numeric + (brl_ars->>'venta')::numeric) / 2;
  brl_ars_date := coalesce((brl_ars->>'fechaActualizacion')::timestamptz::date, now()::date);
  if brl_ars_rate is not null and brl_ars_rate > 0 then
    insert into public.fx_rates (base, quote, as_of_date, rate, source)
    values ('BRL','ARS', brl_ars_date, brl_ars_rate, 'provider')
    on conflict (base,quote,as_of_date) do update
      set rate = excluded.rate, fetched_at = now(), source = 'provider';
  end if;

  -- USD -> MXN (México)
  select content::jsonb into usd_mxn
  from extensions.http_get('https://mx.dolarapi.com/v1/cotizaciones/usd');
  usd_mxn_rate := ((usd_mxn->>'compra')::numeric + (usd_mxn->>'venta')::numeric) / 2;
  usd_mxn_date := coalesce((usd_mxn->>'fechaActualizacion')::timestamptz::date, now()::date);
  if usd_mxn_rate is not null and usd_mxn_rate > 0 then
    insert into public.fx_rates (base, quote, as_of_date, rate, source)
    values ('USD','MXN', usd_mxn_date, usd_mxn_rate, 'provider')
    on conflict (base,quote,as_of_date) do update
      set rate = excluded.rate, fetched_at = now(), source = 'provider';
  end if;

  -- ========== DERIVADOS (si hay insumos válidos) ==========
  -- Inversas simples
  if usd_ars_rate > 0 then
    d := usd_ars_date;
    insert into public.fx_rates values ('ARS','USD', d, 1.0 / usd_ars_rate, 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
  end if;

  if eur_ars_rate > 0 then
    d := eur_ars_date;
    insert into public.fx_rates values ('ARS','EUR', d, 1.0 / eur_ars_rate, 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
  end if;

  if brl_ars_rate > 0 then
    d := brl_ars_date;
    insert into public.fx_rates values ('ARS','BRL', d, 1.0 / brl_ars_rate, 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
  end if;

  if usd_mxn_rate > 0 then
    d := usd_mxn_date;
    insert into public.fx_rates values ('MXN','USD', d, 1.0 / usd_mxn_rate, 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
  end if;

  -- Puente USD para cruces
  if eur_ars_rate > 0 and usd_ars_rate > 0 then
    d := least(eur_ars_date, usd_ars_date);
    insert into public.fx_rates values ('EUR','USD', d, eur_ars_rate / usd_ars_rate, 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
    insert into public.fx_rates values ('USD','EUR', d, usd_ars_rate / eur_ars_rate, 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
  end if;

  if brl_ars_rate > 0 and usd_ars_rate > 0 then
    d := least(brl_ars_date, usd_ars_date);
    insert into public.fx_rates values ('BRL','USD', d, brl_ars_rate / usd_ars_rate, 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
    insert into public.fx_rates values ('USD','BRL', d, usd_ars_rate / brl_ars_rate, 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
  end if;

  -- Cruces con MXN por USD
  if eur_ars_rate > 0 and usd_ars_rate > 0 and usd_mxn_rate > 0 then
    d := least(eur_ars_date, usd_ars_date, usd_mxn_date);
    insert into public.fx_rates values ('EUR','MXN', d, (eur_ars_rate / usd_ars_rate) * usd_mxn_rate, 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
    insert into public.fx_rates values ('MXN','EUR', d, 1.0 / ((eur_ars_rate / usd_ars_rate) * usd_mxn_rate), 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
  end if;

  if brl_ars_rate > 0 and usd_ars_rate > 0 and usd_mxn_rate > 0 then
    d := least(brl_ars_date, usd_ars_date, usd_mxn_date);
    insert into public.fx_rates values ('BRL','MXN', d, (brl_ars_rate / usd_ars_rate) * usd_mxn_rate, 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
    insert into public.fx_rates values ('MXN','BRL', d, 1.0 / ((brl_ars_rate / usd_ars_rate) * usd_mxn_rate), 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
  end if;

  -- Cruces EUR <-> BRL por ARS directo
  if eur_ars_rate > 0 and brl_ars_rate > 0 then
    d := least(eur_ars_date, brl_ars_date);
    insert into public.fx_rates values ('EUR','BRL', d, eur_ars_rate / brl_ars_rate, 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
    insert into public.fx_rates values ('BRL','EUR', d, brl_ars_rate / eur_ars_rate, 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
  end if;

  -- ARS <-> MXN por USD
  if usd_ars_rate > 0 and usd_mxn_rate > 0 then
    d := least(usd_ars_date, usd_mxn_date);
    insert into public.fx_rates values ('ARS','MXN', d, (1.0 / usd_ars_rate) * usd_mxn_rate, 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
    insert into public.fx_rates values ('MXN','ARS', d, 1.0 / ((1.0 / usd_ars_rate) * usd_mxn_rate), 'derived', now())
    on conflict (base,quote,as_of_date) do update set rate = excluded.rate, fetched_at = now(), source = 'derived';
  end if;
end;
$$;


ALTER FUNCTION "public"."refresh_fx_rates"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
begin
  new.updated_at := now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."set_updated_at"() IS 'Trigger to update updated_at; search_path fixed.';



CREATE OR REPLACE FUNCTION "public"."validate_transaction_rules"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  -- Accounts
  v_debit_acc_user   uuid;
  v_credit_acc_user  uuid;
  v_debit_acc_curr   char(3);
  v_credit_acc_curr  char(3);

  -- Categories (y su kind vía el grupo)
  v_debit_cat_user   uuid;
  v_credit_cat_user  uuid;
  v_debit_cat_kind   text;
  v_credit_cat_kind  text;
begin
  -- ===== 1) PERTENENCIA (todas las FKs deben ser del mismo user) =====
  if new.debit_account_id is not null then
    select user_id, currency into v_debit_acc_user, v_debit_acc_curr
    from public.accounts where id = new.debit_account_id;
    if v_debit_acc_user is null then
      raise exception 'Debit account not found';
    end if;
    if v_debit_acc_user <> new.user_id then
      raise exception 'Debit account does not belong to this user';
    end if;
  end if;

  if new.credit_account_id is not null then
    select user_id, currency into v_credit_acc_user, v_credit_acc_curr
    from public.accounts where id = new.credit_account_id;
    if v_credit_acc_user is null then
      raise exception 'Credit account not found';
    end if;
    if v_credit_acc_user <> new.user_id then
      raise exception 'Credit account does not belong to this user';
    end if;
  end if;

  if new.debit_category_id is not null then
    select c.user_id, g.kind
      into v_debit_cat_user, v_debit_cat_kind
    from public.categories c
    join public.category_groups g on g.id = c.group_id
    where c.id = new.debit_category_id;
    if v_debit_cat_user is null then
      raise exception 'Debit category not found';
    end if;
    if v_debit_cat_user <> new.user_id then
      raise exception 'Debit category does not belong to this user';
    end if;
  end if;

  if new.credit_category_id is not null then
    select c.user_id, g.kind
      into v_credit_cat_user, v_credit_cat_kind
    from public.categories c
    join public.category_groups g on g.id = c.group_id
    where c.id = new.credit_category_id;
    if v_credit_cat_user is null then
      raise exception 'Credit category not found';
    end if;
    if v_credit_cat_user <> new.user_id then
      raise exception 'Credit category does not belong to this user';
    end if;
  end if;

  -- ===== 2) REGLAS POR TIPO =====
  if new.type = 'expense' then
    -- Debe usar categoría de gasto del lado debit
    if v_debit_cat_kind is distinct from 'expense' then
      raise exception 'Expense must use an EXPENSE category on the debit side';
    end if;

  elsif new.type = 'income' then
    -- Debe usar categoría de ingreso del lado credit
    if v_credit_cat_kind is distinct from 'income' then
      raise exception 'Income must use an INCOME category on the credit side';
    end if;

  elsif new.type = 'transfer' then
    -- Debe haber dos cuentas distintas
    if new.debit_account_id = new.credit_account_id then
      raise exception 'Transfer requires two different accounts';
    end if;

    -- Coherencia FX
    if v_debit_acc_curr is not null and v_credit_acc_curr is not null then
      if v_debit_acc_curr = v_credit_acc_curr then
        -- Misma moneda: no deben venir campos de FX
        if new.amount_counter is not null
           or new.fx_mode is not null
           or new.fx_rate_used is not null then
          raise exception 'Same-currency transfer must not set amount_counter/fx fields';
        end if;
      else
        -- Monedas distintas: exigir amount_counter o fx_mode
        if new.amount_counter is null and new.fx_mode is null then
          raise exception 'Cross-currency transfer: provide amount_counter or fx_mode';
        end if;
        if new.fx_rate_used is not null and new.fx_rate_used <= 0 then
          raise exception 'fx_rate_used must be > 0';
        end if;
      end if;
    end if;

  elsif new.type = 'adjustment' then
    -- Por ahora no forzamos kind específico; ya lo limita el CHECK de forma.
    null;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."validate_transaction_rules"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."validate_transaction_rules"() IS 'Business rules for `transactions`: ownership checks, category kind by type, and FX rules for transfers.';


SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "posted_at" "date" NOT NULL,
    "status" "text" DEFAULT 'cleared'::"text" NOT NULL,
    "amount" numeric(18,4) NOT NULL,
    "debit_account_id" "uuid",
    "credit_account_id" "uuid",
    "debit_category_id" "uuid",
    "credit_category_id" "uuid",
    "amount_counter" numeric(18,4),
    "fx_mode" "text",
    "fx_rate_used" numeric(18,8),
    "description" "text",
    "counterparty" "text",
    "external_id" "text",
    "attrs" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "transactions_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "transactions_fx_mode_check" CHECK (("fx_mode" = ANY (ARRAY['system'::"text", 'override'::"text"]))),
    CONSTRAINT "transactions_status_check" CHECK (("status" = ANY (ARRAY['cleared'::"text", 'pending'::"text"]))),
    CONSTRAINT "transactions_type_check" CHECK (("type" = ANY (ARRAY['expense'::"text", 'income'::"text", 'transfer'::"text", 'adjustment'::"text"]))),
    CONSTRAINT "tx_adjustment_shape" CHECK ((("type" <> 'adjustment'::"text") OR ((("debit_category_id" IS NOT NULL) AND ("credit_account_id" IS NOT NULL) AND ("debit_account_id" IS NULL) AND ("credit_category_id" IS NULL)) OR (("credit_category_id" IS NOT NULL) AND ("debit_account_id" IS NOT NULL) AND ("credit_account_id" IS NULL) AND ("debit_category_id" IS NULL))))),
    CONSTRAINT "tx_expense_shape" CHECK ((("type" <> 'expense'::"text") OR (("debit_category_id" IS NOT NULL) AND ("credit_account_id" IS NOT NULL) AND ("debit_account_id" IS NULL) AND ("credit_category_id" IS NULL)))),
    CONSTRAINT "tx_income_shape" CHECK ((("type" <> 'income'::"text") OR (("debit_account_id" IS NOT NULL) AND ("credit_category_id" IS NOT NULL) AND ("credit_account_id" IS NULL) AND ("debit_category_id" IS NULL)))),
    CONSTRAINT "tx_transfer_shape" CHECK ((("type" <> 'transfer'::"text") OR (("debit_account_id" IS NOT NULL) AND ("credit_account_id" IS NOT NULL) AND ("debit_category_id" IS NULL) AND ("credit_category_id" IS NULL) AND ("debit_account_id" <> "credit_account_id"))))
);


ALTER TABLE "public"."transactions" OWNER TO "postgres";


COMMENT ON TABLE "public"."transactions" IS 'Unified ledger of user transactions. Enforces valid shapes for expense, income, transfer, and adjustment using CHECK constraints.';



COMMENT ON COLUMN "public"."transactions"."id" IS 'Transaction ID (UUID).';



COMMENT ON COLUMN "public"."transactions"."user_id" IS 'User ID (FK to Supabase Auth). Owner of the transaction.';



COMMENT ON COLUMN "public"."transactions"."type" IS 'Transaction type: expense | income | transfer | adjustment.';



COMMENT ON COLUMN "public"."transactions"."posted_at" IS 'Accounting date used for balances and reporting.';



COMMENT ON COLUMN "public"."transactions"."status" IS 'Clearing status: cleared | pending.';



COMMENT ON COLUMN "public"."transactions"."amount" IS 'Primary amount (always positive). Sign is implied by debit/credit roles.';



COMMENT ON COLUMN "public"."transactions"."debit_account_id" IS 'Debit Account ID (receives value) when applicable.';



COMMENT ON COLUMN "public"."transactions"."credit_account_id" IS 'Credit Account ID (gives value) when applicable.';



COMMENT ON COLUMN "public"."transactions"."debit_category_id" IS 'Debit Category ID (e.g., expense/adjustment) when applicable.';



COMMENT ON COLUMN "public"."transactions"."credit_category_id" IS 'Credit Category ID (e.g., income/adjustment) when applicable.';



COMMENT ON COLUMN "public"."transactions"."amount_counter" IS 'Counter amount for cross-currency transfers (destination side).';



COMMENT ON COLUMN "public"."transactions"."fx_mode" IS 'FX mode for transfers: system | override.';



COMMENT ON COLUMN "public"."transactions"."fx_rate_used" IS 'FX rate used when fx_mode=override (amount_counter/amount).';



COMMENT ON COLUMN "public"."transactions"."description" IS 'Free-form description/memo.';



COMMENT ON COLUMN "public"."transactions"."counterparty" IS 'Merchant/beneficiary/counterparty label.';



COMMENT ON COLUMN "public"."transactions"."external_id" IS 'External import ID for idempotency.';



COMMENT ON COLUMN "public"."transactions"."attrs" IS 'Flexible JSON attributes for extensibility.';



COMMENT ON COLUMN "public"."transactions"."created_at" IS 'Row creation timestamp (UTC).';



COMMENT ON COLUMN "public"."transactions"."updated_at" IS 'Row last update timestamp (UTC).';



CREATE OR REPLACE VIEW "public"."account_ledger_v" WITH ("security_invoker"='true') AS
 SELECT "t"."user_id",
    "t"."id" AS "transaction_id",
    "t"."posted_at",
    "t"."credit_account_id" AS "account_id",
    ((- "t"."amount"))::numeric(18,4) AS "delta",
    "t"."type",
    "t"."description"
   FROM "public"."transactions" "t"
  WHERE ("t"."type" = 'expense'::"text")
UNION ALL
 SELECT "t"."user_id",
    "t"."id" AS "transaction_id",
    "t"."posted_at",
    "t"."debit_account_id" AS "account_id",
    "t"."amount" AS "delta",
    "t"."type",
    "t"."description"
   FROM "public"."transactions" "t"
  WHERE ("t"."type" = 'income'::"text")
UNION ALL
 SELECT "t"."user_id",
    "t"."id" AS "transaction_id",
    "t"."posted_at",
    "t"."credit_account_id" AS "account_id",
    ((- "t"."amount"))::numeric(18,4) AS "delta",
    "t"."type",
    "t"."description"
   FROM "public"."transactions" "t"
  WHERE ("t"."type" = 'transfer'::"text")
UNION ALL
 SELECT "t"."user_id",
    "t"."id" AS "transaction_id",
    "t"."posted_at",
    "t"."debit_account_id" AS "account_id",
    COALESCE("t"."amount_counter", "t"."amount") AS "delta",
    "t"."type",
    "t"."description"
   FROM "public"."transactions" "t"
  WHERE ("t"."type" = 'transfer'::"text")
UNION ALL
 SELECT "t"."user_id",
    "t"."id" AS "transaction_id",
    "t"."posted_at",
    "t"."credit_account_id" AS "account_id",
    ((- "t"."amount"))::numeric(18,4) AS "delta",
    "t"."type",
    "t"."description"
   FROM "public"."transactions" "t"
  WHERE (("t"."type" = 'adjustment'::"text") AND ("t"."credit_account_id" IS NOT NULL) AND ("t"."debit_category_id" IS NOT NULL))
UNION ALL
 SELECT "t"."user_id",
    "t"."id" AS "transaction_id",
    "t"."posted_at",
    "t"."debit_account_id" AS "account_id",
    "t"."amount" AS "delta",
    "t"."type",
    "t"."description"
   FROM "public"."transactions" "t"
  WHERE (("t"."type" = 'adjustment'::"text") AND ("t"."debit_account_id" IS NOT NULL) AND ("t"."credit_category_id" IS NOT NULL));


ALTER VIEW "public"."account_ledger_v" OWNER TO "postgres";


COMMENT ON VIEW "public"."account_ledger_v" IS 'Per-account deltas (+/-) derived from transactions. Uses security_invoker so RLS applies.';



CREATE TABLE IF NOT EXISTS "public"."accounts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type_code" "text" NOT NULL,
    "currency" character(3) NOT NULL,
    "name" "text" NOT NULL,
    "institution_name" "text",
    "notes" "text",
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "opened_at" "date",
    "closed_at" "date",
    "number_last4" "text",
    "attrs" "jsonb",
    "sync_provider" "text" DEFAULT 'manual'::"text" NOT NULL,
    "external_id" "text",
    "sync_status" "text",
    "sync_last_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "accounts_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'closed'::"text"])))
);


ALTER TABLE "public"."accounts" OWNER TO "postgres";


COMMENT ON TABLE "public"."accounts" IS 'Accounts owned by each user. Used to group transactions and calculate balances.';



COMMENT ON COLUMN "public"."accounts"."id" IS 'Account ID (UUID). Primary key.';



COMMENT ON COLUMN "public"."accounts"."user_id" IS 'User ID (FK to Supabase Auth). Owner of the account.';



COMMENT ON COLUMN "public"."accounts"."type_code" IS 'Account Type Code (FK to account_types). Defines kind = asset/liability.';



COMMENT ON COLUMN "public"."accounts"."currency" IS 'Currency Code (ISO 4217). Base currency of the account.';



COMMENT ON COLUMN "public"."accounts"."name" IS 'Display name of the account (e.g., Santander ARS, Wallet USD).';



COMMENT ON COLUMN "public"."accounts"."institution_name" IS 'Institution or provider of the account (e.g., Santander, Ualá).';



COMMENT ON COLUMN "public"."accounts"."notes" IS 'Optional notes entered by the user.';



COMMENT ON COLUMN "public"."accounts"."status" IS 'Status of the account: active | inactive | closed.';



COMMENT ON COLUMN "public"."accounts"."opened_at" IS 'Date when the account was opened.';



COMMENT ON COLUMN "public"."accounts"."closed_at" IS 'Date when the account was closed (if status=closed).';



COMMENT ON COLUMN "public"."accounts"."number_last4" IS 'Last 4 digits or short reference of the account.';



COMMENT ON COLUMN "public"."accounts"."attrs" IS 'Flexible JSON attributes (per type).';



COMMENT ON COLUMN "public"."accounts"."sync_provider" IS 'External sync provider (if connected).';



COMMENT ON COLUMN "public"."accounts"."external_id" IS 'External ID from provider (if connected).';



COMMENT ON COLUMN "public"."accounts"."sync_status" IS 'Last sync status (e.g., success, error).';



COMMENT ON COLUMN "public"."accounts"."sync_last_at" IS 'Timestamp of last sync.';



COMMENT ON COLUMN "public"."accounts"."created_at" IS 'Row creation timestamp (UTC).';



COMMENT ON COLUMN "public"."accounts"."updated_at" IS 'Row last update timestamp (UTC).';



CREATE OR REPLACE VIEW "public"."account_balances_v" WITH ("security_invoker"='true') AS
 SELECT "a"."user_id",
    "a"."id" AS "account_id",
    "a"."name" AS "account_name",
    "a"."currency",
    (COALESCE("sum"("l"."delta"), (0)::numeric))::numeric(18,4) AS "balance"
   FROM ("public"."accounts" "a"
     LEFT JOIN "public"."account_ledger_v" "l" ON ((("l"."account_id" = "a"."id") AND ("l"."user_id" = "a"."user_id"))))
  GROUP BY "a"."user_id", "a"."id", "a"."name", "a"."currency";


ALTER VIEW "public"."account_balances_v" OWNER TO "postgres";


COMMENT ON VIEW "public"."account_balances_v" IS 'Current balance per account (sum of account_ledger_v). Join-friendly with accounts.';



CREATE TABLE IF NOT EXISTS "public"."account_types" (
    "type_code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "kind" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "account_types_kind_check" CHECK (("kind" = ANY (ARRAY['asset'::"text", 'liability'::"text"])))
);


ALTER TABLE "public"."account_types" OWNER TO "postgres";


COMMENT ON TABLE "public"."account_types" IS 'Catalog of allowed account types (Cash, Bank Account, Wallet, Credit Card, Loan, Real Estate, Vehicle, Other).';



COMMENT ON COLUMN "public"."account_types"."type_code" IS 'Account Type Code (stable key, e.g., bank_account, wallet).';



COMMENT ON COLUMN "public"."account_types"."name" IS 'Account Type Name (display name, e.g., Bank Account).';



COMMENT ON COLUMN "public"."account_types"."kind" IS 'Kind of account: asset or liability.';



COMMENT ON COLUMN "public"."account_types"."description" IS 'Description of the account type.';



COMMENT ON COLUMN "public"."account_types"."created_at" IS 'Row creation timestamp (UTC).';



CREATE OR REPLACE VIEW "public"."adjustments_v" WITH ("security_invoker"='true') AS
 SELECT "id",
    "user_id",
    "type",
    "posted_at",
    "status",
    "amount",
    "debit_account_id",
    "credit_account_id",
    "debit_category_id",
    "credit_category_id",
    "amount_counter",
    "fx_mode",
    "fx_rate_used",
    "description",
    "counterparty",
    "external_id",
    "attrs",
    "created_at",
    "updated_at"
   FROM "public"."transactions"
  WHERE ("type" = 'adjustment'::"text");


ALTER VIEW "public"."adjustments_v" OWNER TO "postgres";


COMMENT ON VIEW "public"."adjustments_v" IS 'View of ADJUSTMENT transactions. Uses security_invoker so RLS on public.transactions applies.';



COMMENT ON COLUMN "public"."adjustments_v"."id" IS 'Transaction ID (UUID).';



COMMENT ON COLUMN "public"."adjustments_v"."user_id" IS 'User ID (FK to Supabase Auth). Owner of the transaction.';



COMMENT ON COLUMN "public"."adjustments_v"."type" IS 'Transaction type: expense | income | transfer | adjustment.';



COMMENT ON COLUMN "public"."adjustments_v"."posted_at" IS 'Accounting date used for balances and reporting.';



COMMENT ON COLUMN "public"."adjustments_v"."status" IS 'Clearing status: cleared | pending.';



COMMENT ON COLUMN "public"."adjustments_v"."amount" IS 'Primary amount (always positive). Sign is implied by debit/credit roles.';



COMMENT ON COLUMN "public"."adjustments_v"."debit_account_id" IS 'Debit Account ID (receives value) when applicable.';



COMMENT ON COLUMN "public"."adjustments_v"."credit_account_id" IS 'Credit Account ID (gives value) when applicable.';



COMMENT ON COLUMN "public"."adjustments_v"."debit_category_id" IS 'Debit Category ID (e.g., expense/adjustment) when applicable.';



COMMENT ON COLUMN "public"."adjustments_v"."credit_category_id" IS 'Credit Category ID (e.g., income/adjustment) when applicable.';



COMMENT ON COLUMN "public"."adjustments_v"."amount_counter" IS 'Counter amount for cross-currency transfers (destination side).';



COMMENT ON COLUMN "public"."adjustments_v"."fx_mode" IS 'FX mode for transfers: system | override.';



COMMENT ON COLUMN "public"."adjustments_v"."fx_rate_used" IS 'FX rate used when fx_mode=override (amount_counter/amount).';



COMMENT ON COLUMN "public"."adjustments_v"."description" IS 'Free-form description/memo.';



COMMENT ON COLUMN "public"."adjustments_v"."counterparty" IS 'Merchant/beneficiary/counterparty label.';



COMMENT ON COLUMN "public"."adjustments_v"."external_id" IS 'External import ID for idempotency.';



COMMENT ON COLUMN "public"."adjustments_v"."attrs" IS 'Flexible JSON attributes for extensibility.';



COMMENT ON COLUMN "public"."adjustments_v"."created_at" IS 'Row creation timestamp (UTC).';



COMMENT ON COLUMN "public"."adjustments_v"."updated_at" IS 'Row last update timestamp (UTC).';



CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "group_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


COMMENT ON TABLE "public"."categories" IS 'Per-user leaf Categories inside a Group. Only leaf categories are assigned to transactions.';



COMMENT ON COLUMN "public"."categories"."id" IS 'Category ID (UUID).';



COMMENT ON COLUMN "public"."categories"."user_id" IS 'User ID (FK to Supabase Auth).';



COMMENT ON COLUMN "public"."categories"."group_id" IS 'Group ID (FK to category_groups).';



COMMENT ON COLUMN "public"."categories"."name" IS 'Category name (e.g., Alquiler, Nafta, Sueldo).';



COMMENT ON COLUMN "public"."categories"."is_active" IS 'Whether the category is active (can be hidden without deleting).';



COMMENT ON COLUMN "public"."categories"."created_at" IS 'Row creation timestamp (UTC).';



COMMENT ON COLUMN "public"."categories"."updated_at" IS 'Row last update timestamp (UTC).';



CREATE TABLE IF NOT EXISTS "public"."category_group_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "kind" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "sort_order" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "category_group_templates_kind_check" CHECK (("kind" = ANY (ARRAY['expense'::"text", 'income'::"text"])))
);


ALTER TABLE "public"."category_group_templates" OWNER TO "postgres";


COMMENT ON TABLE "public"."category_group_templates" IS 'System catalog: suggested category groups for onboarding (no User ID).';



COMMENT ON COLUMN "public"."category_group_templates"."id" IS 'Group Template ID (UUID).';



COMMENT ON COLUMN "public"."category_group_templates"."name" IS 'Group name (e.g., Casa, Auto, Ocio).';



COMMENT ON COLUMN "public"."category_group_templates"."kind" IS 'Group kind: expense | income.';



COMMENT ON COLUMN "public"."category_group_templates"."is_active" IS 'Whether the template is active and should be shown for onboarding.';



COMMENT ON COLUMN "public"."category_group_templates"."sort_order" IS 'Optional UI sort order.';



COMMENT ON COLUMN "public"."category_group_templates"."created_at" IS 'Row creation timestamp (UTC).';



COMMENT ON COLUMN "public"."category_group_templates"."updated_at" IS 'Row last update timestamp (UTC).';



CREATE TABLE IF NOT EXISTS "public"."category_groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "kind" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "category_groups_kind_check" CHECK (("kind" = ANY (ARRAY['expense'::"text", 'income'::"text"])))
);


ALTER TABLE "public"."category_groups" OWNER TO "postgres";


COMMENT ON TABLE "public"."category_groups" IS 'Per-user Category Groups (folders). Each row belongs to one user. Typical examples: Casa, Auto, Ocio, Otros (Gastos), Otros (Ingresos).';



COMMENT ON COLUMN "public"."category_groups"."id" IS 'Group ID (UUID).';



COMMENT ON COLUMN "public"."category_groups"."user_id" IS 'User ID (FK to Supabase Auth).';



COMMENT ON COLUMN "public"."category_groups"."name" IS 'Group name (e.g., Casa, Auto, Ocio).';



COMMENT ON COLUMN "public"."category_groups"."kind" IS 'Group kind: expense | income.';



COMMENT ON COLUMN "public"."category_groups"."is_active" IS 'Whether the group is active (can be hidden without deleting).';



COMMENT ON COLUMN "public"."category_groups"."created_at" IS 'Row creation timestamp (UTC).';



COMMENT ON COLUMN "public"."category_groups"."updated_at" IS 'Row last update timestamp (UTC).';



CREATE TABLE IF NOT EXISTS "public"."category_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_template_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "sort_order" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."category_templates" OWNER TO "postgres";


COMMENT ON TABLE "public"."category_templates" IS 'System catalog: suggested leaf categories for onboarding (no User ID).';



COMMENT ON COLUMN "public"."category_templates"."id" IS 'Category Template ID (UUID).';



COMMENT ON COLUMN "public"."category_templates"."group_template_id" IS 'Parent Group Template ID.';



COMMENT ON COLUMN "public"."category_templates"."name" IS 'Category name (e.g., Alquiler, Nafta).';



COMMENT ON COLUMN "public"."category_templates"."is_active" IS 'Whether the template is active and should be shown for onboarding.';



COMMENT ON COLUMN "public"."category_templates"."sort_order" IS 'Optional UI sort order.';



COMMENT ON COLUMN "public"."category_templates"."created_at" IS 'Row creation timestamp (UTC).';



COMMENT ON COLUMN "public"."category_templates"."updated_at" IS 'Row last update timestamp (UTC).';



CREATE TABLE IF NOT EXISTS "public"."currencies" (
    "code" character(3) NOT NULL,
    "name" "text" NOT NULL,
    "symbol" "text",
    "decimals" integer DEFAULT 2 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."currencies" OWNER TO "postgres";


COMMENT ON TABLE "public"."currencies" IS 'Global catalog of ISO-4217 currencies used to validate and format monetary amounts. Read-only for app users; maintained by backend jobs.';



COMMENT ON COLUMN "public"."currencies"."code" IS 'ISO-4217 currency code (3 uppercase letters), e.g., USD, ARS, EUR. Primary key.';



COMMENT ON COLUMN "public"."currencies"."name" IS 'Human-readable currency name, e.g., "US Dollar".';



COMMENT ON COLUMN "public"."currencies"."symbol" IS 'Display symbol, e.g., $, €, R$. Optional.';



COMMENT ON COLUMN "public"."currencies"."decimals" IS 'Number of fractional digits for the currency (e.g., 2 for USD/EUR, 0 for ARS).';



COMMENT ON COLUMN "public"."currencies"."is_active" IS 'Whether this currency is available for selection in the app.';



COMMENT ON COLUMN "public"."currencies"."created_at" IS 'Timestamp when the row was created (UTC).';



CREATE OR REPLACE VIEW "public"."expenses_v" WITH ("security_invoker"='true') AS
 SELECT "id",
    "user_id",
    "type",
    "posted_at",
    "status",
    "amount",
    "debit_account_id",
    "credit_account_id",
    "debit_category_id",
    "credit_category_id",
    "amount_counter",
    "fx_mode",
    "fx_rate_used",
    "description",
    "counterparty",
    "external_id",
    "attrs",
    "created_at",
    "updated_at"
   FROM "public"."transactions"
  WHERE ("type" = 'expense'::"text");


ALTER VIEW "public"."expenses_v" OWNER TO "postgres";


COMMENT ON VIEW "public"."expenses_v" IS 'View of EXPENSE transactions. Uses security_invoker so RLS on public.transactions applies.';



COMMENT ON COLUMN "public"."expenses_v"."id" IS 'Transaction ID (UUID).';



COMMENT ON COLUMN "public"."expenses_v"."user_id" IS 'User ID (FK to Supabase Auth). Owner of the transaction.';



COMMENT ON COLUMN "public"."expenses_v"."type" IS 'Transaction type: expense | income | transfer | adjustment.';



COMMENT ON COLUMN "public"."expenses_v"."posted_at" IS 'Accounting date used for balances and reporting.';



COMMENT ON COLUMN "public"."expenses_v"."status" IS 'Clearing status: cleared | pending.';



COMMENT ON COLUMN "public"."expenses_v"."amount" IS 'Primary amount (always positive). Sign is implied by debit/credit roles.';



COMMENT ON COLUMN "public"."expenses_v"."debit_account_id" IS 'Debit Account ID (receives value) when applicable.';



COMMENT ON COLUMN "public"."expenses_v"."credit_account_id" IS 'Credit Account ID (gives value) when applicable.';



COMMENT ON COLUMN "public"."expenses_v"."debit_category_id" IS 'Debit Category ID (e.g., expense/adjustment) when applicable.';



COMMENT ON COLUMN "public"."expenses_v"."credit_category_id" IS 'Credit Category ID (e.g., income/adjustment) when applicable.';



COMMENT ON COLUMN "public"."expenses_v"."amount_counter" IS 'Counter amount for cross-currency transfers (destination side).';



COMMENT ON COLUMN "public"."expenses_v"."fx_mode" IS 'FX mode for transfers: system | override.';



COMMENT ON COLUMN "public"."expenses_v"."fx_rate_used" IS 'FX rate used when fx_mode=override (amount_counter/amount).';



COMMENT ON COLUMN "public"."expenses_v"."description" IS 'Free-form description/memo.';



COMMENT ON COLUMN "public"."expenses_v"."counterparty" IS 'Merchant/beneficiary/counterparty label.';



COMMENT ON COLUMN "public"."expenses_v"."external_id" IS 'External import ID for idempotency.';



COMMENT ON COLUMN "public"."expenses_v"."attrs" IS 'Flexible JSON attributes for extensibility.';



COMMENT ON COLUMN "public"."expenses_v"."created_at" IS 'Row creation timestamp (UTC).';



COMMENT ON COLUMN "public"."expenses_v"."updated_at" IS 'Row last update timestamp (UTC).';



CREATE TABLE IF NOT EXISTS "public"."fx_rates" (
    "base" character(3) NOT NULL,
    "quote" character(3) NOT NULL,
    "as_of_date" "date" NOT NULL,
    "rate" numeric(18,6) NOT NULL,
    "source" "text" DEFAULT 'dolarapi'::"text" NOT NULL,
    "fetched_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "fx_base_quote_diff" CHECK (("base" <> "quote")),
    CONSTRAINT "fx_rates_rate_check" CHECK (("rate" > (0)::numeric))
);


ALTER TABLE "public"."fx_rates" OWNER TO "postgres";


COMMENT ON TABLE "public"."fx_rates" IS 'Daily foreign exchange rates. One row per (base, quote, date). Read-only for app users; insertions via backend jobs.';



COMMENT ON COLUMN "public"."fx_rates"."base" IS 'Base currency (ISO-4217). Rate expresses 1 base = rate quote.';



COMMENT ON COLUMN "public"."fx_rates"."quote" IS 'Quote currency (ISO-4217).';



COMMENT ON COLUMN "public"."fx_rates"."as_of_date" IS 'Date the rate applies to (UTC).';



COMMENT ON COLUMN "public"."fx_rates"."rate" IS 'Numeric exchange rate: 1 base = rate quote.';



COMMENT ON COLUMN "public"."fx_rates"."source" IS 'Provider/source of the rate (e.g., dolarapi, ecb).';



COMMENT ON COLUMN "public"."fx_rates"."fetched_at" IS 'Timestamp when this row was inserted (UTC).';



CREATE OR REPLACE VIEW "public"."incomes_v" WITH ("security_invoker"='true') AS
 SELECT "id",
    "user_id",
    "type",
    "posted_at",
    "status",
    "amount",
    "debit_account_id",
    "credit_account_id",
    "debit_category_id",
    "credit_category_id",
    "amount_counter",
    "fx_mode",
    "fx_rate_used",
    "description",
    "counterparty",
    "external_id",
    "attrs",
    "created_at",
    "updated_at"
   FROM "public"."transactions"
  WHERE ("type" = 'income'::"text");


ALTER VIEW "public"."incomes_v" OWNER TO "postgres";


COMMENT ON VIEW "public"."incomes_v" IS 'View of INCOME transactions. Uses security_invoker so RLS on public.transactions applies.';



COMMENT ON COLUMN "public"."incomes_v"."id" IS 'Transaction ID (UUID).';



COMMENT ON COLUMN "public"."incomes_v"."user_id" IS 'User ID (FK to Supabase Auth). Owner of the transaction.';



COMMENT ON COLUMN "public"."incomes_v"."type" IS 'Transaction type: expense | income | transfer | adjustment.';



COMMENT ON COLUMN "public"."incomes_v"."posted_at" IS 'Accounting date used for balances and reporting.';



COMMENT ON COLUMN "public"."incomes_v"."status" IS 'Clearing status: cleared | pending.';



COMMENT ON COLUMN "public"."incomes_v"."amount" IS 'Primary amount (always positive). Sign is implied by debit/credit roles.';



COMMENT ON COLUMN "public"."incomes_v"."debit_account_id" IS 'Debit Account ID (receives value) when applicable.';



COMMENT ON COLUMN "public"."incomes_v"."credit_account_id" IS 'Credit Account ID (gives value) when applicable.';



COMMENT ON COLUMN "public"."incomes_v"."debit_category_id" IS 'Debit Category ID (e.g., expense/adjustment) when applicable.';



COMMENT ON COLUMN "public"."incomes_v"."credit_category_id" IS 'Credit Category ID (e.g., income/adjustment) when applicable.';



COMMENT ON COLUMN "public"."incomes_v"."amount_counter" IS 'Counter amount for cross-currency transfers (destination side).';



COMMENT ON COLUMN "public"."incomes_v"."fx_mode" IS 'FX mode for transfers: system | override.';



COMMENT ON COLUMN "public"."incomes_v"."fx_rate_used" IS 'FX rate used when fx_mode=override (amount_counter/amount).';



COMMENT ON COLUMN "public"."incomes_v"."description" IS 'Free-form description/memo.';



COMMENT ON COLUMN "public"."incomes_v"."counterparty" IS 'Merchant/beneficiary/counterparty label.';



COMMENT ON COLUMN "public"."incomes_v"."external_id" IS 'External import ID for idempotency.';



COMMENT ON COLUMN "public"."incomes_v"."attrs" IS 'Flexible JSON attributes for extensibility.';



COMMENT ON COLUMN "public"."incomes_v"."created_at" IS 'Row creation timestamp (UTC).';



COMMENT ON COLUMN "public"."incomes_v"."updated_at" IS 'Row last update timestamp (UTC).';



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "user_id" "uuid" NOT NULL,
    "display_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON TABLE "public"."profiles" IS 'Basic user profile linked 1:1 with Supabase Auth users. Stores display name and creation date. No preferences.';



COMMENT ON COLUMN "public"."profiles"."user_id" IS 'Unique identifier from Supabase Auth (FK). Primary key. One row per user.';



COMMENT ON COLUMN "public"."profiles"."display_name" IS 'User-chosen display name shown in the UI. Optional.';



COMMENT ON COLUMN "public"."profiles"."created_at" IS 'Timestamp when the profile was created (UTC).';



CREATE OR REPLACE VIEW "public"."transfers_v" WITH ("security_invoker"='true') AS
 SELECT "id",
    "user_id",
    "type",
    "posted_at",
    "status",
    "amount",
    "debit_account_id",
    "credit_account_id",
    "debit_category_id",
    "credit_category_id",
    "amount_counter",
    "fx_mode",
    "fx_rate_used",
    "description",
    "counterparty",
    "external_id",
    "attrs",
    "created_at",
    "updated_at"
   FROM "public"."transactions"
  WHERE ("type" = 'transfer'::"text");


ALTER VIEW "public"."transfers_v" OWNER TO "postgres";


COMMENT ON VIEW "public"."transfers_v" IS 'View of TRANSFER transactions. Uses security_invoker so RLS on public.transactions applies.';



COMMENT ON COLUMN "public"."transfers_v"."id" IS 'Transaction ID (UUID).';



COMMENT ON COLUMN "public"."transfers_v"."user_id" IS 'User ID (FK to Supabase Auth). Owner of the transaction.';



COMMENT ON COLUMN "public"."transfers_v"."type" IS 'Transaction type: expense | income | transfer | adjustment.';



COMMENT ON COLUMN "public"."transfers_v"."posted_at" IS 'Accounting date used for balances and reporting.';



COMMENT ON COLUMN "public"."transfers_v"."status" IS 'Clearing status: cleared | pending.';



COMMENT ON COLUMN "public"."transfers_v"."amount" IS 'Primary amount (always positive). Sign is implied by debit/credit roles.';



COMMENT ON COLUMN "public"."transfers_v"."debit_account_id" IS 'Debit Account ID (receives value) when applicable.';



COMMENT ON COLUMN "public"."transfers_v"."credit_account_id" IS 'Credit Account ID (gives value) when applicable.';



COMMENT ON COLUMN "public"."transfers_v"."debit_category_id" IS 'Debit Category ID (e.g., expense/adjustment) when applicable.';



COMMENT ON COLUMN "public"."transfers_v"."credit_category_id" IS 'Credit Category ID (e.g., income/adjustment) when applicable.';



COMMENT ON COLUMN "public"."transfers_v"."amount_counter" IS 'Counter amount for cross-currency transfers (destination side).';



COMMENT ON COLUMN "public"."transfers_v"."fx_mode" IS 'FX mode for transfers: system | override.';



COMMENT ON COLUMN "public"."transfers_v"."fx_rate_used" IS 'FX rate used when fx_mode=override (amount_counter/amount).';



COMMENT ON COLUMN "public"."transfers_v"."description" IS 'Free-form description/memo.';



COMMENT ON COLUMN "public"."transfers_v"."counterparty" IS 'Merchant/beneficiary/counterparty label.';



COMMENT ON COLUMN "public"."transfers_v"."external_id" IS 'External import ID for idempotency.';



COMMENT ON COLUMN "public"."transfers_v"."attrs" IS 'Flexible JSON attributes for extensibility.';



COMMENT ON COLUMN "public"."transfers_v"."created_at" IS 'Row creation timestamp (UTC).';



COMMENT ON COLUMN "public"."transfers_v"."updated_at" IS 'Row last update timestamp (UTC).';



CREATE TABLE IF NOT EXISTS "public"."user_settings" (
    "user_id" "uuid" NOT NULL,
    "base_currency" character(3),
    "locale" "text" DEFAULT 'es-AR'::"text" NOT NULL,
    "theme" "text" DEFAULT 'light'::"text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_settings" OWNER TO "postgres";


COMMENT ON TABLE "public"."user_settings" IS 'User preferences table. Stores base currency, locale, and UI theme. Separated from profile for modularity.';



COMMENT ON COLUMN "public"."user_settings"."user_id" IS 'Owner user (FK to Supabase Auth). Primary key. One row per user.';



COMMENT ON COLUMN "public"."user_settings"."base_currency" IS 'Preferred reporting currency (ISO-4217 code, e.g., ARS, USD, EUR). Nullable until set.';



COMMENT ON COLUMN "public"."user_settings"."locale" IS 'Locale code for formatting dates and numbers (e.g., es-AR, en-US). Default: es-AR.';



COMMENT ON COLUMN "public"."user_settings"."theme" IS 'UI theme preference (e.g., light, dark). Default: light.';



COMMENT ON COLUMN "public"."user_settings"."updated_at" IS 'Timestamp of the last update (UTC).';



ALTER TABLE ONLY "public"."account_types"
    ADD CONSTRAINT "account_types_pkey" PRIMARY KEY ("type_code");



ALTER TABLE ONLY "public"."accounts"
    ADD CONSTRAINT "accounts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_unique_per_user" UNIQUE ("user_id", "group_id", "name");



ALTER TABLE ONLY "public"."category_group_templates"
    ADD CONSTRAINT "category_group_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."category_groups"
    ADD CONSTRAINT "category_groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."category_groups"
    ADD CONSTRAINT "category_groups_unique_per_user" UNIQUE ("user_id", "name", "kind");



ALTER TABLE ONLY "public"."category_templates"
    ADD CONSTRAINT "category_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."category_group_templates"
    ADD CONSTRAINT "cgt_unique" UNIQUE ("name", "kind");



ALTER TABLE ONLY "public"."category_templates"
    ADD CONSTRAINT "ct_unique" UNIQUE ("group_template_id", "name");



ALTER TABLE ONLY "public"."currencies"
    ADD CONSTRAINT "currencies_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."fx_rates"
    ADD CONSTRAINT "fx_rates_pkey" PRIMARY KEY ("base", "quote", "as_of_date");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_external_unique" UNIQUE ("user_id", "external_id");



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_settings"
    ADD CONSTRAINT "user_settings_pkey" PRIMARY KEY ("user_id");



CREATE INDEX "idx_accounts_currency" ON "public"."accounts" USING "btree" ("currency");



CREATE INDEX "idx_accounts_type" ON "public"."accounts" USING "btree" ("type_code");



CREATE INDEX "idx_accounts_user" ON "public"."accounts" USING "btree" ("user_id");



CREATE INDEX "idx_accounts_user_status" ON "public"."accounts" USING "btree" ("user_id", "status");



CREATE INDEX "idx_categories_user_group" ON "public"."categories" USING "btree" ("user_id", "group_id");



CREATE INDEX "idx_cgroups_user_kind" ON "public"."category_groups" USING "btree" ("user_id", "kind");



CREATE INDEX "idx_tx_adjustment_date" ON "public"."transactions" USING "btree" ("posted_at") WHERE ("type" = 'adjustment'::"text");



CREATE INDEX "idx_tx_expense_date" ON "public"."transactions" USING "btree" ("posted_at") WHERE ("type" = 'expense'::"text");



CREATE INDEX "idx_tx_income_date" ON "public"."transactions" USING "btree" ("posted_at") WHERE ("type" = 'income'::"text");



CREATE INDEX "idx_tx_transfer_date" ON "public"."transactions" USING "btree" ("posted_at") WHERE ("type" = 'transfer'::"text");



CREATE INDEX "idx_tx_user_credit_acc" ON "public"."transactions" USING "btree" ("user_id", "credit_account_id") WHERE ("credit_account_id" IS NOT NULL);



CREATE INDEX "idx_tx_user_credit_cat" ON "public"."transactions" USING "btree" ("user_id", "credit_category_id") WHERE ("credit_category_id" IS NOT NULL);



CREATE INDEX "idx_tx_user_date" ON "public"."transactions" USING "btree" ("user_id", "posted_at");



CREATE INDEX "idx_tx_user_debit_acc" ON "public"."transactions" USING "btree" ("user_id", "debit_account_id") WHERE ("debit_account_id" IS NOT NULL);



CREATE INDEX "idx_tx_user_debit_cat" ON "public"."transactions" USING "btree" ("user_id", "debit_category_id") WHERE ("debit_category_id" IS NOT NULL);



CREATE INDEX "idx_tx_user_type_date" ON "public"."transactions" USING "btree" ("user_id", "type", "posted_at");



CREATE OR REPLACE TRIGGER "trg_accounts_updated_at" BEFORE UPDATE ON "public"."accounts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_categories_updated_at" BEFORE UPDATE ON "public"."categories" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_cgroups_updated_at" BEFORE UPDATE ON "public"."category_groups" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_cgt_updated_at" BEFORE UPDATE ON "public"."category_group_templates" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_ct_updated_at" BEFORE UPDATE ON "public"."category_templates" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_transactions_updated_at" BEFORE UPDATE ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_transactions_validate" BEFORE INSERT OR UPDATE ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."validate_transaction_rules"();



ALTER TABLE ONLY "public"."accounts"
    ADD CONSTRAINT "accounts_currency_fkey" FOREIGN KEY ("currency") REFERENCES "public"."currencies"("code") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."accounts"
    ADD CONSTRAINT "accounts_type_code_fkey" FOREIGN KEY ("type_code") REFERENCES "public"."account_types"("type_code") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."accounts"
    ADD CONSTRAINT "accounts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."category_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."category_groups"
    ADD CONSTRAINT "category_groups_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."category_templates"
    ADD CONSTRAINT "category_templates_group_template_id_fkey" FOREIGN KEY ("group_template_id") REFERENCES "public"."category_group_templates"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_settings"
    ADD CONSTRAINT "fk_user_settings_currency" FOREIGN KEY ("base_currency") REFERENCES "public"."currencies"("code") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."fx_rates"
    ADD CONSTRAINT "fx_rates_base_fkey" FOREIGN KEY ("base") REFERENCES "public"."currencies"("code") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."fx_rates"
    ADD CONSTRAINT "fx_rates_quote_fkey" FOREIGN KEY ("quote") REFERENCES "public"."currencies"("code") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_credit_account_id_fkey" FOREIGN KEY ("credit_account_id") REFERENCES "public"."accounts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_credit_category_id_fkey" FOREIGN KEY ("credit_category_id") REFERENCES "public"."categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_debit_account_id_fkey" FOREIGN KEY ("debit_account_id") REFERENCES "public"."accounts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_debit_category_id_fkey" FOREIGN KEY ("debit_category_id") REFERENCES "public"."categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_settings"
    ADD CONSTRAINT "user_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE "public"."account_types" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "account_types_read_auth" ON "public"."account_types" FOR SELECT USING (true);



ALTER TABLE "public"."accounts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accounts_delete_own" ON "public"."accounts" FOR DELETE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "accounts_insert_own" ON "public"."accounts" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "accounts_select_own" ON "public"."accounts" FOR SELECT USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "accounts_update_own" ON "public"."accounts" FOR UPDATE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "categories_delete_own" ON "public"."categories" FOR DELETE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "categories_insert_own" ON "public"."categories" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "categories_select_own" ON "public"."categories" FOR SELECT USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "categories_update_own" ON "public"."categories" FOR UPDATE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."category_group_templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."category_groups" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."category_templates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "cgroups_delete_own" ON "public"."category_groups" FOR DELETE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "cgroups_insert_own" ON "public"."category_groups" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "cgroups_select_own" ON "public"."category_groups" FOR SELECT USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "cgroups_update_own" ON "public"."category_groups" FOR UPDATE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "cgt_select_all" ON "public"."category_group_templates" FOR SELECT USING (true);



CREATE POLICY "ct_select_all" ON "public"."category_templates" FOR SELECT USING (true);



ALTER TABLE "public"."currencies" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "currencies_read_auth" ON "public"."currencies" FOR SELECT USING (true);



ALTER TABLE "public"."fx_rates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "fx_read_auth" ON "public"."fx_rates" FOR SELECT USING (true);



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_insert_own" ON "public"."profiles" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "profiles_select_own" ON "public"."profiles" FOR SELECT USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "profiles_update_own" ON "public"."profiles" FOR UPDATE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "settings_insert_own" ON "public"."user_settings" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "settings_select_own" ON "public"."user_settings" FOR SELECT USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "settings_update_own" ON "public"."user_settings" FOR UPDATE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."transactions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tx_delete_own" ON "public"."transactions" FOR DELETE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "tx_insert_own" ON "public"."transactions" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "tx_select_own" ON "public"."transactions" FOR SELECT USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "tx_update_own" ON "public"."transactions" FOR UPDATE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."user_settings" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."_resolve_user"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."_resolve_user"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."_resolve_user"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_expense"("p_user_id" "uuid", "p_posted_at" "date", "p_account_id" "uuid", "p_category_id" "uuid", "p_amount" numeric, "p_description" "text", "p_counterparty" "text", "p_external_id" "text", "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."add_expense"("p_user_id" "uuid", "p_posted_at" "date", "p_account_id" "uuid", "p_category_id" "uuid", "p_amount" numeric, "p_description" "text", "p_counterparty" "text", "p_external_id" "text", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_expense"("p_user_id" "uuid", "p_posted_at" "date", "p_account_id" "uuid", "p_category_id" "uuid", "p_amount" numeric, "p_description" "text", "p_counterparty" "text", "p_external_id" "text", "p_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_income"("p_user_id" "uuid", "p_posted_at" "date", "p_account_id" "uuid", "p_category_id" "uuid", "p_amount" numeric, "p_description" "text", "p_counterparty" "text", "p_external_id" "text", "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."add_income"("p_user_id" "uuid", "p_posted_at" "date", "p_account_id" "uuid", "p_category_id" "uuid", "p_amount" numeric, "p_description" "text", "p_counterparty" "text", "p_external_id" "text", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_income"("p_user_id" "uuid", "p_posted_at" "date", "p_account_id" "uuid", "p_category_id" "uuid", "p_amount" numeric, "p_description" "text", "p_counterparty" "text", "p_external_id" "text", "p_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_transfer"("p_user_id" "uuid", "p_posted_at" "date", "p_from_account_id" "uuid", "p_to_account_id" "uuid", "p_amount_out" numeric, "p_amount_in" numeric, "p_fx_mode" "text", "p_fx_rate_used" numeric, "p_description" "text", "p_external_id" "text", "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."add_transfer"("p_user_id" "uuid", "p_posted_at" "date", "p_from_account_id" "uuid", "p_to_account_id" "uuid", "p_amount_out" numeric, "p_amount_in" numeric, "p_fx_mode" "text", "p_fx_rate_used" numeric, "p_description" "text", "p_external_id" "text", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_transfer"("p_user_id" "uuid", "p_posted_at" "date", "p_from_account_id" "uuid", "p_to_account_id" "uuid", "p_amount_out" numeric, "p_amount_in" numeric, "p_fx_mode" "text", "p_fx_rate_used" numeric, "p_description" "text", "p_external_id" "text", "p_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."clone_category_templates_for_user"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."clone_category_templates_for_user"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."clone_category_templates_for_user"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."clone_selected_category_templates_for_user"("p_user_id" "uuid", "p_template_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."clone_selected_category_templates_for_user"("p_user_id" "uuid", "p_template_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."clone_selected_category_templates_for_user"("p_user_id" "uuid", "p_template_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_other_groups"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_other_groups"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_other_groups"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_fx_rates"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_fx_rates"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_fx_rates"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_transaction_rules"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_transaction_rules"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_transaction_rules"() TO "service_role";



GRANT ALL ON TABLE "public"."transactions" TO "anon";
GRANT ALL ON TABLE "public"."transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."transactions" TO "service_role";



GRANT ALL ON TABLE "public"."account_ledger_v" TO "anon";
GRANT ALL ON TABLE "public"."account_ledger_v" TO "authenticated";
GRANT ALL ON TABLE "public"."account_ledger_v" TO "service_role";



GRANT ALL ON TABLE "public"."accounts" TO "anon";
GRANT ALL ON TABLE "public"."accounts" TO "authenticated";
GRANT ALL ON TABLE "public"."accounts" TO "service_role";



GRANT ALL ON TABLE "public"."account_balances_v" TO "anon";
GRANT ALL ON TABLE "public"."account_balances_v" TO "authenticated";
GRANT ALL ON TABLE "public"."account_balances_v" TO "service_role";



GRANT ALL ON TABLE "public"."account_types" TO "anon";
GRANT ALL ON TABLE "public"."account_types" TO "authenticated";
GRANT ALL ON TABLE "public"."account_types" TO "service_role";



GRANT ALL ON TABLE "public"."adjustments_v" TO "anon";
GRANT ALL ON TABLE "public"."adjustments_v" TO "authenticated";
GRANT ALL ON TABLE "public"."adjustments_v" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."category_group_templates" TO "anon";
GRANT ALL ON TABLE "public"."category_group_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."category_group_templates" TO "service_role";



GRANT ALL ON TABLE "public"."category_groups" TO "anon";
GRANT ALL ON TABLE "public"."category_groups" TO "authenticated";
GRANT ALL ON TABLE "public"."category_groups" TO "service_role";



GRANT ALL ON TABLE "public"."category_templates" TO "anon";
GRANT ALL ON TABLE "public"."category_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."category_templates" TO "service_role";



GRANT ALL ON TABLE "public"."currencies" TO "anon";
GRANT ALL ON TABLE "public"."currencies" TO "authenticated";
GRANT ALL ON TABLE "public"."currencies" TO "service_role";



GRANT ALL ON TABLE "public"."expenses_v" TO "anon";
GRANT ALL ON TABLE "public"."expenses_v" TO "authenticated";
GRANT ALL ON TABLE "public"."expenses_v" TO "service_role";



GRANT ALL ON TABLE "public"."fx_rates" TO "anon";
GRANT ALL ON TABLE "public"."fx_rates" TO "authenticated";
GRANT ALL ON TABLE "public"."fx_rates" TO "service_role";



GRANT ALL ON TABLE "public"."incomes_v" TO "anon";
GRANT ALL ON TABLE "public"."incomes_v" TO "authenticated";
GRANT ALL ON TABLE "public"."incomes_v" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."transfers_v" TO "anon";
GRANT ALL ON TABLE "public"."transfers_v" TO "authenticated";
GRANT ALL ON TABLE "public"."transfers_v" TO "service_role";



GRANT ALL ON TABLE "public"."user_settings" TO "anon";
GRANT ALL ON TABLE "public"."user_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."user_settings" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







RESET ALL;
