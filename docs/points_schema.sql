-- Apply this migration to the NaviPet Supabase project before shipping the app.
-- The Flutter client only calls these functions; prices and rewards live here.
create table if not exists public.point_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance integer not null default 0 check (balance >= 0),
  equipped_outfit text
);

create table if not exists public.point_transactions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  amount integer not null check (amount <> 0),
  reason text not null,
  reference_id text not null,
  created_at timestamptz not null default now(),
  unique (user_id, reason, reference_id)
);

create table if not exists public.outfit_purchases (
  user_id uuid not null references auth.users(id) on delete cascade,
  outfit_id text not null,
  purchased_at timestamptz not null default now(),
  primary key (user_id, outfit_id)
);

alter table public.point_wallets enable row level security;
alter table public.point_transactions enable row level security;
alter table public.outfit_purchases enable row level security;

create policy "read own wallet" on public.point_wallets for select to authenticated using (user_id = (select auth.uid()));
create policy "read own transactions" on public.point_transactions for select to authenticated using (user_id = (select auth.uid()));
create policy "read own outfits" on public.outfit_purchases for select to authenticated using (user_id = (select auth.uid()));

revoke all on public.point_wallets, public.point_transactions, public.outfit_purchases from anon, authenticated;
grant select on public.point_wallets, public.point_transactions, public.outfit_purchases to authenticated;

create or replace function public.claim_daily_task(
  p_class_id uuid,
  p_kind text,
  p_latitude double precision default null,
  p_longitude double precision default null
) returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_class public.classes%rowtype;
  v_today date := (now() at time zone 'America/Los_Angeles')::date;
  v_weekday integer := extract(isodow from (now() at time zone 'America/Los_Angeles'));
  v_time time := (now() at time zone 'America/Los_Angeles')::time;
  v_reward integer;
  v_balance integer;
begin
  if v_user is null then raise exception 'Sign in to claim points'; end if;
  select * into v_class from public.classes where id = p_class_id and user_id = v_user;
  if not found then raise exception 'Class not found'; end if;

  if p_kind = 'attend' and not v_class.is_online and v_weekday = any(v_class.weekdays) then
    if v_time < v_class.start_time - interval '15 minutes' or
       v_time > v_class.end_time + interval '15 minutes' then
      raise exception 'Class check-in is outside the scheduled time';
    end if;
    if p_latitude is null or p_longitude is null or
       p_latitude < -90 or p_latitude > 90 or p_longitude < -180 or p_longitude > 180 or
       6371000 * 2 * asin(sqrt(
         power(sin(radians((v_class.latitude - p_latitude) / 2)), 2) +
         cos(radians(p_latitude)) * cos(radians(v_class.latitude)) *
         power(sin(radians((v_class.longitude - p_longitude) / 2)), 2)
       )) > 150 then
      raise exception 'Outside the class check-in area';
    end if;
    v_reward := 10;
  elsif p_kind = 'attend_online' and v_class.is_online and v_weekday = any(v_class.weekdays) then
    v_reward := 5;
  elsif p_kind = 'prepare' and not exists (
    select 1 from public.classes c where c.user_id = v_user and v_weekday = any(c.weekdays)
  ) and p_class_id in (
    select c.id from public.classes c where c.user_id = v_user order by c.start_time limit 3
  ) then
    v_reward := 5;
  else
    raise exception 'Task is not scheduled today';
  end if;

  insert into public.point_wallets (user_id) values (v_user) on conflict do nothing;
  select balance into v_balance from public.point_wallets where user_id = v_user for update;
  if exists (
    select 1 from public.task_completions
    where user_id = v_user and class_id = p_class_id and task_date = v_today and task_kind = p_kind
  ) then return v_balance; end if;

  insert into public.task_completions (user_id, class_id, task_date, task_kind)
  values (v_user, p_class_id, v_today, p_kind);
  insert into public.point_transactions (user_id, amount, reason, reference_id)
  values (v_user, v_reward, 'daily_task', p_class_id::text || '|' || v_today || '|' || p_kind);
  update public.point_wallets set balance = balance + v_reward where user_id = v_user returning balance into v_balance;
  return v_balance;
end;
$$;

create or replace function public.equip_outfit(p_outfit_id text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then raise exception 'Sign in to equip outfits'; end if;
  if not exists (select 1 from public.outfit_purchases where user_id = v_user and outfit_id = p_outfit_id) then
    raise exception 'Outfit is not owned';
  end if;
  update public.point_wallets set equipped_outfit = p_outfit_id where user_id = v_user;
end;
$$;

create or replace function public.buy_outfit(p_outfit_id text)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_price integer;
  v_balance integer;
begin
  if v_user is null then raise exception 'Sign in to buy outfits'; end if;
  v_price := case p_outfit_id
    when 'csulb_tee' then 20
    when 'grad_cap' then 30
    when 'shades' then 15
    when 'beach_hat' then 25
    else null end;
  if v_price is null then raise exception 'Unknown outfit'; end if;
  insert into public.point_wallets (user_id) values (v_user) on conflict do nothing;
  select balance into v_balance from public.point_wallets where user_id = v_user for update;
  if exists (select 1 from public.outfit_purchases where user_id = v_user and outfit_id = p_outfit_id) then
    return v_balance;
  end if;
  if v_balance < v_price then raise exception 'Not enough points'; end if;
  insert into public.outfit_purchases (user_id, outfit_id) values (v_user, p_outfit_id);
  insert into public.point_transactions (user_id, amount, reason, reference_id)
  values (v_user, -v_price, 'outfit_purchase', p_outfit_id);
  update public.point_wallets set balance = balance - v_price where user_id = v_user returning balance into v_balance;
  return v_balance;
end;
$$;

revoke all on function public.claim_daily_task(uuid, text, double precision, double precision) from public;
revoke all on function public.buy_outfit(text) from public;
revoke all on function public.equip_outfit(text) from public;
grant execute on function public.claim_daily_task(uuid, text, double precision, double precision) to authenticated;
grant execute on function public.buy_outfit(text) to authenticated;
grant execute on function public.equip_outfit(text) to authenticated;
