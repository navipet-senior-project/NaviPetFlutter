import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/course_class.dart';
import '../theme/app_theme.dart';
import 'class_editor_sheet.dart';

/// Opens the details for [course]; Edit class swaps to the editor.
void showClassDetailSheet(BuildContext context, CourseClass course) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => ClassDetailSheet(
      course: course,
      completions: context.read<AppState>().completionCountFor(course.id),
      onEdit: () {
        Navigator.pop(sheetContext);
        showClassEditorSheet(context, course);
      },
    ),
  );
}

/// The details a calendar block leaves out: when the class meets, where,
/// and achievement progress, with a way into the editor.
class ClassDetailSheet extends StatelessWidget {
  const ClassDetailSheet({
    super.key,
    required this.course,
    required this.completions,
    required this.onEdit,
  });

  final CourseClass course;
  final int completions;
  final VoidCallback onEdit;

  /// Completions needed to fill an achievement.
  static const goal = 5;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// `1 task completed · 1/5`.
  static String progressLabel(int count) =>
      '$count ${count == 1 ? 'task' : 'tasks'} completed · '
      '${count.clamp(0, goal)}/$goal';

  @override
  Widget build(BuildContext context) {
    final days = ([...course.weekdays]..sort())
        .where((day) => day >= 1 && day <= 7)
        .map((day) => _dayNames[day - 1])
        .join(', ');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.courseCode,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.petInk,
              ),
            ),
            Text(
              course.courseName,
              style: const TextStyle(fontSize: 15, color: AppColors.labelInk),
            ),
            const SizedBox(height: AppSpacing.lg),
            _row(Icons.schedule, '$days · ${course.timeRangeLabel}'),
            _row(
              course.isOnline
                  ? Icons.videocam_outlined
                  : Icons.location_on_outlined,
              course.locationLabel,
            ),
            _row(Icons.workspace_premium_outlined, progressLabel(completions)),
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: completions.clamp(0, goal) / goal,
                  minHeight: 8,
                  color: AppColors.yellow,
                  backgroundColor: AppColors.cardBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onEdit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.petInk,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text(
                  'Edit class',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.petInk),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, color: AppColors.petInk),
          ),
        ),
      ],
    ),
  );
}
