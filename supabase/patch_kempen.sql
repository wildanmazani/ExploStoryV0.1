-- Kempen Syiling (scripts/ui/kempen_panel.gd), until 16 Nov 2026, 12:00 tengah malam (MYT).
--   Beri maklum balas (bintang + komen): +150 syiling
--   Kongsi pautan game dengan kawan:     +100 syiling
-- Once per account, for signed-in accounts with a confirmed e-mail.
-- Run once in Supabase > SQL Editor.
--
-- Read the feedback:
--   select k.created_at, u.email, k.stars, k.comment
--     from public.campaign_claims k join auth.users u on u.id = k.user_id
--    where k.kind = 'feedback' order by k.created_at desc;
-- Totals:
--   select kind, count(*), round(avg(stars), 2) from public.campaign_claims group by kind;
--
-- To end it early or extend it, change kempen_ends() below and run it again.

create table if not exists public.campaign_claims (
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       text not null check (kind in ('feedback', 'share')),
  stars      smallint check (stars between 1 and 5),
  comment    text check (char_length(comment) <= 500),
  created_at timestamptz not null default now(),
  primary key (user_id, kind)
);

alter table public.campaign_claims enable row level security;
-- no direct access: only through the functions below (and teachers may read)
drop policy if exists "claims teacher read" on public.campaign_claims;
create policy "claims teacher read" on public.campaign_claims for select to authenticated using (public.is_teacher());

-- 16 Nov 2026 00:00 in Malaysia (UTC+8)
create or replace function public.kempen_ends() returns timestamptz
language sql immutable as $$ select timestamptz '2026-11-16 00:00:00+08' $$;

-- what this account has already claimed, and when the campaign ends
create or replace function public.kempen_status() returns json
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    return json_build_object('ends', kempen_ends(), 'claimed', json_build_array());
  end if;
  return json_build_object(
    'ends', kempen_ends(),
    'open', now() < kempen_ends(),
    'claimed', coalesce((select json_agg(kind) from campaign_claims where user_id = me), json_build_array()));
end $$;

-- returns 'ok', 'already', 'ended', 'unverified', 'short' or 'signin'
create or replace function public.kempen_claim(p_kind text, p_stars int default null, p_comment text default null) returns text
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then return 'signin'; end if;
  if now() >= kempen_ends() then return 'ended'; end if;
  if not exists (select 1 from auth.users where id = me and email_confirmed_at is not null) then
    return 'unverified';
  end if;
  if p_kind = 'feedback' then
    if p_stars is null or p_stars < 1 or p_stars > 5 or char_length(trim(coalesce(p_comment, ''))) < 10 then
      return 'short';
    end if;
  elsif p_kind <> 'share' then
    return 'short';
  end if;
  insert into campaign_claims (user_id, kind, stars, comment)
  values (me, p_kind, case when p_kind = 'feedback' then p_stars end,
          case when p_kind = 'feedback' then left(trim(p_comment), 500) end)
  on conflict do nothing;
  if not found then return 'already'; end if;
  return 'ok';
end $$;

revoke all on function public.kempen_claim(text, int, text) from public, anon;
grant execute on function public.kempen_claim(text, int, text) to authenticated;
grant execute on function public.kempen_status() to authenticated;
