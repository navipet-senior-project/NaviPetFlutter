import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/course_class.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_section_navigation.dart';

class PetQuestsScreen extends StatefulWidget {
  const PetQuestsScreen({super.key});

  @override
  State<PetQuestsScreen> createState() => _PetQuestsScreenState();
}

class _PetQuestsScreenState extends State<PetQuestsScreen> {
  final _errors = <String, String>{};
  String? _claiming;
  Timer? _onlineTimer;

  @override
  void initState() {
    super.initState();
    _onlineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && context.read<AppState>().hasRunningOnlineSession) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => petTextScaleCap(_build);

  Widget _build(BuildContext context) {
    final state = context.watch<AppState>();
    final tasks = state.dailyTasks();
    final loading = state.classesBusy && state.classes.isEmpty;
    final error = state.classesError;
    final done = tasks.where((task) => task.done).length;

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PetSectionHeader(title: "Today's quests"),
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (error != null && tasks.isEmpty)
              Expanded(child: _errorState(state, error))
            else if (tasks.isEmpty)
              Expanded(child: _emptyState())
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _summary(done: done, total: tasks.length),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _inlineError(error, onRetry: () => _refresh(state)),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  itemCount: tasks.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == tasks.length) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 2, bottom: 4),
                        child: Text(
                          'Quests come from your saved classes. A campus check-in is not proof of class attendance.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    final task = tasks[index];
                    final key = task.keyFor(DateTime.now());
                    return _questCard(
                      task,
                      error: _errors[key],
                      claiming: _claiming == key,
                      onDetails: () => _showTaskDetails(task),
                      onClaim: () => _claim(state, task, key),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: PetSectionBottomNavigation(
        active: PetSectionTab.quests,
      ),
    );
  }

  Widget _summary({required int done, required int total}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.accentSoft,
      border: Border.all(color: AppColors.petInk, width: 2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$done of $total quests done',
          style: const TextStyle(
            color: AppColors.petInk,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Quests done today',
          value: '$done of $total',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: done / total,
              minHeight: 12,
              color: AppColors.yellow,
              backgroundColor: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _questCard(
    DailyClassTask task, {
    required String? error,
    required bool claiming,
    required VoidCallback onDetails,
    required VoidCallback onClaim,
  }) {
    final state = context.watch<AppState>();
    final running =
        task.kind == 'attend_online' &&
        state.onlineSessionRunning(task.course.id);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final actionLabel = task.done
        ? 'Done'
        : error != null
        ? 'Try again'
        : task.kind == 'attend_online'
        ? running
              ? 'Claim'
              : 'Start'
        : task.kind == 'attend'
        ? 'Check in'
        : 'Claim';
    final background = task.done ? const Color(0xFFEEF8F2) : Colors.white;
    final titleColor = task.done ? const Color(0xFF0F5C34) : AppColors.petInk;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(
          color: task.done ? const Color(0xFFBFE3CF) : AppColors.cardBorder,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: task.done ? null : AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onDetails,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _taskIcon(task),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.label,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        task.kind == 'attend_online'
                            ? 'Online class · ${task.course.startLabel}'
                            : task.kind == 'attend'
                            ? 'Class at ${task.course.startLabel} · ${task.course.courseName}'
                            : '${task.course.courseCode} · ${task.course.courseName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (task.kind == 'attend_online' && !task.done) ...[
            const SizedBox(height: 6),
            Text(
              running
                  ? 'Online session: ${_duration(state.onlineSessionDuration(task.course.id))} / ${_duration(state.onlineSessionRequirement(task.course))} required'
                  : 'Start your online session before claiming.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            _inlineError(error),
          ],
          const SizedBox(height: 12),
          if (largeText)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _rewardChip(
                    task.reward,
                    received: task.done,
                    largeText: true,
                  ),
                ),
                const SizedBox(height: 8),
                if (task.done)
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Reward received',
                      style: TextStyle(
                        color: Color(0xFF0F5C34),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  _actionButton(
                    task,
                    actionLabel,
                    claiming: claiming,
                    onClaim: onClaim,
                    largeText: true,
                  ),
              ],
            )
          else
            Row(
              children: [
                _rewardChip(task.reward, received: task.done),
                const Spacer(),
                if (task.done)
                  const Text(
                    'Reward received',
                    style: TextStyle(
                      color: Color(0xFF0F5C34),
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  _actionButton(
                    task,
                    actionLabel,
                    claiming: claiming,
                    onClaim: onClaim,
                    largeText: false,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _taskIcon(DailyClassTask task) {
    final done = task.done;
    final color = done
        ? AppColors.green
        : task.kind == 'attend_online'
        ? const Color(0xFFE6F0FD)
        : AppColors.accentSoft;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        done
            ? Icons.check
            : task.kind == 'attend_online'
            ? Icons.laptop_outlined
            : Icons.location_on_outlined,
        color: done ? Colors.white : AppColors.petInk,
        size: 24,
      ),
    );
  }

  Widget _rewardChip(
    int amount, {
    required bool received,
    bool largeText = false,
  }) => Container(
    height: largeText ? 48 : 36,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: received ? Colors.white : AppColors.accentSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(Icons.diamond, size: largeText ? 20 : 16, color: AppColors.blue),
        const SizedBox(width: 5),
        Text(
          '+$amount',
          style: const TextStyle(
            color: AppColors.yellowInk,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _actionButton(
    DailyClassTask task,
    String label, {
    required bool claiming,
    required VoidCallback onClaim,
    required bool largeText,
  }) => SizedBox(
    height: largeText ? 64 : 48,
    width: largeText ? double.infinity : null,
    child: FilledButton(
      key: ValueKey('quest-action-${task.course.id}-${task.kind}'),
      onPressed: claiming ? null : onClaim,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.petInk,
        disabledBackgroundColor: const Color(0xFFF2F4F7),
        disabledForegroundColor: AppColors.muted,
        side: const BorderSide(color: AppColors.petInk, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: claiming
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    ),
  );

  Widget _inlineError(String message, {VoidCallback? onRetry}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF3F2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/elbee.png', height: 116),
          const SizedBox(height: 12),
          const Text(
            'Add a class on Calendar to get quests',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.petInk,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.go('/checklist'),
            child: const Text('Open Calendar'),
          ),
        ],
      ),
    ),
  );

  Widget _errorState(AppState state, String error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: AppColors.danger,
          ),
          const SizedBox(height: 12),
          Text(
            _errors['refresh'] ?? "Couldn't load today's quests. $error",
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.danger),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _refresh(state),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  Future<void> _refresh(AppState state) async {
    try {
      await state.refreshClasses();
      if (mounted) setState(() => _errors.clear());
    } catch (error) {
      if (mounted) {
        setState(() => _errors['refresh'] = 'Could not refresh quests: $error');
      }
    }
  }

  Future<void> _claim(AppState state, DailyClassTask task, String key) async {
    if (_claiming != null) return;
    setState(() {
      _claiming = key;
      _errors.remove(key);
    });
    try {
      if (task.kind == 'attend_online' &&
          !state.onlineSessionRunning(task.course.id)) {
        state.startOnlineSession(task.course.id);
        return;
      }
      final result = await state.verifyAndToggleTask(task, DateTime.now());
      final message = switch (result) {
        TaskClaimResult.claimed => null,
        TaskClaimResult.notToday =>
          'This quest is only available on its class day.',
        TaskClaimResult.sessionTooShort =>
          'Keep the online session running for the scheduled class duration before claiming.',
        TaskClaimResult.locationUnavailable =>
          'Turn on location access to check in to this class.',
        TaskClaimResult.tooFar =>
          'Move closer to the class building to check in.',
      };
      if (mounted && message != null) setState(() => _errors[key] = message);
    } catch (error) {
      if (mounted) {
        setState(() => _errors[key] = 'Could not update quest: $error');
      }
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }

  void _showTaskDetails(DailyClassTask task) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => _QuestDetails(task: task),
    );
  }

  String _duration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _QuestDetails extends StatelessWidget {
  const _QuestDetails({required this.task});

  final DailyClassTask task;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.course.courseCode,
          style: const TextStyle(
            color: AppColors.petInk,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(task.course.courseName),
        const SizedBox(height: 16),
        Text(task.label),
        const SizedBox(height: 8),
        Text('${task.course.timeRangeLabel} · ${task.course.locationLabel}'),
        const SizedBox(height: 8),
        Text('Reward: ${task.reward} gems${task.done ? ' · received' : ''}'),
        if (task.kind == 'attend') ...[
          const SizedBox(height: 12),
          const Text(
            'A campus check-in is not proof of class attendance. Location and schedule checks only verify this NaviPet quest.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ],
    ),
  );
}
