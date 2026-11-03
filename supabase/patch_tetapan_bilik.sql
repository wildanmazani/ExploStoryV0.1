-- Explo-Story: room settings (November 2026).
-- Run ONCE in Supabase: SQL Editor -> New query -> paste -> Run (after
-- patch_rakan_bilik.sql). Safe to run again.
--
-- The host of a room chooses, before starting:
--   chapter   : which Bab the questions come from (1 or 2 so far)
--   team      : 'pvp'  = everyone against everyone (as before)
--               'coop' = all the players as one team against bots
--   bot_level : 'mudah' | 'biasa' | 'sukar' (coop only: how often bots are right)
--   game_mode : 'kuiz' only for now (the Gelanggang online is locked in the game)
-- In coop every player has one bot opposite them. Correct answers from the
-- team hit the weakest bot; each bot that answers right hits a random player.
-- The team wins when every bot is down (winner = 'team'), the bots when every
-- player is (winner = 'bots').

-- ---------------------------------------------------------------- columns
alter table public.battle_rooms add column if not exists chapter   int  not null default 1;
alter table public.battle_rooms add column if not exists team      text not null default 'pvp';
alter table public.battle_rooms add column if not exists bot_level text not null default 'mudah';
alter table public.battle_rooms add column if not exists game_mode text not null default 'kuiz';
alter table public.battle_rooms add column if not exists bots      jsonb not null default '[]';

-- the answer key now covers more than one chapter: (chapter, qid)
alter table public.battle_answers add column if not exists chapter int not null default 1;
alter table public.battle_answers drop constraint if exists battle_answers_pkey;
alter table public.battle_answers add primary key (chapter, qid);

-- Bab 2 answer key (data/soalan/bab2.json, question number = position in the file)
insert into public.battle_answers (chapter, qid, answer) values
  (2, 0, 3),
  (2, 1, 1),
  (2, 2, 0),
  (2, 3, 0),
  (2, 4, 1),
  (2, 5, 1),
  (2, 6, 0),
  (2, 7, 2),
  (2, 8, 0),
  (2, 9, 3),
  (2, 10, 1),
  (2, 11, 3),
  (2, 12, 3),
  (2, 13, 1),
  (2, 14, 2),
  (2, 15, 1),
  (2, 16, 3),
  (2, 17, 1),
  (2, 18, 2),
  (2, 19, 2),
  (2, 20, 0),
  (2, 21, 2),
  (2, 22, 3),
  (2, 23, 1),
  (2, 24, 2),
  (2, 25, 3),
  (2, 26, 3),
  (2, 27, 0),
  (2, 28, 1),
  (2, 29, 0),
  (2, 30, 0),
  (2, 31, 2),
  (2, 32, 2),
  (2, 33, 3),
  (2, 34, 0),
  (2, 35, 0),
  (2, 36, 2),
  (2, 37, 1),
  (2, 38, 2),
  (2, 39, 3),
  (2, 40, 2)
on conflict (chapter, qid) do update set answer = excluded.answer;

-- ---------------------------------------------------------------- settings
create or replace function public.set_room_config(p_code text, p_chapter int, p_team text, p_level text) returns text
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from battle_rooms where code = p_code and host = auth.uid() and status = 'lobby') then
    return 'not_host';
  end if;
  if not exists (select 1 from battle_answers where chapter = p_chapter) then return 'no_chapter'; end if;
  if p_team not in ('pvp', 'coop') then return 'bad_team'; end if;
  if p_level not in ('mudah', 'biasa', 'sukar') then return 'bad_level'; end if;
  update battle_rooms set chapter = p_chapter, team = p_team, bot_level = p_level, game_mode = 'kuiz'
    where code = p_code;
  return 'ok';
end $$;

-- ---------------------------------------------------------------- start
create or replace function public.start_battle(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare n int; r battle_rooms; names text[] := array['Aisyah', 'Ravi', 'Mei Ling', 'Daniel', 'Aisyah'];
  skins text[] := array['rakan_aisyah', 'rakan_ravi', 'rakan_meiling', 'rakan_daniel', 'rakan_aisyah'];
begin
  select * into r from battle_rooms where code = p_code and host = auth.uid() and status = 'lobby';
  if r.code is null then return 'not_host'; end if;
  select count(*) into n from battle_players where code = p_code;
  if r.team = 'pvp' and n < 2 then return 'too_few'; end if;   -- you + at least 1 other player
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

-- ---------------------------------------------------------------- one round
create or replace function public._battle_tick(p_code text) returns void
language plpgsql security definer set search_path = public as $$
declare
  r battle_rooms;
  correct int;
  fastest uuid;
  p record;
  b jsonb;
  t uuid;
  weak text;
  acc float;
  new_hits jsonb := '[]';
  new_bots jsonb := '[]';
  standing int;
  bots_up int;
begin
  select * into r from battle_rooms where code = p_code for update;
  if r.code is null then return; end if;

  if r.status = 'question' and (now() >= r.round_ends or not exists (
      select 1 from battle_players where code = p_code and alive and answer = -1)) then
    select answer into correct from battle_answers where chapter = r.chapter and qid = r.qid;
    select user_id into fastest from battle_players
      where code = p_code and alive and answer = correct order by answered_at limit 1;

    if r.team = 'coop' then
      -- the team hits the weakest bot still up
      select e->>'id' into weak from jsonb_array_elements(r.bots) e
        where (e->>'alive')::boolean order by (e->>'hp')::int, e->>'id' limit 1;
      for p in select * from battle_players where code = p_code and alive and answer = correct loop
        if weak is not null then
          new_hits := new_hits || jsonb_build_array(jsonb_build_object('from', p.user_id, 'to', weak,
            'dmg', 25 + case when p.user_id = fastest then 5 else 0 end));
        end if;
      end loop;
      -- each bot answers: right often enough for its level, then hits someone
      acc := case r.bot_level when 'sukar' then 0.8 when 'biasa' then 0.64 else 0.48 end;
      for b in select e from jsonb_array_elements(r.bots) e loop
        if (b->>'alive')::boolean then
          if random() < acc then
            b := jsonb_set(b, '{answer}', to_jsonb(correct));
            select user_id into t from battle_players where code = p_code and alive order by random() limit 1;
            if t is not null then
              new_hits := new_hits || jsonb_build_array(jsonb_build_object('from', b->>'id', 'to', t, 'dmg', 25));
            end if;
          else
            b := jsonb_set(b, '{answer}', to_jsonb((correct + 1 + floor(random() * 3)::int) % 4));
          end if;
        end if;
        new_bots := new_bots || jsonb_build_array(b);
      end loop;
      -- damage on the bots
      select coalesce(jsonb_agg(case when d.total is null then e
          else jsonb_set(jsonb_set(e, '{hp}', to_jsonb(greatest(0, (e->>'hp')::int - d.total))),
                         '{alive}', to_jsonb((e->>'hp')::int - d.total > 0)) end), '[]')
        into new_bots
        from jsonb_array_elements(new_bots) e
        left join (select h->>'to' as id, sum((h->>'dmg')::int) as total
                   from jsonb_array_elements(new_hits) h where h->>'to' like 'bot%' group by 1) d
          on d.id = e->>'id';
      update battle_rooms set bots = new_bots where code = p_code;
    else
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
    end if;

    -- damage on the players lands at the same moment
    update battle_players bp set hp = greatest(0, bp.hp - d.total)
    from (select (h->>'to')::uuid as uid, sum((h->>'dmg')::int) as total
          from jsonb_array_elements(new_hits) h where h->>'to' not like 'bot%' group by 1) d
    where bp.code = p_code and bp.user_id = d.uid;
    update battle_players set alive = false where code = p_code and alive and hp <= 0;
    update battle_rooms set status = 'reveal', answer = correct, hits = new_hits,
      reveal_ends = now() + interval '4 seconds' where code = p_code;

  elsif r.status = 'reveal' and now() >= r.reveal_ends then
    select count(*) into standing from battle_players where code = p_code and alive;
    if r.team = 'coop' then
      select count(*) into bots_up from jsonb_array_elements(r.bots) e where (e->>'alive')::boolean;
      if standing > 0 and bots_up > 0 then
        update battle_players set answer = -1, answered_at = null where code = p_code;
        update battle_rooms set status = 'question', round = r.round + 1, answer = null, hits = '[]',
          bots = (select jsonb_agg(jsonb_set(e, '{answer}', '-1'::jsonb)) from jsonb_array_elements(r.bots) e),
          qid = (select qid from battle_answers where chapter = r.chapter and qid <> r.qid order by random() limit 1),
          round_ends = now() + interval '30 seconds' where code = p_code;
      else
        update battle_rooms set status = 'over', winner = null where code = p_code;
        update battle_rooms set hits = jsonb_build_array(jsonb_build_object('result', case when bots_up = 0 then 'team' else 'bots' end))
          where code = p_code;
      end if;
    elsif standing > 1 then
      update battle_players set answer = -1, answered_at = null where code = p_code;
      update battle_rooms set status = 'question', round = r.round + 1, answer = null, hits = '[]',
        qid = (select qid from battle_answers where chapter = r.chapter and qid <> r.qid order by random() limit 1),
        round_ends = now() + interval '30 seconds' where code = p_code;
    else
      update battle_rooms set status = 'over',
        winner = (select user_id from battle_players where code = p_code and alive limit 1)
        where code = p_code;
    end if;
  end if;
end $$;

-- ---------------------------------------------------------------- what the game sees
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
    'chapter', r.chapter, 'team', r.team, 'bot_level', r.bot_level, 'game_mode', r.game_mode,
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

grant execute on function public.set_room_config(text, int, text, text) to authenticated;
