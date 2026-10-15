alter table public.cars
  add column if not exists rate_2_6_days numeric(10,2) not null default 0 check (rate_2_6_days >= 0),
  add column if not exists rate_7_days numeric(10,2) not null default 0 check (rate_7_days >= 0),
  add column if not exists rate_month numeric(10,2) not null default 0 check (rate_month >= 0);

update public.cars
set rate_2_6_days = daily_rate
where rate_2_6_days = 0;

update public.cars
set rate_7_days = daily_rate * 7
where rate_7_days = 0;

update public.cars
set rate_month = daily_rate * 30
where rate_month = 0;
