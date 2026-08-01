/// The focused person: yourself, a direct relationship, or one seen through a
/// friend.
library;

import 'package:flutter/material.dart';

import '../../demo/cast.dart';
import '../../model/decay.dart';
import '../../model/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'sheet_scaffold.dart';

/// One-off geometry: the portrait at the head of the sheet.
const double _avatarSize = 52.0;

/// The gap between a name and the mono line underneath it.
const double _nameGap = 5.0;

class FocusSheet extends StatelessWidget {
  const FocusSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final person = state.personById(state.focusedPersonId ?? '');
    if (person == null) return const SizedBox.shrink();

    if (state.isMe(person.id)) return _SelfFocus(state: state, person: person);

    return state.isDirectlyConnected(person.id)
        ? _DirectFocus(state: state, person: person)
        : _IndirectFocus(state: state, person: person);
  }
}

// ---------------------------------------------------------------------------
// A. Direct connection — the relationship you already have.
// ---------------------------------------------------------------------------

class _DirectFocus extends StatelessWidget {
  const _DirectFocus({required this.state, required this.person});

  final AppState state;
  final Person person;

  /// The edge between me and [person], when one exists.
  Relationship? get _edge {
    final key = Relationship.keyFor(state.meId, person.id);
    for (final r in state.relationships) {
      if (r.key == key) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final model = state.decay;
    final edge = _edge;

    // What matters here is the shared history, not the person's whole life:
    // read the link when we have one, the person only as a fallback.
    final days = edge == null
        ? model.daysOf(person.id)
        : model.linkDaysOf(edge);
    final d = edge == null ? model.decayOf(person.id) : model.linkDecayOf(edge);

    final line = d > kRingAmberAbove
        ? 'It has been ${durationLabel(days)} since you were in the same '
              'room. This one is fading.'
        : d > kLinkFragmentsAbove
        ? 'You and ${person.name} are drifting a little — '
              '${durationLabel(days)} since the last time.'
        : 'You two are in good rhythm right now.';

    final inPlan = state.planIds.contains(person.id);

    return SheetScaffold(
      label: Contexts.label(person.context),
      title: person.name,
      subtitle: line,
      onClose: state.goHome,
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(
              label: 'PLAN SOMETHING',
              onTap: () => state.setMode(AppMode.planTime),
            ),
          ),
          const SizedBox(width: Tokens.gapS),
          Expanded(
            child: SheetGhostButton(
              label: 'LOG A MEETUP',
              onTap: () => state.setMode(AppMode.log),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(person: person, size: _avatarSize),
              const SizedBox(width: Tokens.gapM),
              Expanded(
                child: Text(
                  person.name,
                  style: Tokens.personNameLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.gapL),
          Row(
            children: [
              Expanded(
                child: SheetStat(
                  caption: 'LAST TOGETHER',
                  value: agoLabel(days),
                ),
              ),
              const SizedBox(width: Tokens.gapS),
              Expanded(
                child: SheetStat(
                  caption: 'HEALTH',
                  value: Tokens.healthLabel(d),
                  accent: Tokens.healthColor(d),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.gapM),
          HealthBar(decay: d),
          if (state.view == GraphView.distance) ...[
            const SizedBox(height: Tokens.gapM),
            Text(
              '${coarseDistanceLabel(person.distanceKm)} · '
              '${(person.city ?? 'SOMEWHERE ELSE').toUpperCase()}',
              style: Tokens.monoLabel,
            ),
          ],
          if (inPlan) ...[
            const SizedBox(height: Tokens.gapL),
            Text(
              'IN YOUR UPCOMING PLAN',
              style: Tokens.monoLabelBright.copyWith(color: Tokens.violet),
            ),
            const SizedBox(height: Tokens.gapS),
            SheetRow(
              title: 'Open the plan',
              meta: 'WHO IS IN · WHEN · WHERE',
              dot: Tokens.violet,
              onTap: () => state.setMode(AppMode.planDetail),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// B. Indirect connection — someone you can see, and nothing more.
// ---------------------------------------------------------------------------

class _IndirectFocus extends StatelessWidget {
  const _IndirectFocus({required this.state, required this.person});

  final AppState state;
  final Person person;

  @override
  Widget build(BuildContext context) {
    final mutual = state.mutualFor(person.id);
    final pending = state.isConnectionPending(person.id);

    final line = mutual == null
        ? 'You can see ${person.name} through a friend you have in common.'
        : 'You can see ${person.name} because you both know ${mutual.name}.';

    final through = mutual == null
        ? 'CONNECTED THROUGH A MUTUAL FRIEND'
        : 'CONNECTED THROUGH ${mutual.name.toUpperCase()}';

    return SheetScaffold(
      label: 'INDIRECT CONNECTION',
      title: person.name,
      subtitle: line,
      onClose: state.goHome,
      footer: SheetButton(
        label: pending ? 'REQUEST SENT' : 'SEND A CONNECTION REQUEST',
        onTap: pending ? null : () => state.setMode(AppMode.connect),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(person: person, size: _avatarSize, dimmed: true),
              const SizedBox(width: Tokens.gapM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: Tokens.personNameLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: _nameGap),
                    Text(through, style: Tokens.monoLabelBright),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.gapL),
          Container(
            padding: const EdgeInsets.all(Tokens.gapM),
            decoration: BoxDecoration(
              border: Border.all(
                color: Tokens.borderColor,
                width: Tokens.hairline,
              ),
              borderRadius: BorderRadius.circular(Tokens.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRIVATE UNTIL THEY ACCEPT', style: Tokens.monoLabelDim),
                const SizedBox(height: Tokens.gapS),
                Text(
                  'You will not see their activity, their circle, or where '
                  'they are until they accept. They will not see yours '
                  'either. A request only asks — it never adds anyone to '
                  'anything.',
                  style: Tokens.sheetProse,
                ),
              ],
            ),
          ),
          if (pending) ...[
            const SizedBox(height: Tokens.gapM),
            Text(
              'WAITING FOR ${person.name.toUpperCase()} TO ANSWER',
              style: Tokens.monoLabel,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C. Yourself — the node in the middle. Nothing to plan, nothing to log.
// ---------------------------------------------------------------------------

/// How many slipping connections we are willing to name here.
const int _slippingShown = 3;

class _SelfFocus extends StatelessWidget {
  const _SelfFocus({required this.state, required this.person});

  final AppState state;
  final Person person;

  /// The edge between me and [otherId], when one exists.
  Relationship? _edgeTo(String otherId) {
    final key = Relationship.keyFor(state.meId, otherId);
    for (final r in state.relationships) {
      if (r.key == key) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final model = state.decay;
    final people = state.directPeople;

    // Same reading as _DirectFocus: the shared link when there is one, the
    // person alone only as a fallback.
    final scored = <({Person person, double days, double decay})>[];
    for (final p in people) {
      final edge = _edgeTo(p.id);
      scored.add((
        person: p,
        days: edge == null ? model.daysOf(p.id) : model.linkDaysOf(edge),
        decay: edge == null ? model.decayOf(p.id) : model.linkDecayOf(edge),
      ));
    }
    scored.sort((a, b) => b.decay.compareTo(a.decay));

    final fading = scored.where((e) => e.decay > kRingAmberAbove).length;
    final slipping = scored.take(_slippingShown).toList();

    return SheetScaffold(
      label: 'YOU',
      title: person.name,
      subtitle:
          'Everyone here is someone you have actually met. The brighter the '
          'thread, the more recently.',
      onClose: state.goHome,
      footer: SheetGhostButton(label: 'CLOSE', onTap: state.goHome),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(person: person, size: _avatarSize),
              const SizedBox(width: Tokens.gapM),
              Expanded(
                child: Text(
                  person.name,
                  style: Tokens.personNameLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.gapL),
          Row(
            children: [
              Expanded(
                child: SheetStat(
                  caption: 'PEOPLE IN YOUR GRAPH',
                  value: people.length.toString(),
                ),
              ),
              const SizedBox(width: Tokens.gapS),
              Expanded(
                child: SheetStat(
                  caption: 'FADING',
                  value: fading.toString(),
                  accent: fading > 0 ? Tokens.amber : null,
                ),
              ),
            ],
          ),
          if (slipping.isNotEmpty) ...[
            const SizedBox(height: Tokens.gapL),
            Text('WHO IS SLIPPING', style: Tokens.monoLabel),
            const SizedBox(height: Tokens.gapS),
            for (final e in slipping)
              SheetRow(
                title: e.person.name,
                meta: agoLabel(e.days),
                dot: Tokens.contextColor(e.person.context),
                onTap: () => state.focusPerson(e.person.id),
              ),
          ],
        ],
      ),
    );
  }
}
