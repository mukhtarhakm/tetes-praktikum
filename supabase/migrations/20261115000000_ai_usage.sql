create table public.ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  calls integer not null default 0,
  primary key (user_id, day)
);

alter table public.ai_usage enable row level security;
revoke all on public.ai_usage from anon, authenticated;

create function public.reserve_brew_ai_call(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  next_calls integer;
begin
  insert into public.ai_usage (user_id, day, calls)
  values (p_user_id, (now() at time zone 'Asia/Jakarta')::date, 1)
  on conflict (user_id, day) do update
    set calls = public.ai_usage.calls + 1
    where public.ai_usage.calls < 20
  returning calls into next_calls;
  return next_calls is not null;
end;
$$;

revoke all on function public.reserve_brew_ai_call(uuid) from public, anon, authenticated;
grant execute on function public.reserve_brew_ai_call(uuid) to service_role;
