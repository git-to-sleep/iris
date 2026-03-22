-- ═══════════════════════════════════════
--  IRIS · Supabase Database Setup
--  Run this in your Supabase SQL Editor
-- ═══════════════════════════════════════

-- 1. Profiles table (stores users + credits)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  email text not null,
  credits integer not null default 10,
  created_at timestamptz default now()
);

-- 2. Enable Row Level Security
alter table public.profiles enable row level security;

-- 3. Users can only read/update their own profile
create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- 4. Auto-create profile with 10 credits on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, credits)
  values (new.id, new.email, 10);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 5. Function to deduct credits (call from your app)
create or replace function public.deduct_credit(user_id uuid, amount integer)
returns integer as $$
declare
  new_credits integer;
begin
  update public.profiles
  set credits = credits - amount
  where id = user_id and credits >= amount
  returning credits into new_credits;

  if not found then
    raise exception 'Insufficient credits';
  end if;

  return new_credits;
end;
$$ language plpgsql security definer;
