-- Explo-Story: room codes of 6 digits, and Main Lagi in a Kuiz room (November 2026).
-- Run ONCE in Supabase: SQL Editor -> New query -> paste -> Run (after
-- patch_gelanggang_dalam_talian.sql). Safe to run again.
--
-- 1. A new room gets a code of 6 digits (e.g. 482913), easier to type than
--    letters. Rooms opened before keep their letter codes until they end.
-- 2. restart_battle: when a Kuiz room is over, its host starts the same room
--    again with the same players (Main Lagi), nobody has to leave.
--    (A Gelanggang room plays again over Realtime and needs nothing here.)

create or replace function public._rand_digits(n int) returns text language sql volatile as $$
  select lpad(floor(random() * power(10, n))::bigint::text, n, '0')
$$;

create or replace function public.create_room(p_name text, p_avatar text, p_skin text) returns text
language plpgsql security definer set search_path = public as $$
declare c text;
begin
  loop
    c := _rand_digits(6);
    begin
      insert into battle_rooms (code, host) values (c, auth.uid());
      exit;
    exception when unique_violation then null;
    end;
  end loop;
  insert into battle_players (code, user_id, name, avatar, skin) values (c, auth.uid(), p_name, p_avatar, p_skin);
  return c;
end $$;

-- the host of a finished Kuiz room: everyone back to full HP, a new first round
create or replace function public.restart_battle(p_code text) returns text
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from battle_rooms where code = p_code and host = auth.uid() and status = 'over') then
    return 'not_host';
  end if;
  update battle_players set hp = 100, alive = true, target = null, answer = -1, answered_at = null
    where code = p_code;
  update battle_rooms set status = 'lobby', round = 0, winner = null, hits = '[]', bots = '[]'
    where code = p_code;
  return start_battle(p_code);
end $$;

grant execute on function public.create_room(text, text, text) to authenticated;
grant execute on function public.restart_battle(text) to authenticated;
