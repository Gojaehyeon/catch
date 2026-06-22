-- Catch — 0014 그룹 RPC를 setof 반환으로(클라이언트 배열 디코드 일관성)
-- 단일 composite 반환은 PostgREST 응답 형태가 클라 디코드와 어긋나 그룹 생성이 실패하던 문제 수정.

drop function if exists public.create_group(text, int, int, int);
create or replace function public.create_group(p_name text, p_shape int, p_color int, p_label_color int)
returns setof public.groups language plpgsql security definer set search_path = public as $$
declare gen text; new_id uuid;
begin
  gen := upper(substr(md5(gen_random_uuid()::text), 1, 6));
  insert into public.groups(name, owner_id, invite_code, shape, color, label_color)
    values (p_name, auth.uid(), gen, p_shape, p_color, p_label_color)
    returning id into new_id;
  insert into public.group_members(group_id, user_id, role) values (new_id, auth.uid(), 'owner');
  return query select * from public.groups where id = new_id;
end;
$$;
grant execute on function public.create_group(text, int, int, int) to authenticated;

drop function if exists public.join_group(text);
create or replace function public.join_group(code text)
returns setof public.groups language plpgsql security definer set search_path = public as $$
declare gid uuid;
begin
  select id into gid from public.groups where invite_code = upper(code);
  if gid is null then raise exception 'group_not_found'; end if;
  insert into public.group_members(group_id, user_id, role)
    values (gid, auth.uid(), 'member') on conflict (group_id, user_id) do nothing;
  return query select * from public.groups where id = gid;
end;
$$;
grant execute on function public.join_group(text) to authenticated;
