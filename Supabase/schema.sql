-- Orbit — Supabase schema.
--
-- Paste this whole file into the SQL editor of a new Supabase project and run it once.
--
-- The rule the whole app rests on is enforced here, not in Swift: a location row is readable
-- only by someone with an accepted, two-way invite. No client bug can leak a position,
-- because the database will not return it.

create extension if not exists citext;

-- ---------------------------------------------------------------- profiles

create table public.profiles (
    id          uuid primary key references auth.users on delete cascade,
    first_name  text not null,
    last_name   text not null,
    username    citext not null unique
                check (length(username) between 3 and 20 and username ~ '^[a-z0-9_]+$'),
    -- E.164, e.g. +14155550134. Never exposed by a policy; only the matching function reads it.
    phone       text,
    created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- You can always read and write your own row.
create policy "own profile" on public.profiles
    for all using (auth.uid() = id) with check (auth.uid() = id);

-- You can read the profile of anyone you have an invite with, in either direction and at any
-- stage — otherwise a pending request would have no name to show.
create policy "profiles of people you have an invite with" on public.profiles
    for select using (
        exists (
            select 1 from public.invites i
            where (i.from_user = auth.uid() and i.to_user = profiles.id)
               or (i.to_user = auth.uid() and i.from_user = profiles.id)
        )
    );

-- ---------------------------------------------------------------- invites

create type public.invite_status as enum ('pending', 'accepted', 'declined');

create table public.invites (
    id          uuid primary key default gen_random_uuid(),
    from_user   uuid not null references auth.users on delete cascade,
    to_user     uuid not null references auth.users on delete cascade,
    status      public.invite_status not null default 'pending',
    created_at  timestamptz not null default now(),
    responded_at timestamptz,
    check (from_user <> to_user),
    unique (from_user, to_user)
);

create index on public.invites (to_user, status);
create index on public.invites (from_user, status);

alter table public.invites enable row level security;

create policy "invites you are part of" on public.invites
    for select using (auth.uid() in (from_user, to_user));

create policy "you can invite" on public.invites
    for insert with check (auth.uid() = from_user);

-- Only the recipient answers, and only a pending invite.
create policy "you answer your own invites" on public.invites
    for update using (auth.uid() = to_user and status = 'pending')
    with check (auth.uid() = to_user);

-- Either side can withdraw or stop sharing.
create policy "either side can end it" on public.invites
    for delete using (auth.uid() in (from_user, to_user));

-- ---------------------------------------------------------------- locations

create table public.locations (
    user_id     uuid primary key references auth.users on delete cascade,
    latitude    double precision not null,
    longitude   double precision not null,
    -- Degrees clockwise from north, and metres per second — how they are moving.
    course      double precision,
    speed       double precision,
    updated_at  timestamptz not null default now()
);

alter table public.locations enable row level security;

create policy "write only your own position" on public.locations
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- The one that matters. A position is visible only where sharing is mutual and accepted.
create policy "read positions of people sharing with you" on public.locations
    for select using (
        exists (
            select 1 from public.invites i
            where i.status = 'accepted'
              and ((i.from_user = auth.uid() and i.to_user = locations.user_id)
                or (i.to_user = auth.uid() and i.from_user = locations.user_id))
        )
    );

-- Realtime respects the policies above, so a client subscribed to every change still only
-- receives the rows it is allowed to read.
alter publication supabase_realtime add table public.locations;
alter publication supabase_realtime add table public.invites;

-- ---------------------------------------------------------------- functions

-- Username availability, callable before sign-up. Security definer so it can see the unique
-- index without any policy exposing the profiles table to strangers.
create or replace function public.username_available(name citext)
returns boolean language sql security definer set search_path = public as $$
    select not exists (select 1 from public.profiles where username = name);
$$;

grant execute on function public.username_available(citext) to anon, authenticated;

-- Contact matching. The client sends normalised E.164 numbers; only the ones with accounts
-- come back, and nothing is stored. Numbers that do not match are discarded.
--
-- Note the trade-off honestly: this reveals to the server which numbers are in your address
-- book for the duration of the call. Hashing them client-side does not fix it — the phone
-- number space is small enough to brute-force — so the real answer is private set
-- intersection, which is out of scope here. Do not log the input.
create or replace function public.match_contacts(phones text[])
returns table (id uuid, first_name text, last_name text, username citext, phone text)
language sql security definer set search_path = public as $$
    select p.id, p.first_name, p.last_name, p.username, p.phone
    from public.profiles p
    where p.phone = any(phones) and p.id <> auth.uid();
$$;

grant execute on function public.match_contacts(text[]) to authenticated;

-- Search by name or username, so people can be found without an address book.
create or replace function public.search_people(term text)
returns table (id uuid, first_name text, last_name text, username citext)
language sql security definer set search_path = public as $$
    select p.id, p.first_name, p.last_name, p.username
    from public.profiles p
    where p.id <> auth.uid()
      and (p.username ilike term || '%'
        or p.first_name ilike term || '%'
        or p.last_name ilike term || '%')
    limit 20;
$$;

grant execute on function public.search_people(text) to authenticated;

-- Accepting is the only path to sharing, and it is one statement so it cannot half-happen.
create or replace function public.respond_to_invite(invite uuid, accept boolean)
returns void language sql security invoker set search_path = public as $$
    update public.invites
    set status = case when accept then 'accepted'::invite_status else 'declined'::invite_status end,
        responded_at = now()
    where id = invite and to_user = auth.uid() and status = 'pending';
$$;

grant execute on function public.respond_to_invite(uuid, boolean) to authenticated;
