-- 8x Friends v0 schema: tables, RLS, RPCs, realtime.
-- Never store a decay value; decay is computed client-side from event dates.

-- ── Tables ───────────────────────────────────────────────────────────────────

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  invite_code text unique,
  is_subscriber boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.people (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text,
  context text,
  closeness int not null default 1 check (closeness between 1 and 3),
  birthday_day int,
  birthday_month int,
  met_via text,
  linked_profile_id uuid references public.profiles(id),
  is_me boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.relationships (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  a_person_id uuid not null references public.people(id) on delete cascade,
  b_person_id uuid not null references public.people(id) on delete cascade,
  unique (owner_id, a_person_id, b_person_id),
  check (a_person_id < b_person_id)
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  occurred_on date not null,
  place text,
  created_at timestamptz not null default now()
);

create table public.event_people (
  event_id uuid not null references public.events(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete cascade,
  primary key (event_id, person_id)
);

-- Both directions are written by redeem_invite_code.
create table public.friend_links (
  a_profile_id uuid not null references public.profiles(id) on delete cascade,
  b_profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (a_profile_id, b_profile_id)
);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  sender_profile_id uuid not null references public.profiles(id) on delete cascade,
  place text,
  proposed_for date,
  state text not null default 'pending',
  created_at timestamptz not null default now()
);

create table public.invitation_recipients (
  invitation_id uuid not null references public.invitations(id) on delete cascade,
  recipient_profile_id uuid not null references public.profiles(id) on delete cascade,
  response text not null default 'pending',
  primary key (invitation_id, recipient_profile_id)
);

-- ── Indexes ──────────────────────────────────────────────────────────────────

create index people_owner_id_idx on public.people (owner_id);
create index people_linked_profile_id_idx on public.people (linked_profile_id);
create index relationships_owner_id_idx on public.relationships (owner_id);
create index events_owner_id_idx on public.events (owner_id);
create index event_people_person_id_idx on public.event_people (person_id);
create index friend_links_b_profile_id_idx on public.friend_links (b_profile_id);
create index invitations_sender_profile_id_idx on public.invitations (sender_profile_id);
create index invitation_recipients_recipient_idx on public.invitation_recipients (recipient_profile_id);

-- ── RLS ──────────────────────────────────────────────────────────────────────

alter table public.profiles enable row level security;
alter table public.people enable row level security;
alter table public.relationships enable row level security;
alter table public.events enable row level security;
alter table public.event_people enable row level security;
alter table public.friend_links enable row level security;
alter table public.invitations enable row level security;
alter table public.invitation_recipients enable row level security;

-- profiles: own row only. Other profiles are never directly selectable.
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (id = (select auth.uid()));
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- people / relationships / events: owner only.
create policy people_all_own on public.people
  for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy relationships_all_own on public.relationships
  for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy events_all_own on public.events
  for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

-- event_people: via parent event ownership.
create policy event_people_all_own on public.event_people
  for all to authenticated
  using (exists (select 1 from public.events e where e.id = event_id and e.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.events e where e.id = event_id and e.owner_id = (select auth.uid())));

-- friend_links: readable by either side. Inserts only via security-definer RPC.
create policy friend_links_select on public.friend_links
  for select to authenticated
  using ((select auth.uid()) in (a_profile_id, b_profile_id));

-- invitations: sender full access; recipients may read.
create policy invitations_select on public.invitations
  for select to authenticated
  using (
    sender_profile_id = (select auth.uid())
    or exists (
      select 1 from public.invitation_recipients r
      where r.invitation_id = id and r.recipient_profile_id = (select auth.uid())
    )
  );
-- The paywall lives in the DB too.
create policy invitations_insert on public.invitations
  for insert to authenticated
  with check (
    sender_profile_id = (select auth.uid())
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.is_subscriber)
  );
create policy invitations_update on public.invitations
  for update to authenticated
  using (sender_profile_id = (select auth.uid()))
  with check (sender_profile_id = (select auth.uid()));
create policy invitations_delete on public.invitations
  for delete to authenticated
  using (sender_profile_id = (select auth.uid()));

create policy invitation_recipients_select on public.invitation_recipients
  for select to authenticated
  using (
    recipient_profile_id = (select auth.uid())
    or exists (
      select 1 from public.invitations i
      where i.id = invitation_id and i.sender_profile_id = (select auth.uid())
    )
  );
create policy invitation_recipients_insert on public.invitation_recipients
  for insert to authenticated
  with check (
    exists (
      select 1 from public.invitations i
      where i.id = invitation_id and i.sender_profile_id = (select auth.uid())
    )
  );
create policy invitation_recipients_update on public.invitation_recipients
  for update to authenticated
  using (recipient_profile_id = (select auth.uid()))
  with check (recipient_profile_id = (select auth.uid()));

-- ── RPCs ─────────────────────────────────────────────────────────────────────

create or replace function public.redeem_invite_code(code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  target uuid;
begin
  select p.id into target from public.profiles p
  where lower(p.invite_code) = lower(trim(code));

  if target is null then
    raise exception 'unknown invite code';
  end if;
  if target = me then
    raise exception 'cannot link to yourself';
  end if;

  insert into public.friend_links (a_profile_id, b_profile_id)
  values (me, target), (target, me)
  on conflict do nothing;

  return target;
end;
$$;

-- reach = number of distinct people (excluding is_me) across ALL of my
-- friends' graphs. It is the same value on every row: the size of my
-- second-degree reach.
create or replace function public.friend_graph_summary()
returns table (profile_id uuid, display_name text, people_count int, reach int)
language sql
security definer
set search_path = ''
as $$
  with friends as (
    select f.b_profile_id as id from public.friend_links f
    where f.a_profile_id = auth.uid()
  ),
  total as (
    select count(*)::int as reach
    from public.people pe
    where pe.owner_id in (select id from friends) and not pe.is_me
  )
  select
    pr.id,
    pr.display_name,
    (select count(*)::int from public.people pe
      where pe.owner_id = pr.id and not pe.is_me),
    (select reach from total)
  from public.profiles pr
  where pr.id in (select id from friends);
$$;

create or replace function public.shared_people(friend uuid)
returns table (profile_id uuid, display_name text)
language sql
security definer
set search_path = ''
as $$
  select pr.id, pr.display_name
  from public.profiles pr
  where exists (
      select 1 from public.people p
      where p.owner_id = auth.uid() and p.linked_profile_id = pr.id
    )
    and exists (
      select 1 from public.people p
      where p.owner_id = friend and p.linked_profile_id = pr.id
    )
    and exists (
      select 1 from public.friend_links f
      where f.a_profile_id = auth.uid() and f.b_profile_id = pr.id
    );
$$;

-- The only legitimate cross-owner write: accepting an invitation records the
-- meet-up in both the sender's and the accepting recipient's graph.
create or replace function public.accept_invitation(inv uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  sender uuid;
  place text;
  ev uuid;
  person uuid;
begin
  update public.invitation_recipients r
  set response = 'accepted'
  where r.invitation_id = inv and r.recipient_profile_id = me;

  if not found then
    raise exception 'not a recipient of this invitation';
  end if;

  select i.sender_profile_id, i.place into sender, place
  from public.invitations i where i.id = inv;

  -- Sender's graph: event with the accepting recipient.
  insert into public.events (owner_id, occurred_on, place)
  values (sender, current_date, place) returning id into ev;
  select p.id into person from public.people p
  where p.owner_id = sender and p.linked_profile_id = me limit 1;
  if person is not null then
    insert into public.event_people (event_id, person_id) values (ev, person)
    on conflict do nothing;
  end if;

  -- Recipient's graph: event with the sender.
  insert into public.events (owner_id, occurred_on, place)
  values (me, current_date, place) returning id into ev;
  person := null;
  select p.id into person from public.people p
  where p.owner_id = me and p.linked_profile_id = sender limit 1;
  if person is not null then
    insert into public.event_people (event_id, person_id) values (ev, person)
    on conflict do nothing;
  end if;
end;
$$;

grant execute on function public.redeem_invite_code(text) to authenticated;
grant execute on function public.friend_graph_summary() to authenticated;
grant execute on function public.shared_people(uuid) to authenticated;
grant execute on function public.accept_invitation(uuid) to authenticated;

-- ── Realtime ─────────────────────────────────────────────────────────────────

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'invitations'
  ) then
    alter publication supabase_realtime add table public.invitations;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'invitation_recipients'
  ) then
    alter publication supabase_realtime add table public.invitation_recipients;
  end if;
end;
$$;
