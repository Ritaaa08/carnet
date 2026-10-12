-- Carnet Privé : base de synchronisation.
-- À coller une seule fois dans Supabase > SQL Editor > New query, puis "Run".
-- Le site ne peut que lire, écrire ou effacer un carnet dont il connaît le code secret (64 caractères).
-- Le contenu est chiffré dans le navigateur avant l'envoi : Supabase ne voit jamais tes données en clair.

create table if not exists public.carnet_vaults (
  id text primary key check (char_length(id) between 64 and 80),
  doc jsonb not null,
  rev bigint not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.carnet_vaults enable row level security;
revoke all on public.carnet_vaults from anon, authenticated;

create or replace function public.carnet_get(p_id text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select doc from public.carnet_vaults where id = p_id and char_length(p_id) >= 64;
$$;

create or replace function public.carnet_put(p_id text, p_doc jsonb)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev bigint := coalesce((p_doc->>'rev')::bigint, 0);
begin
  if char_length(p_id) < 64 or char_length(p_id) > 80 then
    raise exception 'code invalide';
  end if;
  if pg_column_size(p_doc) > 2000000 then
    raise exception 'carnet trop volumineux';
  end if;
  insert into public.carnet_vaults (id, doc, rev, updated_at)
  values (p_id, p_doc, v_rev, now())
  on conflict (id) do update
    set doc = excluded.doc, rev = excluded.rev, updated_at = now()
    where public.carnet_vaults.rev <= excluded.rev;
  return (select rev from public.carnet_vaults where id = p_id);
end;
$$;

create or replace function public.carnet_delete(p_id text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.carnet_vaults where id = p_id and char_length(p_id) >= 64;
$$;

revoke all on function public.carnet_get(text) from public;
revoke all on function public.carnet_put(text, jsonb) from public;
revoke all on function public.carnet_delete(text) from public;
grant execute on function public.carnet_get(text) to anon, authenticated;
grant execute on function public.carnet_put(text, jsonb) to anon, authenticated;
grant execute on function public.carnet_delete(text) to anon, authenticated;
