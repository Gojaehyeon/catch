-- username 최소 길이 3 → 2 (예: "go")
alter table public.profiles drop constraint if exists profiles_username_check;
alter table public.profiles
  add constraint profiles_username_check check (username ~ '^[a-z0-9_]{2,20}$');

create or replace function public.username_available(name citext)
returns boolean language sql stable security definer set search_path = public as $$
  select name ~ '^[a-z0-9_]{2,20}$'
     and not exists (select 1 from public.reserved_usernames r where r.name = username_available.name)
     and not exists (select 1 from public.profiles p where p.username = username_available.name);
$$;
