import 'package:flutter/material.dart';

import '../data/elbee_gateway.dart';
import '../data/elbee_reply.dart';
import '../theme/app_theme.dart';

/// Asks the authenticated Elbee route and renders verified cards as text.
class ElbeeSheet extends StatefulWidget {
  const ElbeeSheet({
    super.key,
    required this.gateway,
    required this.onOpenPlace,
  });

  final ElbeeGateway gateway;

  /// Existing place id only. The sheet has no coordinates to pass.
  final ValueChanged<String> onOpenPlace;

  @override
  State<ElbeeSheet> createState() => _ElbeeSheetState();
}

class _ElbeeSheetState extends State<ElbeeSheet> {
  static const _reactions = [
    'Elbee tilts their head.',
    'Elbee waits.',
    'Elbee looks at the map.',
  ];

  final _question = TextEditingController();
  var _consent = false;
  var _busy = false;
  var _reaction = 0;
  ElbeeReply? _reply;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _question.text.trim();
    if (question.isEmpty || _busy) return;
    setState(() => _busy = true);
    final reply = await widget.gateway.ask(
      question,
      includeNextClass: _consent,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _reply = reply;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reply = _reply;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _reaction++),
                  child: Image.asset(
                    'assets/images/shark_side.png',
                    width: 64,
                    height: 64,
                    semanticLabel: 'Elbee, NaviPet campus pet',
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Elbee finds verified CSULB places. NaviPet pet, not the '
                    'university parking chatbot. Scanning a room is separate.',
                  ),
                ),
              ],
            ),
            if (_reaction > 0)
              Text(_reactions[(_reaction - 1) % _reactions.length]),
            const SizedBox(height: 12),
            TextField(
              controller: _question,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ask about a CSULB building or room',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                label: const Text('Find my next class'),
                onPressed: () => _question.text = 'Where is my next class?',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _consent = value ?? false),
              title: const Text('Use my next class for this question'),
              subtitle: const Text('Off unless you check this before sending.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            FilledButton(
              onPressed: _busy ? null : _ask,
              child: Text(_busy ? 'Asking…' : 'Ask Elbee'),
            ),
            if (reply != null) ...[
              const SizedBox(height: 12),
              _status(reply),
              for (final card in reply.cards) _card(card),
            ],
          ],
        ),
      ),
    );
  }

  Widget _status(ElbeeReply reply) {
    final fixed = switch (reply.status) {
      ElbeeStatus.options => null,
      ElbeeStatus.noMatch => 'No verified campus match.',
      ElbeeStatus.offCampus => 'Elbee only answers CSULB campus questions.',
      ElbeeStatus.modelUnavailable =>
        "Elbee's assistant is unavailable right now.",
      ElbeeStatus.budget => "Elbee's question budget is used up.",
      ElbeeStatus.network =>
        'Elbee could not be reached. Check your connection.',
      ElbeeStatus.signedOut => 'Sign in again to ask Elbee.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fixed != null) Text(fixed),
        if (reply.explanation != null) Text(reply.explanation!),
        if (reply.clarification != null) Text(reply.clarification!),
      ],
    );
  }

  Widget _card(ElbeeCard card) {
    final lines = <String>[
      card.title,
      if (card.subtitle != null) card.subtitle!,
      if (card.floor != null) 'Floor ${card.floor}',
      if (card.indoorNote != null) card.indoorNote!,
      if (card.provenanceUrl != null) card.provenanceUrl!,
      if (card.sourceUrl != null) card.sourceUrl!,
      if (card.retrievedAt != null) 'Retrieved ${card.retrievedAt}',
    ];
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final line in lines) Text(line)],
    );
    return Card(
      child: card.opensRoute
          ? InkWell(
              onTap: () => widget.onOpenPlace(card.placeId!),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: text,
              ),
            )
          : Padding(padding: const EdgeInsets.all(AppSpacing.md), child: text),
    );
  }
}
