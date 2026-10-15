-- Store engine displacement in cubic centimeters for fleet grouping.
alter table public.cars
  add column if not exists engine_cc integer;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.cars'::regclass
      and conname = 'cars_engine_cc_positive'
  ) then
    alter table public.cars
      add constraint cars_engine_cc_positive
      check (engine_cc is null or engine_cc > 0);
  end if;
end
$$;
