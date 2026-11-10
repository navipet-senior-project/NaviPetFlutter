/// Answer from `POST /elbee/ask`.
///
/// Request body is `{question, scheduleConsent, mode: "ask"}`. A 200 object
/// uses `status`, `disclosure`, `explanation`, `clarifyingQuestion`, `cards`,
/// `parking`, and `nextClass`. A destination card needs `placeId` and `title`.
/// Coordinates, steps, and parking eligibility are ignored.
enum ElbeeStatus {
  ok,
  ambiguous,
  noMatch,
  offTopic,
  budget,
  consentRequired,
  unavailable,
  demo,
  network,
  signedOut,
  rateLimited,
  conflict,
  rejected,
}

class ElbeeCard {
  const ElbeeCard({
    required this.title,
    required this.placeId,
    this.subtitle,
    this.floor,
    this.indoorNote,
  });

  final String title;
  final String placeId;
  final String? subtitle;
  final String? floor;
  final String? indoorNote;
}

class ElbeeRule {
  const ElbeeRule({required this.text, this.sourceUrl, this.retrievedAt});

  final String text;
  final String? sourceUrl;
  final String? retrievedAt;
}

class ElbeeParking {
  const ElbeeParking({required this.disclaimer, this.rules = const []});

  final String disclaimer;
  final List<ElbeeRule> rules;
}

class ElbeeNextClass {
  const ElbeeNextClass({
    required this.courseCode,
    this.startTime,
    this.endTime,
    this.placeId,
  });

  final String courseCode;
  final String? startTime;
  final String? endTime;
  final String? placeId;
}

class ElbeeReply {
  const ElbeeReply({
    required this.status,
    this.disclosure,
    this.explanation,
    this.clarifyingQuestion,
    this.cards = const [],
    this.parking,
    this.nextClass,
  });

  final ElbeeStatus status;
  final String? disclosure;
  final String? explanation;
  final String? clarifyingQuestion;
  final List<ElbeeCard> cards;
  final ElbeeParking? parking;
  final ElbeeNextClass? nextClass;

  static ElbeeReply parse(int statusCode, Object? json) {
    final error = json is Map ? json['error'] : null;
    final code = error is Map ? error['code'] : null;
    if (statusCode == 401 || code == 'INVALID_ACCESS_TOKEN') {
      return const ElbeeReply(status: ElbeeStatus.signedOut);
    }
    if (statusCode == 429 || code == 'RATE_LIMITED') {
      return const ElbeeReply(status: ElbeeStatus.rateLimited);
    }
    if (statusCode == 409 || code == 'CONFLICT') {
      return const ElbeeReply(status: ElbeeStatus.conflict);
    }
    if (statusCode == 422 || code == 'VALIDATION_ERROR') {
      return ElbeeReply(
        status: ElbeeStatus.rejected,
        explanation: error is Map ? _text(error['message']) : null,
      );
    }
    if (statusCode == 502 || code == 'UPSTREAM_ERROR') {
      return const ElbeeReply(status: ElbeeStatus.network);
    }
    if (statusCode != 200 || json is! Map) {
      return const ElbeeReply(status: ElbeeStatus.unavailable);
    }
    final status = switch (json['status']) {
      'ok' => ElbeeStatus.ok,
      'ambiguous' => ElbeeStatus.ambiguous,
      'no_match' => ElbeeStatus.noMatch,
      'off_topic' => ElbeeStatus.offTopic,
      'budget_exhausted' => ElbeeStatus.budget,
      'consent_required' => ElbeeStatus.consentRequired,
      'unavailable' => ElbeeStatus.unavailable,
      'demo' => ElbeeStatus.demo,
      _ => ElbeeStatus.unavailable,
    };
    return ElbeeReply(
      status: status,
      disclosure: _text(json['disclosure']),
      explanation: _text(json['explanation']),
      clarifyingQuestion: _text(json['clarifyingQuestion']),
      cards: _cards(json['cards']),
      parking: _parking(json['parking']),
      nextClass: _nextClass(json['nextClass']),
    );
  }

  static List<ElbeeCard> _cards(Object? raw) {
    if (raw is! List) return const [];
    final cards = <ElbeeCard>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final placeId = _text(item['placeId']);
      final title = _text(item['title']);
      if (placeId == null || title == null) continue;
      cards.add(
        ElbeeCard(
          title: title,
          placeId: placeId,
          subtitle: _text(item['subtitle']),
          floor: _text(item['floor']),
          indoorNote: _text(item['indoorNote']),
        ),
      );
    }
    return cards;
  }

  static ElbeeParking? _parking(Object? raw) {
    if (raw is! Map) return null;
    final disclaimer = _text(raw['disclaimer']);
    if (disclaimer == null) return null;
    final rules = <ElbeeRule>[];
    final rawRules = raw['rules'];
    if (rawRules is List) {
      for (final item in rawRules) {
        if (item is! Map) continue;
        final text = _text(item['text']);
        if (text == null) continue;
        rules.add(
          ElbeeRule(
            text: text,
            sourceUrl: _text(item['sourceUrl']),
            retrievedAt: _text(item['retrievedAt']),
          ),
        );
      }
    }
    return ElbeeParking(disclaimer: disclaimer, rules: rules);
  }

  static ElbeeNextClass? _nextClass(Object? raw) {
    if (raw is! Map) return null;
    final courseCode = _text(raw['courseCode']);
    if (courseCode == null) return null;
    return ElbeeNextClass(
      courseCode: courseCode,
      startTime: _text(raw['startTime']),
      endTime: _text(raw['endTime']),
      placeId: _text(raw['placeId']),
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
