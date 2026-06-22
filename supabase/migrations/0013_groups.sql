-- Catch — 0013 그룹(공유 항아리)
-- 로컬 기본 저장 + 그룹에 넣은 스티커만 멤버끼리 공유.

-- ---------------------------------------------------------------- groups
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 50),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  invite_code text not null unique,
  shape int, color int, label_color int,   -- 항아리 노드 스타일(폴더와 동일 체계)
  created_at timestamptz not null default now()
);
create index groups_owner on public.groups(owner_id);

create table public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',      -- 'owner' | 'member'
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index group_members_user on public.group_members(user_id);

-- 스티커에 그룹 소속 추가(null = 로컬/미공유).
alter table public.catches add column group_id uuid references public.groups(id) on delete set null;
create index catches_group on public.catches(group_id);

-- 멤버십 헬퍼(RLS 재귀 방지용 security definer).
create or replace function public.is_group_member(g uuid, u uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.group_members m where m.group_id = g and m.user_id = u);
$$;

-- ---------------------------------------------------------------- RLS
alter table public.groups enable row level security;
alter table public.group_members enable row level security;

-- groups: 멤버만 조회. 생성/수정/삭제는 owner.
create policy groups_select on public.groups for select to authenticated
  using ( public.is_group_member(id, auth.uid()) );
create policy groups_insert on public.groups for insert to authenticated
  with check ( owner_id = auth.uid() );
create policy groups_update on public.groups for update to authenticated
  using ( owner_id = auth.uid() ) with check ( owner_id = auth.uid() );
create policy groups_delete on public.groups for delete to authenticated
  using ( owner_id = auth.uid() );

-- group_members: 같은 그룹 멤버끼리 조회. 본인 행만 추가/삭제(가입/탈퇴).
create policy gm_select on public.group_members for select to authenticated
  using ( public.is_group_member(group_id, auth.uid()) );
create policy gm_insert on public.group_members for insert to authenticated
  with check ( user_id = auth.uid() );
create policy gm_delete on public.group_members for delete to authenticated
  using ( user_id = auth.uid() );

-- catches: 기존 정책을 그룹 모델로 교체(소유자 또는 그룹 멤버만 조회).
drop policy if exists catches_select on public.catches;
create policy catches_select on public.catches for select to authenticated
  using (
    owner_id = auth.uid()
    or (group_id is not null and public.is_group_member(group_id, auth.uid()))
  );

-- 그룹 배정을 위해 group_id 업데이트 허용(소유자가 자기 멤버 그룹으로만).
grant update (folder_id, title, is_public, group_id) on public.catches to authenticated;
drop policy if exists catches_update on public.catches;
create policy catches_update on public.catches for update to authenticated
  using ( owner_id = auth.uid() )
  with check ( owner_id = auth.uid()
               and (group_id is null or public.is_group_member(group_id, auth.uid())) );

-- ---------------------------------------------------------------- RPC
-- 그룹 생성(초대 코드 자동 + 본인 owner 멤버십 동시 생성).
create or replace function public.create_group(p_name text, p_shape int, p_color int, p_label_color int)
returns public.groups language plpgsql security definer set search_path = public as $$
declare g public.groups; gen text;
begin
  gen := upper(substr(md5(gen_random_uuid()::text), 1, 6));
  insert into public.groups(name, owner_id, invite_code, shape, color, label_color)
    values (p_name, auth.uid(), gen, p_shape, p_color, p_label_color)
    returning * into g;
  insert into public.group_members(group_id, user_id, role) values (g.id, auth.uid(), 'owner');
  return g;
end;
$$;
grant execute on function public.create_group(text, int, int, int) to authenticated;

-- 초대 코드로 그룹 가입.
create or replace function public.join_group(code text)
returns public.groups language plpgsql security definer set search_path = public as $$
declare g public.groups;
begin
  select * into g from public.groups where invite_code = upper(code);
  if g.id is null then raise exception 'group_not_found'; end if;
  insert into public.group_members(group_id, user_id, role)
    values (g.id, auth.uid(), 'member')
    on conflict (group_id, user_id) do nothing;
  return g;
end;
$$;
grant execute on function public.join_group(text) to authenticated;

grant select on public.groups to authenticated;
grant select, insert, delete on public.group_members to authenticated;
grant insert on public.groups to authenticated;
