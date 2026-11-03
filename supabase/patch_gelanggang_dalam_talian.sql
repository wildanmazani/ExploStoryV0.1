-- Explo-Story: the Gelanggang online (November 2026).
-- Run ONCE in Supabase: SQL Editor -> New query -> paste -> Run (after
-- patch_tetapan_bilik.sql). Safe to run again.
--
-- A room can now be a Kuiz (as before) or a Gelanggang. The fight itself
-- does not go through the database: the room host's game runs it and talks to
-- the other players over Supabase Realtime (channel "gel-<room code>"). The
-- database only keeps the room, its settings and who is in it.
--   game_mode : 'kuiz' | 'gelanggang'
--   stage     : 'sekolah' | 'pokok' | 'gua' (the host's progress opens them,
--               checked in the game)
-- Starting a Gelanggang room sets status = 'gelanggang'; the lobby of every
-- player then opens the Gelanggang screen.

alter table public.battle_rooms add column if not exists stage text not null default 'sekolah';
alter table public.battle_rooms drop constraint if exists battle_rooms_status_check;
alter table public.battle_rooms add constraint battle_rooms_status_check
  check (status in ('lobby', 'question', 'reveal', 'over', 'gelanggang'));

create or replace function public.set_room_options(p_code text, p_chapter int, p_team text, p_level text,
  p_mode text, p_stage text) returns text
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from battle_rooms where code = p_code and host = auth.uid() and status = 'lobby') then
    return 'not_host';
  end if;
  if not exists (select 1 from battle_answers where chapter = p_chapter) then return 'no_chapter'; end if;
  if p_team not in ('pvp', 'coop') then return 'bad_team'; end if;
  if p_level not in ('mudah', 'biasa', 'sukar') then return 'bad_level'; end if;
  if p_mode not in ('kuiz', 'gelanggang') then return 'bad_mode'; end if;
  if p_stage not in ('sekolah', 'pokok', 'gua') then return 'bad_stage'; end if;
  update battle_rooms set chapter = p_chapter, team = p_team, bot_level = p_level, game_mode = p_mode, stage = p_stage
    where code = p_code;
  return 'ok';
end $$;

grant execute on function public.set_room_options(text, int, text, text, text, text) to authenticated;

-- the Gelanggang starts without database rounds
create or replace function public.start_battle(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare n int; r battle_rooms; names text[] := array['Aisyah', 'Ravi', 'Mei Ling', 'Daniel', 'Aisyah'];
  skins text[] := array['rakan_aisyah', 'rakan_ravi', 'rakan_meiling', 'rakan_daniel', 'rakan_aisyah'];
begin
  select * into r from battle_rooms where code = p_code and host = auth.uid() and status = 'lobby';
  if r.code is null then return 'not_host'; end if;
  select count(*) into n from battle_players where code = p_code;
  if r.team = 'pvp' and n < 2 then return 'too_few'; end if;   -- you + at least 1 other player
  if r.game_mode = 'gelanggang' then
    update battle_rooms set status = 'gelanggang' where code = p_code;
    return 'ok';
  end if;
  update battle_rooms set status = 'question', round = 1,
    qid = (select qid from battle_answers where chapter = r.chapter order by random() limit 1),
    round_ends = now() + interval '30 seconds', hits = '[]',
    bots = case when r.team = 'coop' then (
      select jsonb_agg(jsonb_build_object('id', 'bot' || i, 'name', names[i], 'skin', skins[i],
        'hp', 100, 'alive', true, 'answer', -1) order by i)
      from generate_series(1, n) i) else '[]' end
    where code = p_code;
  return 'ok';
end $$;

-- battle_state also tells the stage
create or replace function public.battle_state(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r battle_rooms; result text;
begin
  if not exists (select 1 from battle_players where code = p_code and user_id = auth.uid()) then
    return null;
  end if;
  perform _battle_tick(p_code);
  select * into r from battle_rooms where code = p_code;
  result := case
    when r.status <> 'over' or r.team <> 'coop' then coalesce(r.winner::text, '')
    when exists (select 1 from jsonb_array_elements(r.bots) e where (e->>'alive')::boolean) then 'bots'
    else 'team' end;
  return jsonb_build_object(
    'code', r.code, 'host', r.host, 'status', r.status, 'round', r.round, 'qid', r.qid,
    'chapter', r.chapter, 'team', r.team, 'bot_level', r.bot_level, 'game_mode', r.game_mode, 'stage', r.stage,
    'time_left', greatest(0, coalesce(extract(epoch from (r.round_ends - now())), 0)),
    'answer', case when r.status in ('reveal', 'over') then r.answer end,
    'hits', case when r.status = 'over' and r.team = 'coop' then '[]'::jsonb else r.hits end,
    'winner', result,
    'players', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', bp.user_id, 'name', bp.name, 'avatar', bp.avatar, 'skin', bp.skin,
        'hp', bp.hp, 'alive', bp.alive, 'target', coalesce(bp.target::text, ''),
        'answered', bp.answer >= 0, 'bot', false,
        'answer', case when bp.user_id = auth.uid() or r.status <> 'question' then bp.answer else -1 end
      ) order by bp.joined_at), '[]') from battle_players bp where bp.code = p_code)
      || (select coalesce(jsonb_agg(jsonb_build_object(
        'id', e->>'id', 'name', e->>'name', 'avatar', 'pelajar_1', 'skin', e->>'skin',
        'hp', (e->>'hp')::int, 'alive', (e->>'alive')::boolean, 'target', '',
        'answered', true, 'bot', true,
        'answer', case when r.status = 'question' then -1 else (e->>'answer')::int end)), '[]')
        from jsonb_array_elements(r.bots) e));
end $$;
