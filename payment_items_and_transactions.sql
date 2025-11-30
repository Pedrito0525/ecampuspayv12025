-- payment_items table: catalog of sellable items per service account
create table if not exists public.payment_items (
  id bigint generated always as identity primary key,
  service_account_id bigint not null references public.service_accounts(id) on delete cascade,
  name text not null,
  category text not null,
  base_price numeric(12,2) not null check (base_price >= 0),
  has_sizes boolean not null default false,
  size_options jsonb, -- {"Small": 15.0, "Medium": 20.0}
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_payment_items_service on public.payment_items(service_account_id);
create index if not exists idx_payment_items_active on public.payment_items(is_active);

-- service_transactions table: records of sales
create table if not exists public.service_transactions (
  id bigint generated always as identity primary key,
  service_account_id bigint not null references public.service_accounts(id) on delete restrict,
  main_service_id bigint references public.service_accounts(id) on delete set null,
  student_id text, -- optional
  items jsonb not null, -- array of {id,name,price,quantity,total}
  total_amount numeric(14,2) not null check (total_amount >= 0),
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists idx_service_tx_service on public.service_transactions(service_account_id);
create index if not exists idx_service_tx_main on public.service_transactions(main_service_id);
create index if not exists idx_service_tx_created on public.service_transactions(created_at);

-- trigger to keep updated_at fresh
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

do $$ begin
  if not exists (
    select 1 from pg_trigger where tgname = 'trg_payment_items_updated_at'
  ) then
    create trigger trg_payment_items_updated_at
    before update on public.payment_items
    for each row execute function public.set_updated_at();
  end if;
end $$;

-- Basic RLS scaffolding (enable and allow owners)
alter table public.payment_items enable row level security;
alter table public.service_transactions enable row level security;

-- Policies (adjust roles as needed)
do $$ begin
  if not exists (
    select 1 from pg_policies where tablename = 'payment_items' and policyname = 'allow_read_active_items'
  ) then
    create policy allow_read_active_items on public.payment_items
      for select using (is_active = true);
  end if;
  if not exists (
    select 1 from pg_policies where tablename = 'payment_items' and policyname = 'owner_manage_items'
  ) then
    create policy owner_manage_items on public.payment_items
      for all using (true) with check (true);
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_policies where tablename = 'service_transactions' and policyname = 'allow_insert_transactions'
  ) then
    create policy allow_insert_transactions on public.service_transactions
      for insert with check (true);
  end if;
  if not exists (
    select 1 from pg_policies where tablename = 'service_transactions' and policyname = 'allow_read_own_transactions'
  ) then
    create policy allow_read_own_transactions on public.service_transactions
      for select using (true);
  end if;
end $$;


