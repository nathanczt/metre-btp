-- Synchronisation en ligne de Métré BTP (Supabase, offre gratuite)
-- À coller une seule fois dans Supabase : SQL Editor → New query → Run.
-- Chaque utilisateur ne voit que ses propres données (Row Level Security).

-- Projets et travaux : une ligne par compte
create table if not exists public.metre_state (
  user_id uuid primary key default auth.uid() references auth.users on delete cascade,
  data jsonb not null,
  stamp bigint not null,
  updated_at timestamptz not null default now()
);

-- Plans : une ligne par plan (le fichier lui-même est dans le stockage « plans »)
create table if not exists public.metre_plans (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  id text not null,
  meta jsonb,
  stamp bigint not null,
  deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

-- Date de dernière modification posée par le serveur (sert à ne recevoir que les nouveautés)
create or replace function public.metre_touch() returns trigger language plpgsql as $$
begin new.updated_at = clock_timestamp(); return new; end $$;
drop trigger if exists metre_state_touch on public.metre_state;
create trigger metre_state_touch before insert or update on public.metre_state for each row execute function public.metre_touch();
drop trigger if exists metre_plans_touch on public.metre_plans;
create trigger metre_plans_touch before insert or update on public.metre_plans for each row execute function public.metre_touch();

alter table public.metre_state enable row level security;
alter table public.metre_plans enable row level security;
drop policy if exists "mes donnees" on public.metre_state;
create policy "mes donnees" on public.metre_state for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "mes plans" on public.metre_plans;
create policy "mes plans" on public.metre_plans for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Fichiers des plans : dossier privé par utilisateur (plans/<id utilisateur>/<id du plan>)
insert into storage.buckets (id, name, public) values ('plans', 'plans', false)
  on conflict (id) do nothing;
drop policy if exists "mes fichiers de plans" on storage.objects;
create policy "mes fichiers de plans" on storage.objects for all to authenticated
  using (bucket_id = 'plans' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'plans' and (storage.foldername(name))[1] = auth.uid()::text);
