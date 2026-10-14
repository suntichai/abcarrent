-- AB CARRENT company profile, bank accounts, and phone-keyed customers.
begin;

do $$
begin
  if exists (
    select 1 from public.customers
    group by regexp_replace(coalesce(phone, ''), '\D', '', 'g')
    having regexp_replace(coalesce(phone, ''), '\D', '', 'g') !~ '^0[0-9]{8,9}$'
       or count(*) > 1
  ) then
    raise exception 'Customer phone numbers must contain 9-10 digits starting with 0 and be unique before migration';
  end if;
end;
$$;

create temporary table customer_phone_keys on commit drop as
select id as old_id, regexp_replace(phone, '\D', '', 'g') as phone_key
from public.customers;

alter table public.bookings drop constraint if exists bookings_customer_id_fkey;
alter table public.quotes drop constraint if exists quotes_customer_id_fkey;

update public.bookings b
set customer_id = k.phone_key
from customer_phone_keys k
where b.customer_id = k.old_id;

update public.quotes q
set customer_id = k.phone_key
from customer_phone_keys k
where q.customer_id = k.old_id;

update public.customers c
set id = k.phone_key, phone = k.phone_key
from customer_phone_keys k
where c.id = k.old_id;

alter table public.bookings
  add constraint bookings_customer_id_fkey
  foreign key (customer_id) references public.customers(id) on delete restrict;
alter table public.quotes
  add constraint quotes_customer_id_fkey
  foreign key (customer_id) references public.customers(id) on delete restrict;

create unique index if not exists customers_phone_unique on public.customers(phone);
alter table public.customers add column if not exists branch_name text not null default 'สำนักงานใหญ่';

create table if not exists public.bank_accounts (
  id text primary key,
  nickname text not null,
  bank_name text not null,
  account_name text not null,
  account_number text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.bookings
  add column if not exists bank_account_id text references public.bank_accounts(id) on delete set null;
create index if not exists bookings_bank_account_idx on public.bookings(bank_account_id) where paid;

create table if not exists public.company_settings (
  id text primary key check (id = 'default'),
  profile jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.bank_accounts enable row level security;
drop policy if exists "admin access bank accounts" on public.bank_accounts;
create policy "admin access bank accounts" on public.bank_accounts
  for all to authenticated using ((select public.is_ab_admin()))
  with check ((select public.is_ab_admin()));
grant select, insert, update, delete on public.bank_accounts to authenticated;

alter table public.company_settings enable row level security;
drop policy if exists "admin access company settings" on public.company_settings;
create policy "admin access company settings" on public.company_settings
  for all to authenticated using ((select public.is_ab_admin()))
  with check ((select public.is_ab_admin()));
grant select, insert, update, delete on public.company_settings to authenticated;

commit;
