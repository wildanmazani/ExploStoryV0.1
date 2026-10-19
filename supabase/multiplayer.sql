-- Explo-Story: Bilik Pertarungan (multiplayer battle) for Supabase.
-- Run AFTER supabase/schema.sql: SQL Editor -> New query -> paste -> Run.
--
-- Rules (same numbers as scripts/battle/battle_rules.gd): everyone starts with
-- 100 HP; each round everyone answers the same question; a correct answer hits
-- the chosen target for 25 (+5 for the fastest correct answer); at 0 HP you
-- are out; last one standing wins 20 syiling (given by the game).
-- The server decides who is right and how much damage lands, so players
-- cannot cheat by editing the game. Rooms advance lazily: every call to
-- battle_state() moves the round on when its time is up (no cron needed).
--
-- STATUS: written for scripts/battle/online_battle.gd and
-- scripts/autoload/backend.gd, NOT tested against a live project yet.

-- ---------------------------------------------------------------- player codes + friends
alter table public.profiles add column if not exists player_code varchar(8) unique;

create table if not exists public.friends (
  user_id    uuid not null references auth.users(id) on delete cascade,
  friend_id  uuid not null references auth.users(id) on delete cascade,
  status     text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id)
);

-- ---------------------------------------------------------------- battle tables
create table if not exists public.battle_answers (   -- answer key of data/soalan/bab1.json
  qid    int primary key,
  answer int not null check (answer between 0 and 3)
);

create table if not exists public.battle_rooms (
  code        varchar(6) primary key,
  host        uuid not null references auth.users(id) on delete cascade,
  status      text not null default 'lobby' check (status in ('lobby', 'question', 'reveal', 'over')),
  round       int not null default 0,
  qid         int not null default 0,
  answer      int,
  round_ends  timestamptz,
  reveal_ends timestamptz,
  hits        jsonb not null default '[]',
  winner      uuid,
  created_at  timestamptz not null default now()
);

create table if not exists public.battle_players (
  code        varchar(6) not null references public.battle_rooms(code) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  avatar      text not null default 'pelajar_1',
  skin        text not null default 'alif',
  hp          int not null default 100,
  alive       boolean not null default true,
  target      uuid,
  answer      int not null default -1,
  answered_at timestamptz,
  joined_at   timestamptz not null default now(),
  primary key (code, user_id)
);

-- Tables are only reached through the functions below (security definer).
alter table public.friends        enable row level security;
alter table public.battle_answers enable row level security;
alter table public.battle_rooms   enable row level security;
alter table public.battle_players enable row level security;

-- ---------------------------------------------------------------- helpers
create or replace function public._rand_code(n int) returns text language sql volatile as $$
  select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '')
  from generate_series(1, n);
$$;

create or replace function public.ensure_player_code() returns text
language plpgsql security definer set search_path = public as $$
declare c text;
begin
  select player_code into c from profiles where user_id = auth.uid();
  while c is null loop
    begin
      update profiles set player_code = _rand_code(6) where user_id = auth.uid() returning player_code into c;
    exception when unique_violation then c := null;
    end;
  end loop;
  return c;
end $$;

create or replace function public._are_friends(a uuid, b uuid) returns boolean language sql stable as $$
  select exists (select 1 from public.friends where status = 'accepted'
    and ((user_id = a and friend_id = b) or (user_id = b and friend_id = a)));
$$;

-- ---------------------------------------------------------------- friends
-- add by Player ID; when both have added each other the pair is accepted
create or replace function public.add_friend(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare other uuid;
begin
  select user_id into other from profiles where player_code = upper(trim(p_code));
  if other is null then return 'not_found'; end if;
  if other = auth.uid() then return 'self'; end if;
  if exists (select 1 from friends where user_id = other and friend_id = auth.uid()) then
    update friends set status = 'accepted' where user_id = other and friend_id = auth.uid();
    insert into friends (user_id, friend_id, status) values (auth.uid(), other, 'accepted')
      on conflict (user_id, friend_id) do update set status = 'accepted';
    return 'accepted';
  end if;
  insert into friends (user_id, friend_id) values (auth.uid(), other) on conflict do nothing;
  return 'pending';
end $$;

create or replace function public.my_friends() returns jsonb
language sql security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', p.user_id, 'name', p.username, 'avatar', p.avatar, 'code', p.player_code,
      'status', case when f.status = 'accepted' then 'accepted'
                     when f.user_id = auth.uid() then 'outgoing' else 'incoming' end)), '[]')
  from friends f
  join profiles p on p.user_id = case when f.user_id = auth.uid() then f.friend_id else f.user_id end
  where (f.user_id = auth.uid() or f.friend_id = auth.uid())
    and not (f.status = 'accepted' and f.friend_id = auth.uid());  -- one row per accepted pair
$$;

-- ---------------------------------------------------------------- rooms
create or replace function public.create_room(p_name text, p_avatar text, p_skin text) returns text
language plpgsql security definer set search_path = public as $$
declare c text;
begin
  loop
    c := _rand_code(6);
    begin
      insert into battle_rooms (code, host) values (c, auth.uid());
      exit;
    exception when unique_violation then null;
    end;
  end loop;
  insert into battle_players (code, user_id, name, avatar, skin) values (c, auth.uid(), p_name, p_avatar, p_skin);
  return c;
end $$;

-- only friends of the host can join (the game's rule: play with friends)
create or replace function public.join_room(p_code text, p_name text, p_avatar text, p_skin text) returns text
language plpgsql security definer set search_path = public as $$
declare r battle_rooms;
begin
  select * into r from battle_rooms where code = upper(trim(p_code));
  if r.code is null then return 'not_found'; end if;
  if r.status <> 'lobby' then return 'started'; end if;
  if r.host <> auth.uid() and not _are_friends(r.host, auth.uid()) then return 'not_friends'; end if;
  if (select count(*) from battle_players where code = r.code) >= 5 then return 'full'; end if;
  insert into battle_players (code, user_id, name, avatar, skin) values (r.code, auth.uid(), p_name, p_avatar, p_skin)
    on conflict (code, user_id) do nothing;
  return 'ok';
end $$;

create or replace function public.start_battle(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not exists (select 1 from battle_rooms where code = p_code and host = auth.uid() and status = 'lobby') then
    return 'not_host';
  end if;
  select count(*) into n from battle_players where code = p_code;
  if n < 3 then return 'too_few'; end if;   -- you + at least 2 friends
  update battle_rooms set status = 'question', round = 1,
    qid = (select qid from battle_answers order by random() limit 1),
    round_ends = now() + interval '30 seconds', hits = '[]' where code = p_code;
  return 'ok';
end $$;

-- ---------------------------------------------------------------- playing
create or replace function public.battle_target(p_code text, p_target uuid) returns void
language sql security definer set search_path = public as $$
  update public.battle_players set target = p_target
  where code = p_code and user_id = auth.uid() and p_target <> auth.uid();
$$;

create or replace function public.battle_answer(p_code text, p_round int, p_answer int, p_target uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update battle_players bp set answer = p_answer, answered_at = now(),
    target = coalesce(p_target, bp.target)
  from battle_rooms r
  where r.code = p_code and bp.code = p_code and bp.user_id = auth.uid()
    and r.status = 'question' and r.round = p_round and bp.alive and bp.answer = -1;
end $$;

create or replace function public.battle_leave(p_code text) returns void
language sql security definer set search_path = public as $$
  update public.battle_players set alive = false, hp = 0 where code = p_code and user_id = auth.uid();
$$;

-- moves the room on when a round's time is up (called by battle_state)
create or replace function public._battle_tick(p_code text) returns void
language plpgsql security definer set search_path = public as $$
declare
  r battle_rooms;
  correct int;
  fastest uuid;
  p record;
  t uuid;
  new_hits jsonb := '[]';
  standing int;
begin
  select * into r from battle_rooms where code = p_code for update;
  if r.code is null then return; end if;

  if r.status = 'question' and (now() >= r.round_ends or not exists (
      select 1 from battle_players where code = p_code and alive and answer = -1)) then
    select answer into correct from battle_answers where qid = r.qid;
    select user_id into fastest from battle_players
      where code = p_code and alive and answer = correct order by answered_at limit 1;
    for p in select * from battle_players where code = p_code and alive and answer = correct loop
      t := p.target;
      if t is null or t = p.user_id or not exists (
          select 1 from battle_players where code = p_code and user_id = t and alive) then
        select user_id into t from battle_players
          where code = p_code and alive and user_id <> p.user_id order by hp, user_id limit 1;
      end if;
      if t is not null then
        new_hits := new_hits || jsonb_build_array(jsonb_build_object('from', p.user_id, 'to', t,
          'dmg', 25 + case when p.user_id = fastest then 5 else 0 end));
      end if;
    end loop;
    -- all damage lands at the same moment
    update battle_players bp set hp = greatest(0, bp.hp - d.total)
    from (select (h->>'to')::uuid as uid, sum((h->>'dmg')::int) as total
          from jsonb_array_elements(new_hits) h group by 1) d
    where bp.code = p_code and bp.user_id = d.uid;
    update battle_players set alive = false where code = p_code and alive and hp <= 0;
    update battle_rooms set status = 'reveal', answer = correct, hits = new_hits,
      reveal_ends = now() + interval '4 seconds' where code = p_code;

  elsif r.status = 'reveal' and now() >= r.reveal_ends then
    select count(*) into standing from battle_players where code = p_code and alive;
    if standing > 1 then
      update battle_players set answer = -1, answered_at = null where code = p_code;
      update battle_rooms set status = 'question', round = r.round + 1, answer = null, hits = '[]',
        qid = (select qid from battle_answers where qid <> r.qid order by random() limit 1),
        round_ends = now() + interval '30 seconds' where code = p_code;
    else
      update battle_rooms set status = 'over',
        winner = (select user_id from battle_players where code = p_code and alive limit 1)
        where code = p_code;
    end if;
  end if;
end $$;

-- the whole room as the game needs it (others' answers stay hidden until the reveal)
create or replace function public.battle_state(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r battle_rooms;
begin
  if not exists (select 1 from battle_players where code = p_code and user_id = auth.uid()) then
    return null;
  end if;
  perform _battle_tick(p_code);
  select * into r from battle_rooms where code = p_code;
  return jsonb_build_object(
    'code', r.code, 'host', r.host, 'status', r.status, 'round', r.round, 'qid', r.qid,
    'time_left', greatest(0, coalesce(extract(epoch from (r.round_ends - now())), 0)),
    'answer', case when r.status in ('reveal', 'over') then r.answer end,
    'hits', r.hits, 'winner', coalesce(r.winner::text, ''),
    'players', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', bp.user_id, 'name', bp.name, 'avatar', bp.avatar, 'skin', bp.skin,
        'hp', bp.hp, 'alive', bp.alive, 'target', coalesce(bp.target::text, ''),
        'answered', bp.answer >= 0,
        'answer', case when bp.user_id = auth.uid() or r.status <> 'question' then bp.answer else -1 end
      ) order by bp.joined_at), '[]') from battle_players bp where bp.code = p_code));
end $$;

-- ---------------------------------------------------------------- answer key (from data/soalan/bab1.json)
insert into public.battle_answers (qid, answer) values
  (0, 2),
  (1, 3),
  (2, 1),
  (3, 2),
  (4, 1),
  (5, 2),
  (6, 3),
  (7, 1),
  (8, 2),
  (9, 3),
  (10, 1),
  (11, 3),
  (12, 2),
  (13, 2),
  (14, 3),
  (15, 0),
  (16, 0),
  (17, 1),
  (18, 1),
  (19, 3),
  (20, 0),
  (21, 1),
  (22, 3),
  (23, 1),
  (24, 1),
  (25, 3),
  (26, 0),
  (27, 0),
  (28, 3),
  (29, 1),
  (30, 3),
  (31, 0)
on conflict (qid) do update set answer = excluded.answer;
