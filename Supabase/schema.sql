-- Orbit — Supabase schema.
--
-- Paste this whole file into the SQL editor of a Supabase project and run it once.
--
-- Orbit has no friend graph. Nobody is on your dial by default. You create an *orbit*, share a
-- link, and it ends — by expiry, by the host closing it, or by everyone leaving. Everything
-- below exists to make that lifecycle something the database enforces rather than something the
-- app is trusted to respect.
--
-- Two rules are load-bearing, and both are policies, not app code:
--   1. A position is readable only by a fellow participant of the same orbit, only while that
--      orbit is active, and only if the reader has not left.
--   2. Expiry is server-side. A client with a stale clock, or a patched client, cannot extend
--      its own access by a second.

-- ---------------------------------------------------------------- orbits

create table public.orbits (
    id           uuid primary key default gen_random_uuid(),
    host_user    uuid not null references auth.users on delete cascade,
    created_at   timestamptz not null default now(),
    -- Hard ceiling of 24 hours from creation or from any extension. There is no indefinite
    -- orbit: a forgotten one always dies.
    expires_at   timestamptz not null,
    ended_at     timestamptz,
    check (expires_at > created_at)
);

create index on public.orbits (host_user);

-- The join link is a capability, so it is a row of its own: it can be revoked and replaced
-- without touching the orbit, and it expires long before the orbit does.
create table public.join_tokens (
    token       text primary key,
    orbit_id    uuid not null references public.orbits on delete cascade,
    created_at  timestamptz not null default now(),
    expires_at  timestamptz not null,
    revoked     boolean not null default false
);

create index on public.join_tokens (orbit_id) where not revoked;

-- ---------------------------------------------------------------- participants

create table public.participants (
    id           uuid primary key default gen_random_uuid(),
    orbit_id     uuid not null references public.orbits on delete cascade,
    user_id      uuid not null references auth.users on delete cascade,
    -- Free text, not unique. The link is the identity mechanism; this is just what to call
    -- someone on the dial.
    display_name text not null check (length(display_name) between 1 and 24),
    joined_at    timestamptz not null default now(),
    left_at      timestamptz,
    unique (orbit_id, user_id)
);

create index on public.participants (orbit_id) where left_at is null;

-- ---------------------------------------------------------------- positions

-- Latest only. There is no history table, and that is a product commitment: when an orbit ends
-- there is nothing to replay, subpoena, or leak.
create table public.positions (
    participant_id uuid primary key references public.participants on delete cascade,
    latitude       double precision not null,
    longitude      double precision not null,
    accuracy       double precision,
    updated_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------- helpers

-- An orbit is live if it has not been ended and has not run out of time. Every policy below
-- goes through this, so "active" means one thing everywhere.
create or replace function public.orbit_is_active(orbit uuid)
returns boolean language sql stable security definer set search_path = public as $$
    select exists (
        select 1 from public.orbits o
        where o.id = orbit and o.ended_at is null and o.expires_at > now()
    );
$$;

-- Your own live membership of an orbit, if any.
create or replace function public.my_participant(orbit uuid)
returns uuid language sql stable security definer set search_path = public as $$
    select p.id from public.participants p
    where p.orbit_id = orbit and p.user_id = auth.uid() and p.left_at is null
    limit 1;
$$;

-- ---------------------------------------------------------------- policies

alter table public.orbits enable row level security;
alter table public.participants enable row level security;
alter table public.positions enable row level security;
alter table public.join_tokens enable row level security;

-- You can see an orbit you are in. Ended and expired ones stay visible so the app can show an
-- explicit "this orbit is over" state rather than an ambiguous empty dial.
create policy "orbits you are in" on public.orbits
    for select using (
        exists (select 1 from public.participants p
                where p.orbit_id = orbits.id and p.user_id = auth.uid())
    );

-- Everyone in an orbit sees everyone else, including people who have left — a departure has to
-- be announceable, and a name that vanishes is worse than one marked gone.
create policy "participants of your orbits" on public.participants
    for select using (
        exists (select 1 from public.participants me
                where me.orbit_id = participants.orbit_id and me.user_id = auth.uid())
    );

-- Leaving is the only row change a participant makes directly.
create policy "you can leave" on public.participants
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Rule 1. Note all three conditions: same orbit, orbit still active, and the reader still in it.
create policy "positions of live co-participants" on public.positions
    for select using (
        exists (
            select 1
            from public.participants them
            join public.participants me on me.orbit_id = them.orbit_id
            where them.id = positions.participant_id
              and me.user_id = auth.uid()
              and me.left_at is null
              and public.orbit_is_active(them.orbit_id)
        )
    );

-- You write your own position, and only while your orbit is live. Publishing stops being
-- possible the moment the orbit ends, whatever the client believes.
create policy "publish your own position" on public.positions
    for all using (
        exists (select 1 from public.participants p
                where p.id = positions.participant_id
                  and p.user_id = auth.uid()
                  and p.left_at is null
                  and public.orbit_is_active(p.orbit_id))
    ) with check (
        exists (select 1 from public.participants p
                where p.id = positions.participant_id
                  and p.user_id = auth.uid()
                  and p.left_at is null
                  and public.orbit_is_active(p.orbit_id))
    );

-- Only the host ever reads a token back, to show or share the link.
create policy "host reads its own tokens" on public.join_tokens
    for select using (
        exists (select 1 from public.orbits o
                where o.id = join_tokens.orbit_id and o.host_user = auth.uid())
    );

alter publication supabase_realtime add table public.positions;
alter publication supabase_realtime add table public.participants;
alter publication supabase_realtime add table public.orbits;

-- ---------------------------------------------------------------- operations

create or replace function public.create_orbit(hours int, display_name text)
returns table (orbit_id uuid, token text, orbit_expires_at timestamptz, token_expires_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare
    new_orbit uuid;
    new_token text;
    token_expiry timestamptz;
begin
    if hours not in (1, 6, 12, 24) then
        raise exception 'duration must be 1, 6, 12 or 24 hours';
    end if;

    insert into public.orbits (host_user, expires_at)
    values (auth.uid(), now() + make_interval(hours => hours))
    returning id into new_orbit;

    insert into public.participants (orbit_id, user_id, display_name)
    values (new_orbit, auth.uid(), display_name);

    -- The link outlives neither the orbit nor an hour, whichever comes first.
    new_token := encode(gen_random_bytes(9), 'base64');
    new_token := replace(replace(replace(new_token, '+', '-'), '/', '_'), '=', '');
    token_expiry := least(now() + interval '1 hour', (select expires_at from public.orbits where id = new_orbit));

    insert into public.join_tokens (token, orbit_id, expires_at)
    values (new_token, new_orbit, token_expiry);

    return query select new_orbit, new_token, (select expires_at from public.orbits where id = new_orbit), token_expiry;
end;
$$;

-- Joining is the whole membership check in one statement: the token has to be live, the orbit
-- has to be live, and there has to be room. A client cannot talk its way past any of the three.
create or replace function public.join_orbit(join_token text, display_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
    target uuid;
    occupied int;
    existing uuid;
begin
    select t.orbit_id into target
    from public.join_tokens t
    where t.token = join_token and not t.revoked and t.expires_at > now();

    if target is null then
        raise exception 'link_invalid';
    end if;

    if not public.orbit_is_active(target) then
        raise exception 'orbit_over';
    end if;

    -- Rejoining on a still-valid link is allowed, and does not consume a second seat.
    select p.id into existing from public.participants p
    where p.orbit_id = target and p.user_id = auth.uid();

    if existing is not null then
        update public.participants
        set left_at = null, display_name = coalesce(nullif(join_orbit.display_name, ''), participants.display_name)
        where id = existing;
        return target;
    end if;

    select count(*) into occupied from public.participants p
    where p.orbit_id = target and p.left_at is null;

    if occupied >= 6 then
        raise exception 'orbit_full';
    end if;

    insert into public.participants (orbit_id, user_id, display_name)
    values (target, auth.uid(), display_name);

    return target;
end;
$$;

-- Extension is capped against the clock, not against the previous expiry, so repeated calls
-- can never push an orbit past a day of remaining life.
create or replace function public.extend_orbit(orbit uuid, hours int)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare
    updated timestamptz;
begin
    update public.orbits o
    set expires_at = least(o.expires_at + make_interval(hours => hours), now() + interval '24 hours')
    where o.id = orbit and o.host_user = auth.uid() and o.ended_at is null and o.expires_at > now()
    returning o.expires_at into updated;

    if updated is null then raise exception 'not_host_or_over'; end if;
    return updated;
end;
$$;

create or replace function public.regenerate_token(orbit uuid)
returns table (token text, expires_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare
    fresh text;
    expiry timestamptz;
begin
    if not exists (select 1 from public.orbits o
                   where o.id = orbit and o.host_user = auth.uid() and public.orbit_is_active(orbit)) then
        raise exception 'not_host_or_over';
    end if;

    update public.join_tokens set revoked = true where orbit_id = orbit and not revoked;

    fresh := replace(replace(replace(encode(gen_random_bytes(9), 'base64'), '+', '-'), '/', '_'), '=', '');
    expiry := least(now() + interval '1 hour', (select o.expires_at from public.orbits o where o.id = orbit));

    insert into public.join_tokens (token, orbit_id, expires_at) values (fresh, orbit, expiry);
    return query select fresh, expiry;
end;
$$;

-- The host ending it ends it for everyone; positions go with it.
create or replace function public.end_orbit(orbit uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
    update public.orbits set ended_at = now()
    where id = orbit and host_user = auth.uid() and ended_at is null;

    update public.join_tokens set revoked = true where orbit_id = orbit;

    delete from public.positions
    where participant_id in (select id from public.participants where orbit_id = orbit);
end;
$$;

-- Leaving drops your position immediately, and ends the orbit if you were the last one in it.
create or replace function public.leave_orbit(orbit uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
    mine uuid;
    remaining int;
begin
    select public.my_participant(orbit) into mine;
    if mine is null then return; end if;

    update public.participants set left_at = now() where id = mine;
    delete from public.positions where participant_id = mine;

    select count(*) into remaining from public.participants
    where orbit_id = orbit and left_at is null;

    -- The host leaving ends it, and so does the last person out.
    if remaining = 0 or exists (select 1 from public.orbits o
                                where o.id = orbit and o.host_user = auth.uid()) then
        update public.orbits set ended_at = now() where id = orbit and ended_at is null;
        update public.join_tokens set revoked = true where orbit_id = orbit;
        delete from public.positions
        where participant_id in (select id from public.participants where orbit_id = orbit);
    end if;
end;
$$;

grant execute on function public.create_orbit(int, text) to authenticated;
grant execute on function public.join_orbit(text, text) to authenticated;
grant execute on function public.extend_orbit(uuid, int) to authenticated;
grant execute on function public.regenerate_token(uuid) to authenticated;
grant execute on function public.end_orbit(uuid) to authenticated;
grant execute on function public.leave_orbit(uuid) to authenticated;
