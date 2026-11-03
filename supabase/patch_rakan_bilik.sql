-- Explo-Story: open friends and rooms (November 2026).
-- Run ONCE in Supabase: SQL Editor -> New query -> paste -> Run.
-- Safe to run again. supabase/multiplayer.sql already has these rules for a
-- new project; this file updates a project set up before them.
--
-- 1. Adding a Player ID makes you friends straight away, both ways (no
--    waiting for the other player to add you back). Requests left waiting
--    under the old rule become friendships now.
-- 2. Anyone with a room code can join the room, friend or not.
-- 3. A room can start with 2 players.

create or replace function public.add_friend(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare other uuid;
begin
  select user_id into other from profiles where player_code = upper(trim(p_code));
  if other is null then return 'not_found'; end if;
  if other = auth.uid() then return 'self'; end if;
  insert into friends (user_id, friend_id, status) values (auth.uid(), other, 'accepted')
    on conflict (user_id, friend_id) do update set status = 'accepted';
  insert into friends (user_id, friend_id, status) values (other, auth.uid(), 'accepted')
    on conflict (user_id, friend_id) do update set status = 'accepted';
  return 'accepted';
end $$;

-- requests waiting under the old rule
update public.friends set status = 'accepted' where status = 'pending';
insert into public.friends (user_id, friend_id, status)
  select friend_id, user_id, 'accepted' from public.friends
  on conflict (user_id, friend_id) do update set status = 'accepted';

create or replace function public.join_room(p_code text, p_name text, p_avatar text, p_skin text) returns text
language plpgsql security definer set search_path = public as $$
declare r battle_rooms;
begin
  select * into r from battle_rooms where code = upper(trim(p_code));
  if r.code is null then return 'not_found'; end if;
  if r.status <> 'lobby' then return 'started'; end if;
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
  if n < 2 then return 'too_few'; end if;   -- you + at least 1 other player
  update battle_rooms set status = 'question', round = 1,
    qid = (select qid from battle_answers order by random() limit 1),
    round_ends = now() + interval '30 seconds', hits = '[]' where code = p_code;
  return 'ok';
end $$;
