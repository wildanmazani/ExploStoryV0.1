-- Explo-Story backend schema for Supabase (Postgres).
-- Based on the GDS v0.2 ERD, adapted to Supabase Auth (auth.users holds the
-- e-mail and password hash, so USERS becomes `profiles`).
-- Run once in Supabase: SQL Editor -> New query -> paste -> Run.

-- ---------------------------------------------------------------- profiles (USERS)
create table if not exists public.profiles (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  username    varchar(50) not null unique,
  role        text not null default 'student' check (role in ('student', 'teacher', 'admin')),
  avatar      text not null default 'pelajar_1',
  created_at  timestamptz not null default now()
);

-- create the profile automatically from the sign-up metadata
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id, username, role, avatar)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    case when new.raw_user_meta_data->>'role' = 'teacher' then 'teacher' else 'student' end,
    coalesce(new.raw_user_meta_data->>'avatar', 'pelajar_1')
  )
  on conflict (user_id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- PLAYER_PROGRESS
create table if not exists public.player_progress (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  current_level int not null default 1,
  total_coins   int not null default 0,
  total_exp     int not null default 0,
  last_map_x    real not null default 0,
  last_map_y    real not null default 0,
  save_data     jsonb,             -- full game save (zones, artifacts, figures, ...)
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------- KSSM_TOPICS + SYLLABUS_MASTERY
create table if not exists public.kssm_topics (
  topic_id    text primary key,   -- e.g. t4_b1_1_1 = Tingkatan 4, Bab 1, subtopik 1.1
  topic_name  varchar(150) not null,
  description text
);

insert into public.kssm_topics (topic_id, topic_name) values
  ('t4_b1_1_1', 'Negara Bangsa Kerajaan Alam Melayu'),
  ('t4_b1_1_2', 'Ciri-ciri Negara Bangsa Kesultanan Melayu Melaka'),
  ('t4_b1_1_3', 'Keunggulan Sistem Pentadbiran dan Perundangan'),
  ('t4_b1_1_4', 'Peranan Pemerintah dan Rakyat')
on conflict do nothing;

create table if not exists public.syllabus_mastery (
  mastery_id         bigint generated always as identity primary key,
  user_id            uuid not null references auth.users(id) on delete cascade,
  topic_id           text not null references public.kssm_topics(topic_id),
  correct_answers    int not null default 0,
  incorrect_answers  int not null default 0,
  mastery_percentage real not null default 0,
  updated_at         timestamptz not null default now(),
  unique (user_id, topic_id)
);

-- ---------------------------------------------------------------- CHARACTERS + UNLOCKED_CHARACTERS (Kad Tokoh)
create table if not exists public.characters (
  character_id    text primary key,
  char_name       varchar(100) not null,
  historical_era  varchar(100) not null,
  skin_asset_path varchar(255) not null,
  cost_coins      int not null default 0
);

create table if not exists public.unlocked_characters (
  unlock_id    bigint generated always as identity primary key,
  user_id      uuid not null references auth.users(id) on delete cascade,
  character_id text not null references public.characters(character_id),
  is_unlocked  boolean not null default true,
  unlocked_at  timestamptz not null default now(),
  unique (user_id, character_id)
);

-- ---------------------------------------------------------------- Pau hint usage (anonymous, for teachers)
create table if not exists public.hint_usage (
  id         bigint generated always as identity primary key,
  puzzle_id  text not null,
  tier       smallint not null check (tier between 1 and 3),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- Phase 2: BATTLE_SESSIONS, AI_EVALUATION_LOGS, PVP_ROOMS
create table if not exists public.battle_sessions (
  session_id     bigint generated always as identity primary key,
  user_id        uuid not null references auth.users(id) on delete cascade,
  topic_id       text references public.kssm_topics(topic_id),
  mode           varchar(20) not null,          -- 'PVC' | 'PVP'
  score_achieved int not null default 0,
  result         varchar(20) not null,          -- 'Victory' | 'Defeat'
  created_at     timestamptz not null default now()
);

create table if not exists public.ai_evaluation_logs (
  log_id              bigint generated always as identity primary key,
  session_id          bigint not null references public.battle_sessions(session_id) on delete cascade,
  question_id         int not null,
  student_answer      text not null,
  ai_confidence_score real not null,
  ai_decision         boolean not null,
  teacher_override    boolean
);

create table if not exists public.pvp_rooms (
  room_id      bigint generated always as identity primary key,
  room_code    varchar(8) not null unique,
  host_user_id uuid not null references auth.users(id) on delete cascade,
  max_players  int not null default 2 check (max_players between 2 and 8),
  status       text not null default 'waiting' check (status in ('waiting', 'active', 'closed')),
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------- Row Level Security
alter table public.profiles            enable row level security;
alter table public.player_progress     enable row level security;
alter table public.kssm_topics         enable row level security;
alter table public.syllabus_mastery    enable row level security;
alter table public.characters          enable row level security;
alter table public.unlocked_characters enable row level security;
alter table public.hint_usage          enable row level security;
alter table public.battle_sessions     enable row level security;
alter table public.ai_evaluation_logs  enable row level security;
alter table public.pvp_rooms           enable row level security;

create or replace function public.is_teacher() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where user_id = auth.uid() and role in ('teacher', 'admin'));
$$;

-- profiles: everyone signed in can read usernames; you edit only yours
create policy "profiles read" on public.profiles for select to authenticated using (true);
create policy "profiles update own" on public.profiles for update to authenticated using (user_id = auth.uid());

-- progress & mastery: own rows; teachers can read all (class analytics)
create policy "progress own" on public.player_progress for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "progress teacher read" on public.player_progress for select to authenticated using (public.is_teacher());
create policy "mastery own" on public.syllabus_mastery for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "mastery teacher read" on public.syllabus_mastery for select to authenticated using (public.is_teacher());

-- static content: readable by anyone
create policy "topics read" on public.kssm_topics for select using (true);
create policy "characters read" on public.characters for select using (true);
create policy "unlocks own" on public.unlocked_characters for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- hint usage: anyone (even guests) may insert, only teachers read
create policy "hints insert" on public.hint_usage for insert to anon, authenticated with check (true);
create policy "hints teacher read" on public.hint_usage for select to authenticated using (public.is_teacher());

-- phase 2 tables: own rows
create policy "battles own" on public.battle_sessions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "ai logs teacher" on public.ai_evaluation_logs for all to authenticated using (public.is_teacher());
create policy "rooms read" on public.pvp_rooms for select to authenticated using (true);
create policy "rooms host" on public.pvp_rooms for all to authenticated
  using (host_user_id = auth.uid()) with check (host_user_id = auth.uid());
