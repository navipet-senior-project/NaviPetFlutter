/// Elbee answers from `POST /elbee/ask`.
///
/// Body is `{question, includeNextClass}`. A 200 object has `status`
/// (`options`, `no_match`, `off_campus`, `model_unavailable`, `budget`),
/// optional `explanation` and `clarification` strings, and `cards`. A
/// destination card needs `place_id` and `title`. A rule card needs `text`
/// or `rules[].text`. Coordinates, steps, and parking eligibility are ignored.
enum ElbeeStatus {
  options,
  noMatch,
  offCampus,
  modelUnavailable,
  budget,
  network,
  signedOut,
}

class ElbeeCard {
  const ElbeeCard({
    required this.title,
    this.subtitle,
    this.placeId,
    this.floor,
    this.indoorNote,
    this.provenanceUrl,
    this.ruleText,
    this.sourceUrl,
    this.retrievedAt,
  });

  final String title;
  final String? subtitle;

  /// Set only for a verified destination. Route handoff uses this id alone.
  final String? placeId;
  final String? floor;
  final String? indoorNote;
  final String? provenanceUrl;
  final String? ruleText;
  final String? sourceUrl;
  final String? retrievedAt;

  bool get opensRoute => placeId != null;
}

class ElbeeReply {
  const ElbeeReply({
    required this.status,
    this.explanation,
    this.clarification,
    this.cards = const [],
  });

  final ElbeeStatus status;
  final String? explanation;
  final String? clarification;
  final List<ElbeeCard> cards;

  static ElbeeReply parse(int statusCode, Object? json) {
    if (statusCode == 401) {
      return const ElbeeReply(status: ElbeeStatus.signedOut);
    }
    if (statusCode == 429) {
      return const ElbeeReply(status: ElbeeStatus.budget);
    }
    if (statusCode == 503 || statusCode == 501) {
      return const ElbeeReply(status: ElbeeStatus.modelUnavailable);
    }
    if (json is! Map) {
      return const ElbeeReply(status: ElbeeStatus.modelUnavailable);
    }
    final status = switch (json['status']) {
      'options' => ElbeeStatus.options,
      'no_match' => ElbeeStatus.noMatch,
      'off_campus' => ElbeeStatus.offCampus,
      'model_unavailable' => ElbeeStatus.modelUnavailable,
      'budget' => ElbeeStatus.budget,
      _ => ElbeeStatus.modelUnavailable,
    };
    if (status != ElbeeStatus.options) {
      return ElbeeReply(
        status: status,
        explanation: _text(json['explanation']),
      );
    }
    final cards = _cards(json['cards']);
    return ElbeeReply(
      status: cards.isEmpty ? ElbeeStatus.noMatch : status,
      explanation: _text(json['explanation']),
      clarification: _text(json['clarification']),
      cards: cards,
    );
  }

  static List<ElbeeCard> _cards(Object? raw) {
    if (raw is! List) return const [];
    final cards = <ElbeeCard>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final card = _card(item);
      if (card != null) cards.add(card);
    }
    return cards;
  }

  static ElbeeCard? _card(Map<dynamic, dynamic> json) {
    final kind = json['kind'];
    final placeId = _text(json['place_id']);
    final title = _text(json['title']) ?? _text(json['text']);
    final rule = _rule(json);
    if (kind == 'rule' || (placeId == null && rule != null)) {
      final text = rule?.text ?? title;
      if (text == null) return null;
      return ElbeeCard(
        title: text,
        ruleText: text,
        sourceUrl: rule?.sourceUrl ?? _text(json['source_url']),
        retrievedAt: rule?.retrievedAt ?? _text(json['retrieved_at']),
        provenanceUrl: _text(json['provenance_url']),
      );
    }
    if (placeId == null || title == null || kind == 'rule') return null;
    return ElbeeCard(
      title: title,
      subtitle: _text(json['subtitle']),
      placeId: placeId,
      floor: _text(json['floor']),
      indoorNote: _text(json['indoor_note']),
      provenanceUrl: _text(json['provenance_url']),
    );
  }

  static _Rule? _rule(Map<dynamic, dynamic> json) {
    final direct = _text(json['text']);
    if (direct != null && json['place_id'] == null) {
      return _Rule(
        direct,
        _text(json['source_url']),
        _text(json['retrieved_at']),
      );
    }
    final rules = json['rules'];
    if (rules is! List || rules.isEmpty || rules.first is! Map) return null;
    final first = rules.first as Map;
    final text = _text(first['text']);
    if (text == null) return null;
    return _Rule(
      text,
      _text(first['source_url']),
      _text(first['retrieved_at']),
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _Rule {
  const _Rule(this.text, this.sourceUrl, this.retrievedAt);
  final String text;
  final String? sourceUrl;
  final String? retrievedAt;
}
