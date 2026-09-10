create extension if not exists "pgcrypto";

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  university text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users(id) on delete set null,
  title text not null check (char_length(title) between 3 and 160),
  company text not null check (char_length(company) between 2 and 120),
  category text not null check (category in ('Internship','Full-time','Freelance','Hackathon')),
  location text not null default 'Remote', description text not null, skills text[] not null default '{}',
  apply_url text not null, deadline date, status text not null default 'published' check (status in ('draft','published','closed')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.saved_opportunities (
  user_id uuid not null references auth.users(id) on delete cascade,
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  created_at timestamptz not null default now(), primary key (user_id, opportunity_id)
);
create table public.applications (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  opportunity_id uuid not null references public.opportunities(id) on delete cascade,
  status text not null default 'saved' check (status in ('saved','applied','interview','offer','rejected')),
  notes text, applied_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (user_id, opportunity_id)
);
create index opportunities_listing_idx on public.opportunities(status, category, created_at desc);
create index applications_user_idx on public.applications(user_id, status);
alter table public.profiles enable row level security; alter table public.opportunities enable row level security; alter table public.saved_opportunities enable row level security; alter table public.applications enable row level security;
create policy "Public can view published opportunities" on public.opportunities for select using (status='published');
create policy "Authenticated users can submit opportunities" on public.opportunities for insert to authenticated with check (auth.uid()=created_by);
create policy "Users manage their profiles" on public.profiles for all to authenticated using (id=auth.uid()) with check (id=auth.uid());
create policy "Users manage saved opportunities" on public.saved_opportunities for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy "Users manage their applications" on public.applications for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id,full_name,avatar_url) values(new.id,new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'avatar_url'); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
