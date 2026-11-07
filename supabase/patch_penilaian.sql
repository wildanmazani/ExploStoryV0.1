-- Kotak bintang: anonymous 1-5 star ratings of the game (scripts/ui/kotak_bintang.gd).
-- Run once in Supabase > SQL Editor. Read them in Table Editor > game_ratings.
-- No name, e-mail or user id is stored.
--
-- context: hud (star button), misi_1_1 (after Misi 1.1), bab_1 (after Bab 1)
--
-- Summary:
--   select context, count(*), round(avg(stars), 2) from public.game_ratings group by context;
--   select stars, count(*) from public.game_ratings group by stars order by stars;

create table if not exists public.game_ratings (
  id         bigint generated always as identity primary key,
  stars      smallint not null check (stars between 1 and 5),
  comment    text check (char_length(comment) <= 300),
  context    text check (char_length(context) <= 20),
  level      smallint,
  bab        smallint,
  lang       text check (char_length(lang) <= 5),
  device     text check (char_length(device) <= 10),
  created_at timestamptz not null default now()
);

alter table public.game_ratings enable row level security;

-- anyone (even guests) may add a rating; only teachers read them in the game
drop policy if exists "ratings insert" on public.game_ratings;
create policy "ratings insert" on public.game_ratings for insert to anon, authenticated with check (true);
drop policy if exists "ratings teacher read" on public.game_ratings;
create policy "ratings teacher read" on public.game_ratings for select to authenticated using (public.is_teacher());
