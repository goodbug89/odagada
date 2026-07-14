create table if not exists public.saved_places (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  place_id text,                       -- Google place id (연결형). NULL이면 직접추가형(후속)
  name text not null,
  lat double precision not null,
  lng double precision not null,
  category text,
  memo text,
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists saved_places_owner_place_uniq
  on public.saved_places(owner_id, place_id) where place_id is not null;

create index if not exists saved_places_owner_idx on public.saved_places(owner_id);

alter table public.saved_places enable row level security;

create policy "saved_select_own" on public.saved_places
  for select using (auth.uid() = owner_id);
create policy "saved_insert_own" on public.saved_places
  for insert with check (auth.uid() = owner_id);
create policy "saved_delete_own" on public.saved_places
  for delete using (auth.uid() = owner_id);
create policy "saved_update_own" on public.saved_places
  for update using (auth.uid() = owner_id);
