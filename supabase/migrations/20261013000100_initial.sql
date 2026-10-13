-- AB CARRENT: initial Supabase/PostgreSQL schema.
-- Run once in Supabase SQL Editor before deploying the browser app.

create extension if not exists btree_gist;

create table if not exists public.ab_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'ผู้ดูแลระบบ',
  created_at timestamptz not null default now()
);

create table if not exists public.cars (
  id text primary key,
  name text not null,
  plate text not null unique,
  car_type text not null default 'รถเก๋ง',
  seats smallint not null default 5 check (seats > 0),
  transmission text not null default 'อัตโนมัติ',
  fuel text not null default 'เบนซิน',
  daily_rate numeric(10,2) not null check (daily_rate >= 0),
  color text,
  available boolean not null default true,
  icon text,
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customers (
  id text primary key,
  name text not null,
  phone text not null,
  email text,
  driver_license text,
  address text,
  created_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id text primary key,
  customer_id text not null references public.customers(id) on delete restrict,
  car_id text not null references public.cars(id) on delete restrict,
  pickup_at timestamptz not null,
  return_at timestamptz not null,
  rental_days integer not null check (rental_days > 0),
  daily_rate_snapshot numeric(10,2) not null check (daily_rate_snapshot >= 0),
  total numeric(12,2) not null check (total >= 0),
  deposit numeric(12,2) not null default 0 check (deposit >= 0),
  payment_method text not null default 'โอนเงิน',
  paid boolean not null default false,
  status text not null default 'confirmed'
    check (status in ('confirmed','ongoing','completed','cancelled')),
  created_at timestamptz not null default now(),
  check (return_at > pickup_at),
  constraint bookings_no_car_time_overlap
    exclude using gist (
      car_id with =,
      tstzrange(pickup_at, return_at, '[)') with &&
    ) where (status in ('confirmed','ongoing'))
);

create table if not exists public.expenses (
  id text primary key,
  expense_date date not null,
  title text not null,
  category text not null,
  amount numeric(12,2) not null check (amount >= 0),
  payment_method text,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists bookings_car_period_idx
  on public.bookings (car_id, pickup_at, return_at);
create index if not exists bookings_customer_idx
  on public.bookings (customer_id);
create index if not exists expenses_date_idx
  on public.expenses (expense_date desc);

create or replace function public.is_ab_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.ab_admins a where a.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_ab_admin() from public;
grant execute on function public.is_ab_admin() to authenticated;

alter table public.ab_admins enable row level security;
alter table public.cars enable row level security;
alter table public.customers enable row level security;
alter table public.bookings enable row level security;
alter table public.expenses enable row level security;

drop policy if exists "admins can read own admin profile" on public.ab_admins;
create policy "admins can read own admin profile" on public.ab_admins
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_ab_admin()));

drop policy if exists "admin access cars" on public.cars;
create policy "admin access cars" on public.cars
  for all to authenticated
  using ((select public.is_ab_admin()))
  with check ((select public.is_ab_admin()));

drop policy if exists "admin access customers" on public.customers;
create policy "admin access customers" on public.customers
  for all to authenticated
  using ((select public.is_ab_admin()))
  with check ((select public.is_ab_admin()));

drop policy if exists "admin access bookings" on public.bookings;
create policy "admin access bookings" on public.bookings
  for all to authenticated
  using ((select public.is_ab_admin()))
  with check ((select public.is_ab_admin()));

drop policy if exists "admin access expenses" on public.expenses;
create policy "admin access expenses" on public.expenses
  for all to authenticated
  using ((select public.is_ab_admin()))
  with check ((select public.is_ab_admin()));

grant select on public.ab_admins to authenticated;
grant select, insert, update, delete on public.cars to authenticated;
grant select, insert, update, delete on public.customers to authenticated;
grant select, insert, update, delete on public.bookings to authenticated;
grant select, insert, update, delete on public.expenses to authenticated;

-- Vehicle photos are public to display on the fleet page; only admins can write.
insert into storage.buckets (id, name, public)
values ('car-photos', 'car-photos', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "public can view car photos" on storage.objects;
create policy "public can view car photos" on storage.objects
  for select to public
  using (bucket_id = 'car-photos');

drop policy if exists "admins can upload car photos" on storage.objects;
create policy "admins can upload car photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'car-photos' and (select public.is_ab_admin()));

drop policy if exists "admins can update car photos" on storage.objects;
create policy "admins can update car photos" on storage.objects
  for update to authenticated
  using (bucket_id = 'car-photos' and (select public.is_ab_admin()))
  with check (bucket_id = 'car-photos' and (select public.is_ab_admin()));

drop policy if exists "admins can delete car photos" on storage.objects;
create policy "admins can delete car photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'car-photos' and (select public.is_ab_admin()));

-- After creating the first user in Authentication > Users, register that user:
-- insert into public.ab_admins (user_id, display_name)
-- select id, 'ผู้ดูแลระบบ' from auth.users where email = 'YOUR_ADMIN_EMAIL';
