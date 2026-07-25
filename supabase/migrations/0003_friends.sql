-- v2.1a 친구 그래프: friendships / invites + RLS + 함수

create table if not exists friendships (
  user_a uuid not null references profiles(id) on delete cascade,
  user_b uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);

create table if not exists invites (
  token text primary key,
  inviter_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  active boolean not null default true
);

alter table friendships enable row level security;
alter table invites enable row level security;

-- friendships: 당사자만 조회·삭제. 삽입 정책 없음 = 직접 삽입 차단(accept_invite로만).
-- (create policy는 재실행 불가라 drop if exists 선행 — 마이그레이션 재적용 안전)
drop policy if exists friendships_select on friendships;
create policy friendships_select on friendships for select
  using (auth.uid() = user_a or auth.uid() = user_b);
drop policy if exists friendships_delete on friendships;
create policy friendships_delete on friendships for delete
  using (auth.uid() = user_a or auth.uid() = user_b);

-- invites: 초대자 본인만.
drop policy if exists invites_owner_all on invites;
create policy invites_owner_all on invites for all
  using (auth.uid() = inviter_id) with check (auth.uid() = inviter_id);

-- profiles: 친구는 서로 이름·아바타 조회 가능(0001 본인정책에 OR로 추가).
drop policy if exists profiles_friends_select on profiles;
create policy profiles_friends_select on profiles for select
  using (
    id = auth.uid() or exists (
      select 1 from friendships f
      where (f.user_a = auth.uid() and f.user_b = profiles.id)
         or (f.user_b = auth.uid() and f.user_a = profiles.id)
    )
  );

-- 수락 전 "OO님과 친구?" 표시용.
create or replace function get_invite_info(p_token text)
returns table(inviter_name text, valid boolean)
language sql security definer set search_path = public as $$
  select p.display_name,
         (i.active and (i.expires_at is null or i.expires_at > now())
          and i.inviter_id <> auth.uid())
  from invites i join profiles p on p.id = i.inviter_id
  where i.token = p_token;
$$;

-- 토큰 검증 후 정규화된 상호 친구행 생성(멱등).
create or replace function accept_invite(p_token text)
returns void
language plpgsql security definer set search_path = public as $$
declare v_inviter uuid; v_me uuid := auth.uid();
begin
  select inviter_id into v_inviter from invites
   where token = p_token and active
     and (expires_at is null or expires_at > now());
  if v_inviter is null then raise exception 'invalid_invite'; end if;
  if v_inviter = v_me then raise exception 'self_invite'; end if;
  insert into friendships(user_a, user_b)
  values (least(v_inviter, v_me), greatest(v_inviter, v_me))
  on conflict do nothing;
end;
$$;

-- 내 친구 목록(상대방 프로필). 이중 FK 조인 회피용 함수.
create or replace function list_my_friends()
returns table(id uuid, display_name text, avatar_url text)
language sql security definer set search_path = public as $$
  select p.id, p.display_name, p.avatar_url
  from friendships f
  join profiles p
    on p.id = case when f.user_a = auth.uid() then f.user_b else f.user_a end
  where f.user_a = auth.uid() or f.user_b = auth.uid();
$$;

grant execute on function get_invite_info(text) to authenticated;
grant execute on function accept_invite(text) to authenticated;
grant execute on function list_my_friends() to authenticated;
