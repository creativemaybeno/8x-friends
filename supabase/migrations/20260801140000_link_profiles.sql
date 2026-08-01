-- Named ghosts were dead: shared_people(friend) requires people.linked_profile_id
-- on BOTH sides, but nothing in v0 ever wrote it — redeem_invite_code only
-- inserted friend_links. So shared_people() always returned zero rows and every
-- friend-of-a-friend rendered nameless.
--
-- Product rule: a friend-of-a-friend you are ALSO account-linked to shows their
-- real name; everyone else is a nameless circle derived from a count. The client
-- must never receive a name it is not entitled to, so all name resolution stays
-- inside security-definer RPCs and no policy is widened here.

-- ── Helper: link the one person row that unambiguously names a profile ────────
-- Matches on trimmed, case-insensitive display name. Deliberately conservative:
-- links only when EXACTLY ONE unlinked candidate matches, so we never attach a
-- real identity to the wrong human, and never invent a person row.
create or replace function public.link_person_by_name(
  owner uuid,
  target uuid,
  target_name text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  cnt int;
  pid uuid;
begin
  if target_name is null or btrim(target_name) = '' then
    return;
  end if;

  -- Already linked on this side: nothing to do (keeps redeem idempotent).
  if exists (
    select 1 from public.people p
    where p.owner_id = owner and p.linked_profile_id = target
  ) then
    return;
  end if;

  select count(*) into cnt
  from public.people p
  where p.owner_id = owner
    and not p.is_me
    and p.linked_profile_id is null
    and p.name is not null
    and lower(btrim(p.name)) = lower(btrim(target_name));

  if cnt = 1 then
    select p.id into pid
    from public.people p
    where p.owner_id = owner
      and not p.is_me
      and p.linked_profile_id is null
      and p.name is not null
      and lower(btrim(p.name)) = lower(btrim(target_name))
    limit 1;

    update public.people set linked_profile_id = target where id = pid;
  end if;
end;
$$;

revoke all on function public.link_person_by_name(uuid, uuid, text) from public;

-- ── redeem_invite_code: also account-link the matching person, both ways ─────
create or replace function public.redeem_invite_code(code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  target uuid;
  my_name text;
  target_name text;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  select p.id, p.display_name into target, target_name
  from public.profiles p
  where lower(btrim(p.invite_code)) = lower(btrim(code))
  limit 1;

  if target is null then
    raise exception 'unknown invite code';
  end if;
  if target = me then
    raise exception 'cannot link to yourself';
  end if;

  insert into public.friend_links (a_profile_id, b_profile_id)
  values (me, target), (target, me)
  on conflict do nothing;

  select p.display_name into my_name from public.profiles p where p.id = me;

  -- My graph gains the link to them; their graph gains the link to me.
  perform public.link_person_by_name(me, target, target_name);
  perform public.link_person_by_name(target, me, my_name);

  return target;
end;
$$;

-- ── friend_graph_summary: define people_count and reach precisely ────────────
-- people_count = person rows in that friend's graph excluding their own is_me
--   node (a friend's node for themselves is not a connection) and excluding the
--   node that is account-linked to ME (I am not part of my own reach).
-- reach = the sum of people_count over all my friends. It is deliberately a SUM,
--   not a distinct-human count: two friends may both know the same person, but
--   without a linked_profile_id on both rows there is no identity to dedupe on,
--   so each friend contributes their own graph size. Identical on every row.
create or replace function public.friend_graph_summary()
returns table (profile_id uuid, display_name text, people_count int, reach int)
language sql
security definer
set search_path = ''
as $$
  with friends as (
    select f.b_profile_id as id from public.friend_links f
    where f.a_profile_id = (select auth.uid())
  ),
  counted as (
    select fr.id,
           (select count(*)::int from public.people pe
            where pe.owner_id = fr.id
              and not pe.is_me
              and (pe.linked_profile_id is distinct from (select auth.uid()))
           ) as n
    from friends fr
  )
  select pr.id, pr.display_name, c.n, (select coalesce(sum(n), 0)::int from counted)
  from counted c
  join public.profiles pr on pr.id = c.id;
$$;

-- ── accept_invitation: idempotent ────────────────────────────────────────────
-- The v0 version tested `found` after an UPDATE that matched even when the row
-- was already 'accepted', so a double-tap (or a realtime retry) wrote a second
-- meet-up event into both graphs. Guard on the state transition instead.
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
  if me is null then
    raise exception 'not authenticated';
  end if;

  update public.invitation_recipients r
  set response = 'accepted'
  where r.invitation_id = inv
    and r.recipient_profile_id = me
    and r.response is distinct from 'accepted';

  if not found then
    if not exists (
      select 1 from public.invitation_recipients r
      where r.invitation_id = inv and r.recipient_profile_id = me
    ) then
      raise exception 'not a recipient of this invitation';
    end if;
    return; -- already accepted: no-op, no duplicate events
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
grant execute on function public.accept_invitation(uuid) to authenticated;

-- No policies are added or changed here, so the invitations /
-- invitation_recipients 42P17 cycle broken by is_invitation_sender /
-- is_invitation_recipient stays broken. link_person_by_name is a plain
-- security-definer function called only from redeem_invite_code and is not
-- referenced by any policy, so it cannot introduce a new cycle.
