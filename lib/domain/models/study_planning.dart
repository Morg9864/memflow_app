import 'models.dart';

/// Planning dates are civil days in UTC. Date pickers supply civil dates, so
/// their year/month/day are copied into UTC before passing them to the domain.
DateTime studyDay(DateTime instant) {
  final utc = instant.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}

String studyDayKey(DateTime day) => day.toIso8601String().substring(0, 10);

DateTime? parseStudyDay(Object? value) {
  if (value is! String ||
      value.startsWith('0000') ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  return parsed != null && studyDayKey(parsed) == value ? parsed : null;
}

class StudyPlan {
  const StudyPlan({
    required this.id,
    required this.collectionId,
    this.deckId,
    required this.startDate,
    this.weekdays = const {},
    this.followUps = const {},
  });

  final String id;
  final String collectionId;
  final String? deckId;
  final DateTime startDate;
  final Set<int> weekdays;
  final Map<DateTime, DateTime?> followUps;

  bool get isRecurring => weekdays.isNotEmpty;

  bool covers(String collectionId, String deckId) =>
      this.collectionId == collectionId &&
      (this.deckId == null || this.deckId == deckId);

  Iterable<DateTime> get oneOffDates sync* {
    if (isRecurring) return;
    DateTime? date = startDate;
    while (date != null) {
      yield date;
      final next = followUps[date];
      if (next == null || !next.isAfter(date)) return;
      date = next;
    }
  }

  bool occursOn(DateTime day) => isRecurring
      ? !day.isBefore(startDate) && weekdays.contains(day.weekday)
      : oneOffDates.contains(day);

  DateTime? nextOnOrAfter(DateTime day) {
    if (!isRecurring) {
      for (final date in oneOffDates) {
        if (!date.isBefore(day) && !followUps.containsKey(date)) return date;
      }
      return null;
    }
    var candidate = day.isBefore(startDate) ? startDate : day;
    for (var offset = 0; offset < 7; offset++) {
      if (weekdays.contains(candidate.weekday)) return candidate;
      candidate = candidate.add(const Duration(days: 1));
    }
    return null;
  }

  Map<String, String?> get followUpPayload => {
    for (final entry in followUps.entries)
      studyDayKey(entry.key): entry.value == null
          ? null
          : studyDayKey(entry.value!),
  };

  static StudyPlan? fromPayload(Map<String, dynamic> payload) {
    final id = payload['id'];
    final collectionId = payload['collection_id'];
    final deckId = payload['deck_id'];
    final date = parseStudyDay(payload['start_date']);
    final weekdays = payload['weekdays'];
    if (id is! String ||
        collectionId is! String ||
        (deckId != null && deckId is! String) ||
        date == null ||
        weekdays is! List ||
        weekdays.any((day) => day is! int || day < 1 || day > 7)) {
      return null;
    }
    final followUps = <DateTime, DateTime?>{};
    final raw = payload['follow_ups'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final occurrence = parseStudyDay(entry.key);
        final next = parseStudyDay(entry.value);
        if (occurrence != null &&
            (entry.value == null || (next?.isAfter(occurrence) ?? false))) {
          followUps[occurrence] = next;
        }
      }
    }
    return StudyPlan(
      id: id,
      collectionId: collectionId,
      deckId: deckId as String?,
      startDate: date,
      weekdays: weekdays.cast<int>().toSet(),
      followUps: followUps,
    );
  }
}

class PlanningProgress {
  const PlanningProgress({
    this.remaining = const [],
    this.worked = 0,
    this.attempts = 0,
    this.correct = 0,
  });

  final List<FlashcardRecord> remaining;
  final int worked;
  final int attempts;
  final int correct;

  int get total => worked + remaining.length;
  double? get successRate => attempts == 0 ? null : correct / attempts;
  bool get isComplete => worked > 0 && remaining.isEmpty;
}

class PastStudySessionDeckProgress {
  const PastStudySessionDeckProgress({
    required this.deckId,
    required this.worked,
    required this.total,
  });

  final String deckId;
  final int worked;
  final int total;

  int get percent => total == 0 ? 0 : (worked * 100 / total).round();
}

class PastStudySession {
  const PastStudySession({
    required this.plan,
    required this.date,
    required this.worked,
    required this.total,
    required this.decks,
  });

  final StudyPlan plan;
  final DateTime date;
  final int worked;
  final int total;
  final List<PastStudySessionDeckProgress> decks;

  int get percent => total == 0 ? 0 : (worked * 100 / total).round();
}

class PlanningOverview {
  PlanningOverview({
    required this.plans,
    required this.collections,
    required this.decks,
    required this.activeCards,
    required this.srsEnabled,
    required this.now,
    required List<ReviewLogRecord> logs,
  }) : today = studyDay(now) {
    for (final log in logs) {
      _logsByDay.putIfAbsent(studyDay(log.createdAt), () => []).add(log);
    }
    for (final log in _logsByDay[today] ?? const <ReviewLogRecord>[]) {
      _reviewedToday.add(log.flashcardId);
    }
    final activeCollections = {
      for (final collection in collections)
        if (!collection.isDisabled) collection.id,
    };
    final activeDecks = {
      for (final deck in decks)
        if (!deck.isDisabled) deck.id: deck.collectionId,
    };
    activePlans = plans.where((plan) {
      return activeCollections.contains(plan.collectionId) &&
          (plan.deckId == null ||
              activeDecks[plan.deckId] == plan.collectionId);
    }).toList();
    todaysPlans = activePlans.where((plan) => plan.occursOn(today)).toList();
    _todayCollections = {
      for (final plan in todaysPlans)
        if (plan.deckId == null) plan.collectionId,
    };
    _todayDecks = todaysPlans.map((plan) => plan.deckId).nonNulls.toSet();
    final open = todaysPlans.where(
      (plan) => plan.isRecurring || !plan.followUps.containsKey(today),
    );
    _openCollections = {
      for (final plan in open)
        if (plan.deckId == null) plan.collectionId,
    };
    _openDecks = open.map((plan) => plan.deckId).nonNulls.toSet();
  }

  final List<StudyPlan> plans;
  final List<CollectionRecord> collections;
  final List<DeckRecord> decks;
  final List<FlashcardRecord> activeCards;
  final bool srsEnabled;
  final DateTime now;
  final DateTime today;
  late final List<StudyPlan> activePlans;
  late final List<StudyPlan> todaysPlans;
  late final Set<String> _todayCollections;
  late final Set<String> _todayDecks;
  late final Set<String> _openCollections;
  late final Set<String> _openDecks;
  final Map<DateTime, List<ReviewLogRecord>> _logsByDay = {};
  final Set<String> _reviewedToday = {};

  Iterable<StudyPlan> get pendingFollowUps => todaysPlans.where(
    (plan) =>
        !plan.isRecurring &&
        !plan.followUps.containsKey(today) &&
        progress(plan: plan).isComplete,
  );

  List<PastStudySession> get pastSessions {
    final sessions = <PastStudySession>[];
    for (final plan in activePlans.where((plan) => !plan.isRecurring)) {
      final dates = plan.oneOffDates
          .where((date) => date.isBefore(today))
          .toList();
      for (var index = 0; index < dates.length; index++) {
        final date = dates[index];
        final nextOccurrence =
            plan.oneOffDates
                .where((candidate) => candidate.isAfter(date))
                .firstOrNull ??
            today.add(const Duration(days: 1));
        final intervalLogs = _logsByDay.entries
            .where(
              (entry) =>
                  !entry.key.isBefore(date) &&
                  entry.key.isBefore(nextOccurrence),
            )
            .expand((entry) => entry.value)
            .toList();
        final reviewedOnDate = {
          for (final log in _logsByDay[date] ?? const <ReviewLogRecord>[])
            log.flashcardId,
        };
        final reviewed = {for (final log in intervalLogs) log.flashcardId};
        final cutoff = date.add(const Duration(days: 1));
        final lateDueIds = {
          for (final log in intervalLogs)
            if (studyDay(log.createdAt).isAfter(date) &&
                studyDay(log.scheduledDueAt).isBefore(cutoff))
              log.flashcardId,
        };
        final plannedCards = activeCards.where((card) {
          return plan.covers(card.collectionId, card.deckId) &&
              card.createdAt.isBefore(cutoff) &&
              (!srsEnabled ||
                  card.dueAt.isBefore(cutoff) ||
                  reviewedOnDate.contains(card.id) ||
                  lateDueIds.contains(card.id));
        }).toList();
        final collectionDecks =
            decks
                .where(
                  (deck) =>
                      deck.collectionId == plan.collectionId &&
                      !deck.isDisabled,
                )
                .toList()
              ..sort((a, b) {
                final byImport = a.createdAt.compareTo(b.createdAt);
                return byImport != 0 ? byImport : a.name.compareTo(b.name);
              });
        final deckIds = plan.deckId != null
            ? [plan.deckId!]
            : collectionDecks.map((deck) => deck.id).toList();
        final deckProgress = [
          for (final deckId in deckIds)
            () {
              final cards = plannedCards.where((card) => card.deckId == deckId);
              final total = cards.length;
              final worked = cards
                  .where((card) => reviewed.contains(card.id))
                  .length;
              return PastStudySessionDeckProgress(
                deckId: deckId,
                worked: worked,
                total: total,
              );
            }(),
        ];
        sessions.add(
          PastStudySession(
            plan: plan,
            date: date,
            worked: deckProgress.fold(0, (sum, deck) => sum + deck.worked),
            total: deckProgress.fold(0, (sum, deck) => sum + deck.total),
            decks: deckProgress,
          ),
        );
      }
    }
    sessions.sort((a, b) => b.date.compareTo(a.date));
    return sessions;
  }

  ({DateTime date, int worked, int total})? previousSessionProgress({
    required String collectionId,
    String? deckId,
  }) {
    bool coversProgressScope(StudyPlan plan) =>
        plan.collectionId == collectionId &&
        (deckId == null
            ? plan.deckId == null
            : plan.deckId == null || plan.deckId == deckId);
    if (activePlans.any(
      (plan) => coversProgressScope(plan) && plan.occursOn(today),
    )) {
      return null;
    }

    final scopedCards = activeCards
        .where(
          (card) =>
              card.collectionId == collectionId &&
              (deckId == null || card.deckId == deckId),
        )
        .toList();
    final lastScheduledDay = lastPlanBefore(
      collectionId: collectionId,
      deckId: deckId,
    );
    if (lastScheduledDay == null) {
      final seenCards = scopedCards
          .where((card) => card.lastReviewedAt != null)
          .toList();
      if (seenCards.isEmpty || scopedCards.isEmpty) return null;
      final latestActivity = seenCards
          .map((card) => card.lastReviewedAt!)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      return (
        date: studyDay(latestActivity),
        worked: seenCards.length,
        total: scopedCards.length,
      );
    }

    final matchingPlans = activePlans.where(coversProgressScope).toList();
    final previousPlans = matchingPlans
        .where((plan) => plan.occursOn(lastScheduledDay))
        .toList();
    final cutoff = lastScheduledDay.add(const Duration(days: 1));
    final intervalLogs = _logsByDay.entries
        .where(
          (entry) =>
              !entry.key.isBefore(lastScheduledDay) &&
              !entry.key.isAfter(today),
        )
        .expand((entry) => entry.value)
        .toList();
    final reviewedOnDay = {
      for (final log
          in _logsByDay[lastScheduledDay] ?? const <ReviewLogRecord>[])
        log.flashcardId,
    };
    final reviewed = {for (final log in intervalLogs) log.flashcardId};
    final lateDueIds = {
      for (final log in intervalLogs)
        if (studyDay(log.createdAt).isAfter(lastScheduledDay) &&
            studyDay(log.scheduledDueAt).isBefore(cutoff))
          log.flashcardId,
    };
    final plannedCards = scopedCards.where((card) {
      final covered = previousPlans.any(
        (plan) => plan.covers(card.collectionId, card.deckId),
      );
      return covered &&
          card.createdAt.isBefore(cutoff) &&
          (!srsEnabled ||
              card.dueAt.isBefore(cutoff) ||
              reviewedOnDay.contains(card.id) ||
              lateDueIds.contains(card.id));
    }).toList();
    if (plannedCards.isEmpty) return null;
    return (
      date: lastScheduledDay,
      worked: plannedCards.where((card) => reviewed.contains(card.id)).length,
      total: plannedCards.length,
    );
  }

  DateTime? lastPlanBefore({required String collectionId, String? deckId}) {
    DateTime? latest;
    for (final plan in activePlans) {
      if (plan.collectionId != collectionId ||
          (deckId == null
              ? plan.deckId != null
              : plan.deckId != null && plan.deckId != deckId)) {
        continue;
      }
      DateTime? candidate;
      if (plan.isRecurring) {
        for (var offset = 1; offset <= 7; offset++) {
          final day = today.subtract(Duration(days: offset));
          if (plan.occursOn(day)) {
            candidate = day;
            break;
          }
        }
      } else {
        for (final day in plan.oneOffDates) {
          if (day.isBefore(today)) candidate = day;
        }
      }
      if (candidate != null && (latest == null || candidate.isAfter(latest))) {
        latest = candidate;
      }
    }
    return latest;
  }

  PlanningProgress progress({
    String? collectionId,
    String? deckId,
    StudyPlan? plan,
  }) {
    final scope = activeCards.where(
      (card) =>
          (collectionId == null || collectionId == card.collectionId) &&
          (deckId == null || deckId == card.deckId) &&
          (plan == null
              ? _todayCollections.contains(card.collectionId) ||
                    _todayDecks.contains(card.deckId)
              : plan.covers(card.collectionId, card.deckId)),
    );
    final ids = <String>{};
    final remaining = <FlashcardRecord>[];
    var worked = 0;
    for (final card in scope) {
      if (!ids.add(card.id)) continue;
      if (_reviewedToday.contains(card.id)) {
        worked++;
      } else {
        final isOpen = plan == null
            ? _openCollections.contains(card.collectionId) ||
                  _openDecks.contains(card.deckId)
            : plan.isRecurring || !plan.followUps.containsKey(today);
        if (isOpen && (!srsEnabled || !card.dueAt.isAfter(now))) {
          remaining.add(card);
        }
      }
    }
    var attempts = 0;
    var correct = 0;
    for (final log in _logsByDay[today] ?? const <ReviewLogRecord>[]) {
      if (!ids.contains(log.flashcardId)) continue;
      attempts++;
      if (log.wasCorrect) correct++;
    }
    return PlanningProgress(
      remaining: remaining,
      worked: worked,
      attempts: attempts,
      correct: correct,
    );
  }

  bool wasReviewedToday(String cardId) => _reviewedToday.contains(cardId);

  DateTime? nextPlanFor(
    String collectionId, {
    String? deckId,
    bool includeToday = true,
  }) {
    DateTime? next;
    final hasRemaining =
        includeToday &&
        progress(
          collectionId: collectionId,
          deckId: deckId,
        ).remaining.isNotEmpty;
    for (final plan in activePlans) {
      if (plan.collectionId != collectionId ||
          (deckId != null && plan.deckId != null && plan.deckId != deckId)) {
        continue;
      }
      final candidate = plan.nextOnOrAfter(
        hasRemaining ? today : today.add(const Duration(days: 1)),
      );
      if (candidate != null && (next == null || candidate.isBefore(next))) {
        next = candidate;
      }
    }
    return next;
  }

  ({int planned, int worked}) recentActivity({
    String? collectionId,
    String? deckId,
  }) {
    final activeCollectionIds = {
      for (final collection in collections)
        if (!collection.isDisabled) collection.id,
    };
    final scopedDecks = decks.where(
      (deck) =>
          !deck.isDisabled &&
          activeCollectionIds.contains(deck.collectionId) &&
          (collectionId == null || deck.collectionId == collectionId) &&
          (deckId == null || deck.id == deckId),
    );
    var planned = 0;
    var worked = 0;
    for (var offset = 13; offset >= 0; offset--) {
      final day = today.subtract(Duration(days: offset));
      final occurrences = activePlans.where((plan) => plan.occursOn(day));
      final reviewedDecks = (_logsByDay[day] ?? const <ReviewLogRecord>[])
          .map((log) => log.deckId)
          .toSet();
      for (final deck in scopedDecks) {
        if (studyDay(deck.createdAt).isAfter(day)) continue;
        final matching = occurrences.where(
          (plan) => plan.covers(deck.collectionId, deck.id),
        );
        if (matching.isEmpty) continue;
        planned++;
        if (reviewedDecks.contains(deck.id) ||
            matching.any((plan) => plan.followUps.containsKey(day))) {
          worked++;
        }
      }
    }
    return (planned: planned, worked: worked);
  }
}
