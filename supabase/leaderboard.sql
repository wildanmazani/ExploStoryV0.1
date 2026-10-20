-- Explo-Story: Papan Markah (leaderboard) for Supabase.
-- Run AFTER supabase/schema.sql and supabase/multiplayer.sql (it uses the
-- friends table): SQL Editor -> New query -> paste -> Run.
--
-- Ranked by total EXP, then battle wins. Three scopes: 'all' (the whole
-- server), 'negeri' (the caller's state) and 'friends' (accepted friends +
-- the caller). The game pushes its own numbers with update_my_stats().
--
-- STATUS: written for scripts/autoload/backend.gd and
-- scripts/ui/papan_panel.gd, NOT tested against a live project yet.

alter table public.profiles add column if not exists display_name text;
alter table public.profiles add column if not exists skin         text not null default 'alif';
alter table public.profiles add column if not exists negeri       text not null default '';
alter table public.profiles add column if not exists total_exp    int  not null default 0;
alter table public.profiles add column if not exists wins         int  not null default 0;
alter table public.profiles add column if not exists stats_at     timestamptz;

create index if not exists profiles_rank_idx on public.profiles (total_exp desc, wins desc);

-- a player can only write their own row; numbers are clamped so one edited
-- save cannot jump past everyone (max one Bab worth of EXP per call)
create or replace function public.update_my_stats(p_name text, p_skin text, p_negeri text, p_exp int, p_wins int)
returns void language plpgsql security definer set search_path = public as $$
begin
  update profiles set
    display_name = left(coalesce(nullif(trim(p_name), ''), username), 16),
    skin         = left(coalesce(p_skin, 'alif'), 32),
    negeri       = left(coalesce(p_negeri, ''), 32),
    total_exp    = greatest(total_exp, least(greatest(p_exp, 0), total_exp + 2000)),
    wins         = greatest(wins, least(greatest(p_wins, 0), wins + 50)),
    stats_at     = now()
  where user_id = auth.uid();
end $$;

-- {rows: [{rank, name, skin, negeri, exp, wins, me}], me: {...} or null}
-- rows = top 50 of the scope; me = the caller's own row (also when outside the top)
create or replace function public.leaderboard(p_scope text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare my_negeri text; result jsonb;
begin
  select negeri into my_negeri from profiles where user_id = auth.uid();
  with scoped as (
    select p.* from profiles p
    where p.role = 'student'
      and case p_scope
        when 'negeri'  then p.negeri <> '' and p.negeri = my_negeri
        when 'friends' then p.user_id = auth.uid() or _are_friends(auth.uid(), p.user_id)
        else true end
  ), ranked as (
    select rank() over (order by total_exp desc, wins desc) as rank,
           coalesce(display_name, username) as name, skin, negeri,
           total_exp as exp, wins, user_id = auth.uid() as me
    from scoped
  )
  select jsonb_build_object(
    'rows', coalesce((select jsonb_agg(to_jsonb(r) order by r.rank) from (select * from ranked order by rank limit 50) r), '[]'),
    'me',   (select to_jsonb(r) from ranked r where r.me limit 1)
  ) into result;
  return result;
end $$;

grant execute on function public.update_my_stats(text, text, text, int, int) to authenticated;
grant execute on function public.leaderboard(text) to authenticated;
