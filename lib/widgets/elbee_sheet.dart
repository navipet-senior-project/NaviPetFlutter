import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/elbee_gateway.dart';
import '../data/elbee_reply.dart';
import '../data/navigation_flow_controller.dart';
import '../theme/app_theme.dart';

/// Opens Elbee and sends a tapped card to [flow] as a verified campus place.
/// [onPlaceSelected] runs once the place is selected, before directions are
/// requested, so a screen other than the map can switch to it.
Future<void> showElbeeSheet(
  BuildContext context, {
  required NavigationFlowController flow,
  VoidCallback? onPlaceSelected,
}) {
  final gateway = context.read<ElbeeGateway>();
  // Captured up front: [onPlaceSelected] may leave this screen.
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Large text makes the sheet full height; keep it off the status bar.
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: ElbeeSheet(
        gateway: gateway,
        onOpenPlace: (placeId) async {
          Navigator.of(sheetContext).pop();
          try {
            final place = await flow.searchGateway.place(placeId);
            if (!context.mounted) return;
            if (!place.isLocal) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Elbee can only open verified CSULB campus places.',
                  ),
                ),
              );
              return;
            }
            await flow.selectPlace(place);
            onPlaceSelected?.call();
            await flow.requestDirections();
          } catch (error) {
            messenger.showSnackBar(
              SnackBar(content: Text('Could not open that place: $error')),
            );
          }
        },
      ),
    ),
  );
}

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
  var _replyConsent = false;
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
    final consent = _consent;
    setState(() {
      _busy = true;
      _consent = false;
      _reply = null;
      _replyConsent = false;
    });
    final ElbeeReply reply;
    try {
      reply = await widget.gateway.ask(question, scheduleConsent: consent);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _reply = const ElbeeReply(status: ElbeeStatus.network);
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _reply = reply;
      _replyConsent = consent;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reply = _reply;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
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
              for (final card in reply.cards)
                _place(card.title, card.placeId, [
                  if (card.subtitle != null) card.subtitle!,
                  if (card.floor != null) 'Floor ${card.floor}',
                  if (card.indoorNote != null) card.indoorNote!,
                ]),
              if (reply.parking != null) _parking(reply.parking!),
              if (_replyConsent && reply.nextClass != null)
                _nextClass(reply.nextClass!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _status(ElbeeReply reply) {
    final fixed = switch (reply.status) {
      ElbeeStatus.ok || ElbeeStatus.ambiguous => null,
      ElbeeStatus.noMatch => 'No verified campus match.',
      ElbeeStatus.offTopic => 'Elbee only answers CSULB campus questions.',
      ElbeeStatus.unavailable => "Elbee's assistant is unavailable right now.",
      ElbeeStatus.budget => "Elbee's question budget is used up.",
      ElbeeStatus.consentRequired =>
        'Check "Use my next class" before asking about your schedule.',
      ElbeeStatus.demo => 'Demo data. Not a live model.',
      ElbeeStatus.network =>
        'Elbee could not be reached. Check your connection.',
      ElbeeStatus.signedOut =>
        'Sign in to use your next class in this question.',
      ElbeeStatus.rateLimited => 'Elbee is limiting questions for this hour.',
      ElbeeStatus.conflict => 'That question is already being answered.',
      ElbeeStatus.rejected =>
        'Ask a CSULB question in 500 characters or fewer.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reply.disclosure != null) Text(reply.disclosure!),
        if (fixed != null) Text(fixed),
        if (reply.explanation != null) Text(reply.explanation!),
        if (reply.clarifyingQuestion != null) Text(reply.clarifyingQuestion!),
      ],
    );
  }

  Widget _parking(ElbeeParking parking) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(parking.disclaimer),
          for (final rule in parking.rules) ...[
            Text(rule.text),
            if (rule.sourceUrl != null) Text(rule.sourceUrl!),
            if (rule.retrievedAt != null) Text('Retrieved ${rule.retrievedAt}'),
          ],
        ],
      ),
    ),
  );

  Widget _nextClass(ElbeeNextClass next) {
    final lines = [
      next.courseCode,
      if (next.startTime != null && next.endTime != null)
        '${next.startTime}–${next.endTime}',
    ];
    final placeId = next.placeId;
    if (placeId == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final line in lines) Text(line)],
          ),
        ),
      );
    }
    return _place(lines.first, placeId, lines.skip(1).toList());
  }

  Widget _place(String title, String placeId, List<String> lines) => Card(
    child: InkWell(
      onTap: () => widget.onOpenPlace(placeId),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(title), for (final line in lines) Text(line)],
        ),
      ),
    ),
  );
}
