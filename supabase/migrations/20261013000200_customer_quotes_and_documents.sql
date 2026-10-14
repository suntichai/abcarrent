-- AB CARRENT: customer tax profile, rental documents, expenses by vehicle, and quotes.
alter table public.customers
  add column if not exists line_id text,
  add column if not exists tax_type text not null default 'individual' check (tax_type in ('individual','company')),
  add column if not exists tax_name text,
  add column if not exists tax_id text,
  add column if not exists tax_address text,
  add column if not exists province text,
  add column if not exists district text,
  add column if not exists subdistrict text,
  add column if not exists postal_code text,
  add column if not exists id_document_path text,
  add column if not exists license_document_path text;

create unique index if not exists customers_tax_id_unique
  on public.customers (tax_id) where tax_id is not null and tax_id <> '';

alter table public.bookings
  add column if not exists insurance_name text,
  add column if not exists insurance_coverage numeric(12,2) not null default 0 check (insurance_coverage >= 0),
  add column if not exists extra_charges jsonb not null default '[]'::jsonb,
  add column if not exists receipt_printed_at timestamptz,
  add column if not exists tax_invoice_printed_at timestamptz,
  add column if not exists quote_id text;

alter table public.expenses
  add column if not exists car_id text references public.cars(id) on delete set null;

create table if not exists public.quotes (
  id text primary key,
  customer_id text not null references public.customers(id) on delete restrict,
  car_id text not null references public.cars(id) on delete restrict,
  pickup_at timestamptz not null,
  return_at timestamptz not null,
  rental_days integer not null check (rental_days > 0),
  daily_rate_snapshot numeric(10,2) not null check (daily_rate_snapshot >= 0),
  total numeric(12,2) not null check (total >= 0),
  deposit numeric(12,2) not null default 0 check (deposit >= 0),
  insurance_name text,
  insurance_coverage numeric(12,2) not null default 0 check (insurance_coverage >= 0),
  extra_charges jsonb not null default '[]'::jsonb,
  status text not null default 'quoted' check (status in ('quoted','converted','expired','cancelled')),
  created_at timestamptz not null default now(),
  check (return_at > pickup_at)
);

create index if not exists quotes_created_at_idx on public.quotes (created_at desc);
alter table public.quotes enable row level security;
drop policy if exists "admin access quotes" on public.quotes;
create policy "admin access quotes" on public.quotes for all to authenticated
  using ((select public.is_ab_admin())) with check ((select public.is_ab_admin()));
grant select, insert, update, delete on public.quotes to authenticated;

-- Prevent accidental reversal of a completed payment status.
create or replace function public.keep_booking_paid_once_paid()
returns trigger language plpgsql as $$
begin
  if old.paid and not new.paid then
    raise exception 'A paid booking cannot be changed back to unpaid';
  end if;
  return new;
end;
$$;
drop trigger if exists bookings_paid_is_irreversible on public.bookings;
create trigger bookings_paid_is_irreversible before update of paid on public.bookings
  for each row execute function public.keep_booking_paid_once_paid();

-- Identity and driving-license PDFs are private; only authenticated admins can access them.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('customer-documents', 'customer-documents', false, 10485760, array['application/pdf'])
on conflict (id) do update set public = false, file_size_limit = 10485760, allowed_mime_types = array['application/pdf'];
drop policy if exists "admins can manage customer documents" on storage.objects;
create policy "admins can manage customer documents" on storage.objects for all to authenticated
  using (bucket_id = 'customer-documents' and (select public.is_ab_admin()))
  with check (bucket_id = 'customer-documents' and (select public.is_ab_admin()));
