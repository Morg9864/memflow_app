import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../domain/models/study_planning.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

String planningLocation({String? collectionId, String? deckId}) => Uri(
  path: '/planning',
  queryParameters: collectionId == null && deckId == null
      ? null
      : {'collectionId': ?collectionId, 'deckId': ?deckId},
).toString();

String plannedStudyLocation({
  String? collectionId,
  String? deckId,
  String? planId,
}) => Uri(
  path: '/study',
  queryParameters: {
    'planned': '1',
    'collectionId': ?collectionId,
    'deckId': ?deckId,
    'planId': ?planId,
  },
).toString();

String formatPlanningDate(DateTime date) =>
    DateFormat('dd/MM/yyyy').format(date);

String formatRelativePlanningDate(DateTime date, {DateTime? today}) {
  final reference = studyDay(today ?? DateTime.now());
  final day = studyDay(date);
  final difference = day.difference(reference).inDays;
  return switch (difference) {
    0 => 'aujourd’hui',
    1 => 'demain',
    > 1 => 'dans $difference jours',
    -1 => 'hier',
    _ => 'il y a ${difference.abs()} jours',
  };
}

String formatRelativeSrsDate(DateTime date, {DateTime? today}) {
  final reference = studyDay(today ?? DateTime.now());
  final difference = studyDay(date).difference(reference).inDays;
  if (difference < 0) {
    return difference == -1
        ? 'en retard depuis hier'
        : 'en retard depuis ${difference.abs()} jours';
  }
  return formatRelativePlanningDate(date, today: reference);
}

const _shortDayNames = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
const _oneDay = Duration(days: 1);

class PlanningScreen extends ConsumerWidget {
  const PlanningScreen({super.key, this.collectionId, this.deckId});

  final String? collectionId;
  final String? deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(planningOverviewProvider);
    final planning = state.value;
    final today = planning?.progress();
    final pastSessions = planning?.pastSessions ?? const <PastStudySession>[];
    final scheduledPlans =
        planning == null
              ? <StudyPlan>[]
              : planning.plans.where((plan) {
                  if (!planning.activePlans.contains(plan)) return true;
                  return plan.isRecurring ||
                      plan.occursOn(planning.today) ||
                      plan.nextOnOrAfter(planning.today.add(_oneDay)) != null;
                }).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return AppScaffold(
      maxContentWidth: AppTheme.formMaxWidth,
      child: SyncRefreshIndicator(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => popOrGo(context, '/'),
                  tooltip: 'Retour',
                  icon: const Icon(AppIcons.arrowLeft),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Planning',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (planning == null || today == null)
              state.hasError
                  ? AppErrorState(
                      onRetry: () => ref.invalidate(planningOverviewProvider),
                    )
                  : const Center(child: CircularProgressIndicator())
            else ...[
              const SectionLabel('Aujourd’hui'),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        today.total == 0
                            ? 'Aucune carte prévue aujourd’hui.'
                            : '${today.worked} sur ${today.total} cartes travaillées',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (today.successRate case final rate?)
                        Text(
                          '${(rate * 100).round()} % de réussite sur ${today.attempts} réponses',
                        ),
                      if (today.remaining.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        FilledButton.icon(
                          onPressed: () => context.push(plannedStudyLocation()),
                          icon: const Icon(AppIcons.play),
                          label: const Text('Étudier le planning du jour'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              StudyFollowUps(planning: planning),
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel('Séances programmées'),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: planning.collections.isEmpty
                      ? null
                      : () => _showEditor(context, planning),
                  icon: const Icon(Icons.add),
                  label: const Text('Planifier une séance'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (scheduledPlans.isEmpty)
                Text(
                  planning.collections.isEmpty
                      ? 'Importe un cours pour programmer ta première séance.'
                      : 'Aucune séance programmée pour le moment.',
                ),
              for (final plan in scheduledPlans)
                _PlanCard(
                  plan: plan,
                  planning: planning,
                  onEdit: () => _showEditor(context, planning, plan),
                ),
              const SizedBox(height: AppSpacing.md),
              const SectionLabel('Séances passées'),
              const SizedBox(height: AppSpacing.sm),
              if (pastSessions.isEmpty)
                const Text('Aucune séance passée pour le moment.'),
              for (final session in pastSessions)
                _PastSessionCard(session: session, planning: planning),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showEditor(
    BuildContext context,
    PlanningOverview planning, [
    StudyPlan? plan,
  ]) => showDialog<void>(
    context: context,
    builder: (_) => _PlanEditor(
      planning: planning,
      plan: plan,
      collectionId: collectionId,
      deckId: deckId,
    ),
  );
}

class _PastSessionCard extends StatelessWidget {
  const _PastSessionCard({required this.session, required this.planning});

  final PastStudySession session;
  final PlanningOverview planning;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMMM yyyy', 'fr_FR').format(session.date);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _planTitle(planning, session.plan),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('Séance du $date'),
              ],
            );
            final overall = Column(
              crossAxisAlignment: constraints.maxWidth >= 600
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${session.percent} %',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text('${session.worked} sur ${session.total} cartes'),
              ],
            );
            if (session.plan.deckId != null) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: title),
                  overall,
                ],
              );
            }
            final results = LayoutBuilder(
              builder: (context, resultConstraints) {
                final columns = resultConstraints.maxWidth >= 760
                    ? 3
                    : resultConstraints.maxWidth >= 480
                    ? 2
                    : 1;
                final spacing = AppSpacing.md;
                final deckWidth =
                    (resultConstraints.maxWidth - spacing * (columns - 1)) /
                    columns;
                final deckDetails = Wrap(
                  spacing: spacing,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final deck in session.decks)
                      SizedBox(
                        width: deckWidth,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            borderRadius: AppTheme.radiusSm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      planning.decks
                                              .where(
                                                (item) =>
                                                    item.id == deck.deckId,
                                              )
                                              .firstOrNull
                                              ?.name ??
                                          'Deck',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    '${deck.percent} %',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                  ),
                                ],
                              ),
                              Text('${deck.worked}/${deck.total} cartes'),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerRight, child: overall),
                    const SizedBox(height: AppSpacing.md),
                    deckDetails,
                  ],
                );
              },
            );
            if (constraints.maxWidth >= 600) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: constraints.maxWidth * .32, child: title),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(child: results),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: AppSpacing.md),
                results,
              ],
            );
          },
        ),
      ),
    );
  }
}

String _planTitle(PlanningOverview planning, StudyPlan plan) {
  final collection = planning.collections
      .where((item) => item.id == plan.collectionId)
      .firstOrNull;
  final deck = planning.decks
      .where((item) => item.id == plan.deckId)
      .firstOrNull;
  return deck == null
      ? collection?.name ?? 'Collection'
      : '${collection?.name ?? 'Collection'} · ${deck.name}';
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({
    required this.plan,
    required this.planning,
    required this.onEdit,
  });

  final StudyPlan plan;
  final PlanningOverview planning;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekdays = plan.weekdays.toList()..sort();
    final active = planning.activePlans.contains(plan);
    final today = active && plan.occursOn(planning.today)
        ? planning.progress(plan: plan)
        : const PlanningProgress();
    final next = plan.nextOnOrAfter(
      today.remaining.isEmpty ? planning.today.add(_oneDay) : planning.today,
    );
    final last = planning.lastPlanBefore(
      collectionId: plan.collectionId,
      deckId: plan.deckId,
    );
    final cadence = plan.isRecurring
        ? weekdays.map((day) => _shortDayNames[day - 1]).join(' · ')
        : 'Séance ponctuelle';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _planTitle(planning, plan),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(cadence),
            Text(
              !active
                  ? 'Cours désactivé'
                  : today.isComplete &&
                        !plan.isRecurring &&
                        !plan.followUps.containsKey(planning.today)
                  ? 'Séance terminée. Choisis la suite.'
                  : next == null
                  ? last != null
                        ? 'Dernière séance ${formatRelativePlanningDate(last, today: planning.today)}'
                        : 'Aucune prochaine séance'
                  : 'Prochaine séance ${formatRelativePlanningDate(next, today: planning.today)}',
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (today.remaining.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => context.push(
                      plannedStudyLocation(
                        collectionId: plan.collectionId,
                        deckId: plan.deckId,
                        planId: plan.id,
                      ),
                    ),
                    icon: const Icon(AppIcons.play),
                    label: Text('Étudier (${today.remaining.length})'),
                  ),
                TextButton(onPressed: onEdit, child: const Text('Modifier')),
                TextButton(
                  onPressed: () => _delete(context, ref),
                  child: const Text('Supprimer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(appRepositoryProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette séance ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await repository.deleteStudyPlan(plan.id);
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'La séance n’a pas pu être supprimée.');
      }
    }
  }
}

class _PlanEditor extends ConsumerStatefulWidget {
  const _PlanEditor({
    required this.planning,
    this.plan,
    this.collectionId,
    this.deckId,
  });

  final PlanningOverview planning;
  final StudyPlan? plan;
  final String? collectionId;
  final String? deckId;

  @override
  ConsumerState<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends ConsumerState<_PlanEditor> {
  late String _collectionId;
  String? _deckId;
  late DateTime _date;
  late bool _recurring;
  late Set<int> _weekdays;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    final requestedDeck = plan?.deckId ?? (plan == null ? widget.deckId : null);
    final deck = widget.planning.decks
        .where((item) => item.id == requestedDeck)
        .firstOrNull;
    final requestedCollection =
        plan?.collectionId ?? deck?.collectionId ?? widget.collectionId;
    _collectionId =
        widget.planning.collections
            .where((item) => item.id == requestedCollection)
            .firstOrNull
            ?.id ??
        widget.planning.collections.first.id;
    _deckId = deck?.collectionId == _collectionId ? deck?.id : null;
    _date = plan?.startDate ?? widget.planning.today;
    _recurring = plan?.isRecurring ?? false;
    _weekdays = {...?plan?.weekdays};
  }

  @override
  Widget build(BuildContext context) {
    final decks = widget.planning.decks.where(
      (deck) => deck.collectionId == _collectionId,
    );
    return AlertDialog(
      title: Text(
        widget.plan == null ? 'Planifier une séance' : 'Modifier la séance',
      ),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.md,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _collectionId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Collection'),
              items: [
                for (final collection in widget.planning.collections)
                  DropdownMenuItem(
                    value: collection.id,
                    child: Text(
                      collection.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null || value == _collectionId) return;
                      setState(() {
                        _collectionId = value;
                        _deckId = null;
                      });
                    },
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(_collectionId),
              initialValue: _deckId ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Deck'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Toute la collection'),
                ),
                for (final deck in decks)
                  DropdownMenuItem(
                    value: deck.id,
                    child: Text(deck.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(
                      () => _deckId = value == null || value.isEmpty
                          ? null
                          : value,
                    ),
            ),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                '${_recurring ? 'Début' : 'Date'} · ${formatPlanningDate(_date)}',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Répéter chaque semaine'),
              value: _recurring,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _recurring = value),
            ),
            if (_recurring)
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (var index = 0; index < _shortDayNames.length; index++)
                    FilterChip(
                      label: Text(_shortDayNames[index]),
                      selected: _weekdays.contains(index + 1),
                      onSelected: _saving
                          ? null
                          : (selected) => setState(() {
                              if (selected) {
                                _weekdays.add(index + 1);
                              } else {
                                _weekdays.remove(index + 1);
                              }
                            }),
                    ),
                ],
              ),
            if (_error case final error?)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving || (_recurring && _weekdays.isEmpty)
              ? null
              : _save,
          child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final today = widget.planning.today;
    final date = await _pickPlanningDate(
      context,
      _date,
      _date.isBefore(today) ? _date : today,
    );
    if (mounted && date != null) setState(() => _date = date);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(appRepositoryProvider)
          .saveStudyPlan(
            id: widget.plan?.id,
            collectionId: _collectionId,
            deckId: _deckId,
            startDate: _date,
            weekdays: _recurring ? _weekdays : const {},
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'La séance n’a pas pu être enregistrée.';
        });
      }
    }
  }
}

class StudyFollowUps extends StatelessWidget {
  const StudyFollowUps({
    super.key,
    required this.planning,
    this.collectionId,
    this.deckId,
  });

  final PlanningOverview planning;
  final String? collectionId;
  final String? deckId;

  @override
  Widget build(BuildContext context) {
    final pending = planning.pendingFollowUps.where(
      (plan) =>
          (collectionId == null || plan.collectionId == collectionId) &&
          (deckId == null || plan.deckId == null || plan.deckId == deckId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final plan in pending)
          _FollowUpCard(
            key: ValueKey((plan.id, planning.today)),
            title: _planTitle(planning, plan),
            planId: plan.id,
            day: planning.today,
          ),
      ],
    );
  }
}

class _FollowUpCard extends ConsumerStatefulWidget {
  const _FollowUpCard({
    super.key,
    required this.title,
    required this.planId,
    required this.day,
  });

  final String title;
  final String planId;
  final DateTime day;

  @override
  ConsumerState<_FollowUpCard> createState() => _FollowUpCardState();
}

class _FollowUpCardState extends ConsumerState<_FollowUpCard> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final suggested = widget.day.add(const Duration(days: 7));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suite de la séance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(widget.title),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed: _saving ? null : () => _save(suggested),
                  child: Text('Revoir le ${formatPlanningDate(suggested)}'),
                ),
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final date = await _pickPlanningDate(
                            context,
                            suggested,
                            widget.day.add(_oneDay),
                          );
                          if (mounted && date != null) await _save(date);
                        },
                  child: const Text('Choisir une date'),
                ),
                TextButton(
                  onPressed: _saving ? null : () => _save(null),
                  child: const Text('Terminer sans date'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(DateTime? next) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(appRepositoryProvider)
          .decideStudyFollowUp(
            planId: widget.planId,
            occurrence: widget.day,
            nextDate: next,
          );
    } catch (_) {
      if (mounted) {
        _showError(
          context,
          'Impossible d’enregistrer la suite de cette séance.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

Future<DateTime?> _pickPlanningDate(
  BuildContext context,
  DateTime initial,
  DateTime first,
) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: DateTime(9999, 12, 31),
  );
  return date == null ? null : DateTime.utc(date.year, date.month, date.day);
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
