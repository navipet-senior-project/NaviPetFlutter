import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/course_class.dart';
import '../data/mapbox_config.dart';
import '../data/mapbox_navigation_service.dart';
import '../data/navigation_models.dart';
import '../theme/app_theme.dart';

class ClassEditorSheet extends StatefulWidget {
  const ClassEditorSheet({super.key, this.course});

  final CourseClass? course;

  @override
  State<ClassEditorSheet> createState() => _ClassEditorSheetState();
}

class _ClassEditorSheetState extends State<ClassEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _building;
  late final TextEditingController _room;
  late Set<int> _weekdays;
  late TimeOfDay _time;
  late TimeOfDay _endTime;
  bool _saving = false;

  static const _dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    _code = TextEditingController(text: course?.courseCode);
    _name = TextEditingController(text: course?.courseName);
    _building = TextEditingController(text: course?.building);
    _room = TextEditingController(text: course?.room);
    _weekdays = {...?course?.weekdays};
    final parts = course?.startTime.split(':');
    _time = parts == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final endParts = course?.endTime.split(':');
    _endTime = endParts == null
        ? TimeOfDay(hour: (_time.hour + 1) % 24, minute: _time.minute)
        : TimeOfDay(
            hour: int.parse(endParts[0]),
            minute: int.parse(endParts[1]),
          );
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _building.dispose();
    _room.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String _databaseTime(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    // Keep the value explicitly 24-hour and include seconds for PostgreSQL
    // time columns and stricter API validators.
    return '$hour:$minute:00';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one class day.')),
      );
      return;
    }
    if (_toMinutes(_endTime) <= _toMinutes(_time)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    setState(() => _saving = true);
    final service = MapboxNavigationService(accessToken: mapboxPublicToken);
    try {
      var coordinate =
          widget.course?.coordinate ??
          const NavigationCoordinate(latitude: csulbLat, longitude: csulbLng);
      // Geocoding improves the pin, but it must not prevent a class from
      // being saved when Mapbox is unavailable or does not recognize a
      // campus building name.
      try {
        final suggestions = await service
            .suggestPlaces(
              '${_building.text}, CSULB',
              proximity: const NavigationCoordinate(
                latitude: csulbLat,
                longitude: csulbLng,
              ),
            )
            .timeout(const Duration(seconds: 8));
        if (suggestions.isNotEmpty) {
          coordinate =
              (await service
                      .retrievePlace(suggestions.first)
                      .timeout(const Duration(seconds: 8)))
                  .coordinate;
        }
      } on TimeoutException {
        // Keep the campus fallback and continue saving.
      } on NavigationServiceException {
        // Keep the campus fallback and continue saving.
      }
      if (!mounted) return;
      await context.read<AppState>().saveClass(
        CourseClassInput(
          id: widget.course?.id,
          courseCode: _code.text,
          courseName: _name.text,
          building: _building.text,
          room: _room.text,
          weekdays: _weekdays.toList()..sort(),
          startTime: _databaseTime(_time),
          endTime: _databaseTime(_endTime),
          latitude: coordinate.latitude,
          longitude: coordinate.longitude,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save class: $error')));
      }
    } finally {
      service.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.course == null ? 'Add a class' : 'Edit class',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.petInk,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _field(_code, 'Course code', 'CS 328')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_room, 'Room', '518', required: false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(_name, 'Class name', 'Software Engineering'),
              const SizedBox(height: 12),
              _field(
                _building,
                'Building or address',
                'Vivian Engineering Center',
              ),
              const SizedBox(height: 16),
              const Text(
                'Meeting days',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                children: List.generate(7, (index) {
                  final day = index + 1;
                  return ChoiceChip(
                    label: Text(_dayNames[index]),
                    selected: _weekdays.contains(day),
                    selectedColor: AppColors.yellow,
                    onSelected: (selected) => setState(() {
                      selected ? _weekdays.add(day) : _weekdays.remove(day);
                    }),
                  );
                }),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule, color: AppColors.petInk),
                title: const Text('Start time'),
                trailing: TextButton(
                  onPressed: () async {
                    final value = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (value != null) setState(() => _time = value);
                  },
                  child: Text(_time.format(context)),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule, color: AppColors.petInk),
                title: const Text('End time'),
                trailing: TextButton(
                  onPressed: () async {
                    final value = await showTimePicker(
                      context: context,
                      initialTime: _endTime,
                    );
                    if (value != null) setState(() => _endTime = value);
                  },
                  child: Text(_endTime.format(context)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.petInk,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text(_saving ? 'Saving class…' : 'Save class'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _toMinutes(TimeOfDay value) => value.hour * 60 + value.minute;

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      validator: required ? _required : null,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
