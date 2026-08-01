/// The focused person: yourself, a direct tie, or someone seen through a
/// mutual. Screens S02 and S19.
library;

import 'package:flutter/material.dart';

import '../../model/decay.dart';
import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

/// Above this a tie reads as in trouble: clay mark, clay signal.
const double _trouble = 0.55;

/// How many slipping ties the self sheet is willing to name.
const int _slippingShown = 3;

class FocusSheet extends StatelessWidget {
  const FocusSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final person = state.personById(state.focusedPersonId ?? '');
    if (person == null) return _NoPerson(state: state);
    if (state.isMe(person.id)) return _SelfFocus(state: state, person: person);
    return state.isDirectlyConnected(person.id)
        ? _DirectFocus(state: state, person: person)
        : _IndirectFocus(state: state, person: person);
  }
}

/// Everyone in my circle who also knows [otherId].
List<String> _mutualNames(AppState state, String otherId) {
  final theirs = <String>{};
  for (final r in state.relationships) {
    final o = r.other(otherId);
    if (o != null) theirs.add(o);
  }
  return [
    for (final p in state.directPeople)
      if (p.id != otherId && theirs.contains(p.id)) p.name,
  ];
}

// ---------------------------------------------------------------------------
// A. Direct connection — S02.
// ---------------------------------------------------------------------------

class _DirectFocus extends StatelessWidget {
  const _DirectFocus({required this.state, required this.person});

  final AppState state;
  final Person person;

  @override
  Widget build(BuildContext context) {
    final edge = state.edgeWith(person.id);
    final decay = state.decayWith(person.id);
    final days = state.daysWith(person.id);
    final ailing = decay > _trouble;
    final health = Tokens.healthColor(decay);
    final rhythm = edge?.rhythmLabel ?? 'now and then';
    final via = edge?.via;
    final where = Contexts.label(person.context);
    final mutuals = _mutualNames(state, person.id);
    final inPlan = state.planIds.contains(person.id);

    return SheetScaffold(
      label: 'person',
      labelColor: ailing ? Tokens.clay : Tokens.ink2,
      labelMark: ailing ? Tokens.clay : Tokens.ink,
      labelRight: Tokens.healthLabel(decay),
      subject: SheetSubject(
        initial: person.initial,
        name: person.name,
        meta: via == null ? where : '$where · $via',
        stat: '${((1 - decay) * 100).round()}%',
        statLabel: 'signal',
        statColor: health,
        badgeDecay: decay,
      ),
      signal: 1 - decay,
      signalColor: health,
      read: _readFor(rhythm, days, ailing),
      rows: [
        SheetRow(title: 'Last together', meta: agoLabel(days)),
        SheetRow(title: 'Your usual rhythm', meta: rhythm),
        SheetRow(
          title: 'Also knows',
          meta: mutuals.isEmpty ? '—' : mutuals.join(', '),
        ),
        if (inPlan)
          SheetRow(
            title: 'In your upcoming plan',
            meta: 'open',
            metaColor: Tokens.limeDeep,
            onTap: () => state.setMode(AppMode.planDetail),
          ),
      ],
      actions: [
        SheetAction(
          label: 'Plan something',
          onTap: () => state.setMode(AppMode.planTime),
        ),
        SheetAction(
          label: 'Log a meetup',
          kind: SheetActionKind.ghost,
          onTap: () => state.setMode(AppMode.log),
        ),
      ],
    );
  }

  /// The warm sentence at the top: the same numbers the graph is drawing,
  /// said the way a person would say them.
  static String _readFor(String rhythm, double days, bool ailing) {
    if (ailing) {
      return 'You two used to see each other $rhythm. It has been '
          '${durationLabel(days)}. Nothing happened — you both just got '
          'busy.';
    }
    if (days < 2) {
      return 'You two see each other $rhythm, and you were together '
          '${agoLabel(days)}. You are in a good rhythm.';
    }
    return 'You two see each other $rhythm. It has been '
        '${durationLabel(days)}, which is about right. You are in a good '
        'rhythm.';
  }
}

// ---------------------------------------------------------------------------
// B. Indirect connection — S19. A name, an initial, a mutual. Nothing else.
// ---------------------------------------------------------------------------

class _IndirectFocus extends StatelessWidget {
  const _IndirectFocus({required this.state, required this.person});

  final AppState state;
  final Person person;

  @override
  Widget build(BuildContext context) {
    final mutual = state.mutualFor(person.id);
    final pending = state.isConnectionPending(person.id);
    final place = state.plan?.place;

    return SheetScaffold(
      label: 'indirect connection',
      labelColor: Tokens.ink2,
      labelMark: Tokens.mut,
      labelRight: pending ? 'request out' : 'not connected',
      subject: SheetSubject(
        initial: person.initial,
        name: person.name,
        meta: mutual == null
            ? 'through a mutual'
            : 'through ${mutual.name.toLowerCase()}',
        hollow: true,
      ),
      read: place == null
          ? 'You have someone in common. They are not a connection yet — '
                'that is their call, not the app’s.'
          : 'You met at $place. They are not a connection yet — that is '
                'their call, not the app’s.',
      rows: [
        SheetRow(title: 'Mutual', meta: mutual?.name ?? '—'),
        const SheetRow(
          title: 'Relationship health',
          meta: 'not visible',
          dimmed: true,
        ),
        const SheetRow(title: 'Location', meta: 'not visible', dimmed: true),
        const SheetRow(
          title: 'Their other people',
          meta: 'not visible',
          dimmed: true,
        ),
      ],
      note:
          'This is everything you can see about someone you are not '
          'connected to: a name, an initial, and who you have in common.',
      actions: [
        SheetAction(
          label: pending ? 'Request sent' : 'Request connection',
          onTap: pending ? null : () => state.setMode(AppMode.connect),
        ),
        SheetAction(
          label: 'Close',
          kind: SheetActionKind.ghost,
          onTap: state.goHome,
        ),
      ],
      foot: pending ? 'nothing of yours is shared until they accept' : null,
    );
  }
}

// ---------------------------------------------------------------------------
// C. Yourself — the node in the middle.
// ---------------------------------------------------------------------------

class _SelfFocus extends StatelessWidget {
  const _SelfFocus({required this.state, required this.person});

  final AppState state;
  final Person person;

  @override
  Widget build(BuildContext context) {
    final slipping = [...state.directPeople]
      ..sort((a, b) => state.decayWith(b.id).compareTo(state.decayWith(a.id)));

    return SheetScaffold(
      label: 'you',
      labelColor: Tokens.ink2,
      labelMark: Tokens.lime,
      labelRight: 'your own node',
      subject: SheetSubject(
        initial: person.initial,
        name: person.name,
        meta:
            '${state.circleCount} in your circle · '
            '${state.driftingCount} drifting',
      ),
      read:
          'Everyone here is someone you have actually met. The brighter the '
          'thread, the more recently.',
      rows: [
        for (final p in slipping.take(_slippingShown))
          SheetRow(
            title: p.name,
            initial: p.initial,
            meta: agoLabel(state.daysWith(p.id)),
            metaColor: state.decayWith(p.id) > _trouble ? Tokens.clay : null,
            onTap: () => state.focusPerson(p.id),
          ),
      ],
      actions: [
        SheetAction(
          label: 'Log a meetup',
          onTap: () => state.setMode(AppMode.log),
        ),
        SheetAction(
          label: 'Close',
          kind: SheetActionKind.ghost,
          onTap: state.goHome,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// D. Nobody is focused — the graph moved on while the sheet was open.
// ---------------------------------------------------------------------------

class _NoPerson extends StatelessWidget {
  const _NoPerson({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => SheetScaffold(
    label: 'person',
    labelColor: Tokens.ink2,
    labelMark: Tokens.mut,
    title: 'Nobody selected',
    read: 'That node is no longer on the graph.',
    actions: [
      SheetAction(
        label: 'Close',
        kind: SheetActionKind.ghost,
        onTap: state.goHome,
      ),
    ],
  );
}
