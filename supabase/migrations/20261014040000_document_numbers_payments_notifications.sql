begin;

create table if not exists public.document_counters (
  document_type text not null check (document_type in ('QT', 'RE', 'IV', 'BK')),
  period text not null,
  last_number integer not null check (last_number > 0),
  primary key (document_type, period)
);

alter table public.document_counters enable row level security;
drop policy if exists "admin access document counters" on public.document_counters;
create policy "admin access document counters" on public.document_counters
  for all to authenticated
  using ((select public.is_ab_admin()))
  with check ((select public.is_ab_admin()));
grant select, insert, update on public.document_counters to authenticated;

alter table public.bookings
  add column if not exists receipt_number text,
  add column if not exists tax_invoice_number text;
create unique index if not exists bookings_receipt_number_unique
  on public.bookings(receipt_number) where receipt_number is not null;
create unique index if not exists bookings_tax_invoice_number_unique
  on public.bookings(tax_invoice_number) where tax_invoice_number is not null;

create table if not exists public.booking_payments (
  id text primary key,
  booking_id text not null references public.bookings(id) on delete cascade,
  amount numeric not null check (amount > 0),
  payment_method text not null check (payment_method in ('เงินสด', 'โอนเงิน', 'บัตรเครดิต', 'อื่นๆ')),
  bank_account_id text references public.bank_accounts(id) on delete restrict,
  paid_at timestamptz not null default now(),
  note text,
  created_at timestamptz not null default now(),
  check (payment_method <> 'โอนเงิน' or bank_account_id is not null)
);
create index if not exists booking_payments_booking_idx
  on public.booking_payments(booking_id, paid_at);
create index if not exists booking_payments_bank_idx
  on public.booking_payments(bank_account_id) where bank_account_id is not null;

alter table public.booking_payments enable row level security;
drop policy if exists "admin access booking payments" on public.booking_payments;
create policy "admin access booking payments" on public.booking_payments
  for all to authenticated
  using ((select public.is_ab_admin()))
  with check ((select public.is_ab_admin()));
grant select, insert, update, delete on public.booking_payments to authenticated;

create table if not exists public.notifications (
  id text primary key,
  event_type text not null,
  title text not null,
  detail text not null default '',
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notifications_created_idx on public.notifications(created_at desc);
alter table public.notifications enable row level security;
drop policy if exists "admin access notifications" on public.notifications;
create policy "admin access notifications" on public.notifications
  for all to authenticated
  using ((select public.is_ab_admin()))
  with check ((select public.is_ab_admin()));
grant select, insert, update, delete on public.notifications to authenticated;

create or replace function public.next_document_number(
  p_document_type text,
  p_document_date date default ((now() at time zone 'Asia/Bangkok')::date)
)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_year integer;
  v_period text;
  v_limit integer;
  v_sequence integer;
  v_body text;
  v_sum integer;
  v_check_digit integer;
begin
  if p_document_type is null or p_document_type not in ('QT', 'RE', 'IV', 'BK') then
    raise exception 'Unsupported document type';
  end if;
  if not coalesce((select public.is_ab_admin()), false) then
    raise exception 'Administrator access required';
  end if;

  v_year := extract(year from p_document_date)::integer + 543;
  v_period := lpad((v_year % 100)::text, 2, '0');
  if p_document_type in ('QT', 'RE', 'IV') then
    v_period := v_period || to_char(p_document_date, 'MM');
    v_limit := 9999;
  else
    v_limit := 99999;
  end if;

  insert into public.document_counters as counters(document_type, period, last_number)
  values (p_document_type, v_period, 1)
  on conflict (document_type, period) do update
    set last_number = counters.last_number + 1
    where counters.last_number < v_limit
  returning last_number into v_sequence;

  if v_sequence is null then
    raise exception 'Document number limit reached for % %', p_document_type, v_period;
  end if;

  if p_document_type = 'BK' then
    v_body := v_period || lpad(v_sequence::text, 5, '0');
    select coalesce(sum(substr(v_body, positions.position, 1)::integer * (9 - positions.position)), 0)
      into v_sum
      from generate_series(1, 7) as positions(position);
    v_check_digit := (11 - (v_sum % 11)) % 10;
    return 'BK' || v_body || v_check_digit::text;
  end if;

  return p_document_type || v_period || lpad(v_sequence::text, 4, '0');
end;
$$;
grant execute on function public.next_document_number(text, date) to authenticated;

create or replace function public.ensure_booking_document_number(
  p_booking_id text,
  p_document_type text,
  p_document_date date default ((now() at time zone 'Asia/Bangkok')::date)
)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_number text;
begin
  if p_document_type not in ('RE', 'IV') then
    raise exception 'Document type must be RE or IV';
  end if;
  if not coalesce((select public.is_ab_admin()), false) then
    raise exception 'Administrator access required';
  end if;

  if p_document_type = 'RE' then
    select receipt_number into v_number
      from public.bookings where id = p_booking_id for update;
  else
    select tax_invoice_number into v_number
      from public.bookings where id = p_booking_id for update;
  end if;
  if not found then
    raise exception 'Booking not found';
  end if;

  if v_number is null then
    v_number := public.next_document_number(p_document_type, p_document_date);
    if p_document_type = 'RE' then
      update public.bookings set receipt_number = v_number where id = p_booking_id;
    else
      update public.bookings set tax_invoice_number = v_number where id = p_booking_id;
    end if;
  end if;
  return v_number;
end;
$$;
grant execute on function public.ensure_booking_document_number(text, text, date) to authenticated;

create or replace function public.record_booking_payment(
  p_payment_id text,
  p_booking_id text,
  p_amount numeric,
  p_payment_method text,
  p_bank_account_id text default null,
  p_paid_at timestamptz default now(),
  p_note text default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_total numeric;
  v_paid_total numeric;
begin
  if not coalesce((select public.is_ab_admin()), false) then
    raise exception 'Administrator access required';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Payment amount must be greater than zero';
  end if;
  if p_payment_method not in ('เงินสด', 'โอนเงิน', 'บัตรเครดิต', 'อื่นๆ') then
    raise exception 'Unsupported payment method';
  end if;
  if p_payment_method = 'โอนเงิน' and p_bank_account_id is null then
    raise exception 'Bank account is required for transfers';
  end if;

  select total into v_total from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'Booking not found';
  end if;

  insert into public.booking_payments
    (id, booking_id, amount, payment_method, bank_account_id, paid_at, note)
  values
    (p_payment_id, p_booking_id, p_amount, p_payment_method, p_bank_account_id, p_paid_at, p_note);

  select coalesce(sum(amount), 0) into v_paid_total
    from public.booking_payments where booking_id = p_booking_id;
  if v_paid_total >= v_total then
    update public.bookings set paid = true where id = p_booking_id and not paid;
  end if;
end;
$$;
grant execute on function public.record_booking_payment(text, text, numeric, text, text, timestamptz, text) to authenticated;

commit;
