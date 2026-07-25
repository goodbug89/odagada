-- v2.1b-1 소셜 지도: saved_places 친구 조회 + 뷰포트 친구-저장 집계

-- 친구는 accepted 친구의 is_public 저장 조회 가능(0002 본인정책에 OR로 추가).
-- (create policy 재실행 불가라 drop if exists 선행 — 마이그레이션 재적용 안전)
drop policy if exists saved_places_friends_select on saved_places;
create policy saved_places_friends_select on saved_places for select
  using (
    owner_id = auth.uid() or (
      is_public and exists (
        select 1 from friendships f
        where (f.user_a = auth.uid() and f.user_b = saved_places.owner_id)
           or (f.user_b = auth.uid() and f.user_a = saved_places.owner_id)
      )
    )
  );

-- 뷰포트(center+radius bbox 근사)의 친구-저장을 place_id로 그룹 집계.
create or replace function friend_saves_near(
  p_lat double precision, p_lng double precision, p_radius double precision)
returns table(
  place_id text, lat double precision, lng double precision,
  name text, category text,
  friend_count int, friend_names text[], memos text[])
language sql security definer set search_path = public as $$
  select sp.place_id,
         max(sp.lat), max(sp.lng), max(sp.name), max(sp.category),
         count(*)::int,
         array_agg(coalesce(p.display_name, '친구') order by sp.owner_id),
         array_agg(coalesce(sp.memo, '') order by sp.owner_id)
  from saved_places sp
  join friendships f
    on (f.user_a = auth.uid() and f.user_b = sp.owner_id)
    or (f.user_b = auth.uid() and f.user_a = sp.owner_id)
  join profiles p on p.id = sp.owner_id
  where sp.place_id is not null and sp.is_public
    and sp.owner_id <> auth.uid()
    and sp.lat between p_lat - (p_radius/111000.0)
                   and p_lat + (p_radius/111000.0)
    and sp.lng between p_lng - (p_radius/(111000.0*cos(radians(p_lat))))
                   and p_lng + (p_radius/(111000.0*cos(radians(p_lat))))
  group by sp.place_id;
$$;

grant execute on function friend_saves_near(double precision,double precision,double precision) to authenticated;
