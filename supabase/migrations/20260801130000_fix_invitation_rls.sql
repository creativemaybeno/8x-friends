-- invitations_select referenced invitation_recipients, whose own policies
-- referenced invitations — Postgres detects the cycle and every insert or
-- select on either table fails with 42P17 "infinite recursion detected in
-- policy". Break it with security-definer helpers, which run with RLS off.

create or replace function public.is_invitation_recipient(inv uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.invitation_recipients r
    where r.invitation_id = inv
      and r.recipient_profile_id = (select auth.uid())
  );
$$;

create or replace function public.is_invitation_sender(inv uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.invitations i
    where i.id = inv
      and i.sender_profile_id = (select auth.uid())
  );
$$;

revoke all on function public.is_invitation_recipient(uuid) from public;
revoke all on function public.is_invitation_sender(uuid) from public;
grant execute on function public.is_invitation_recipient(uuid) to authenticated;
grant execute on function public.is_invitation_sender(uuid) to authenticated;

drop policy if exists invitations_select on public.invitations;
create policy invitations_select on public.invitations
  for select to authenticated
  using (
    sender_profile_id = (select auth.uid())
    or public.is_invitation_recipient(id)
  );

drop policy if exists invitation_recipients_select on public.invitation_recipients;
create policy invitation_recipients_select on public.invitation_recipients
  for select to authenticated
  using (
    recipient_profile_id = (select auth.uid())
    or public.is_invitation_sender(invitation_id)
  );

drop policy if exists invitation_recipients_insert on public.invitation_recipients;
create policy invitation_recipients_insert on public.invitation_recipients
  for insert to authenticated
  with check (public.is_invitation_sender(invitation_id));
