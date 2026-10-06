-- À exécuter dans Supabase : Dashboard > SQL Editor > New query > colle tout ça > Run
-- (Déjà exécuté une fois avec succès — ce fichier est gardé pour référence / réinstallation future)

create extension if not exists vector;

create table if not exists items (
  id uuid default gen_random_uuid() primary key,
  name text,
  shop text not null,
  address text,
  size text,
  price text not null,
  category text,
  image_url text,
  embedding vector(512),
  created_at timestamptz default now()
);

create or replace function match_items(query_embedding vector(512), match_count int)
returns table (
  id uuid,
  name text,
  shop text,
  address text,
  size text,
  price text,
  category text,
  image_url text,
  similarity float
)
language sql stable
as $$
  select id, name, shop, address, size, price, category, image_url,
         1 - (embedding <=> query_embedding) as similarity
  from items
  order by embedding <=> query_embedding
  limit match_count;
$$;

insert into storage.buckets (id, name, public)
values ('items', 'items', true)
on conflict (id) do nothing;

drop policy if exists "Public read access" on storage.objects;
create policy "Public read access"
on storage.objects for select
using (bucket_id = 'items');

-- Migration ajoutée pour le profil Particulier/Friperie et l'expédition
-- (à exécuter séparément si la table "items" existe déjà)
alter table items add column if not exists seller_type text default 'particulier';
alter table items add column if not exists ships_packages boolean default false;

-- Mise à jour de la fonction de recherche pour inclure les nouveaux champs
create or replace function match_items(query_embedding vector(512), match_count int)
returns table (
  id uuid, name text, shop text, address text, size text, price text,
  category text, image_url text, seller_type text, ships_packages boolean, similarity float
)
language sql stable
as $$
  select id, name, shop, address, size, price, category, image_url, seller_type, ships_packages,
         1 - (embedding <=> query_embedding) as similarity
  from items
  order by embedding <=> query_embedding
  limit match_count;
$$;
