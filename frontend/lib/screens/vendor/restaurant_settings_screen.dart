import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/vendor_settings.dart';
import '../../services/restaurant_service.dart';
import '../../widgets/hours/default_hours_editor.dart';
import '../../widgets/hours/day_hours_editor.dart';

class RestaurantSettingsScreen extends StatefulWidget {
  final String token;
  final int restaurantId;
  final String restaurantName;

  const RestaurantSettingsScreen({
    super.key,
    required this.token,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<RestaurantSettingsScreen> createState() =>
      _RestaurantSettingsScreenState();
}

class _RestaurantSettingsScreenState extends State<RestaurantSettingsScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Settings data
  int _prepTimeMinutes = 30;
  HoursOfOperation? _hoursOfOperation;
  DaySchedule _defaultDailyHours = DaySchedule.open(); // Default hours for all days

  // Track which days use default hours vs custom hours
  final Map<String, bool> _useDefaultHours = {
    'monday': true,
    'tuesday': true,
    'wednesday': true,
    'thursday': true,
    'friday': true,
    'saturday': true,
    'sunday': true,
  };

  // Track if hours have been modified
  bool _hoursModified = false;
  bool _prepTimeModified = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings = await _restaurantService.getRestaurantSettings(
        widget.token,
        widget.restaurantId,
      );

      if (mounted) {
        setState(() {
          _prepTimeMinutes = settings.averagePrepTimeMinutes;
          _hoursOfOperation =
              settings.hoursOfOperation ?? HoursOfOperation.defaultHours();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          // Initialize with defaults if loading fails
          _hoursOfOperation = HoursOfOperation.defaultHours();
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if anything was modified
    if (!_hoursModified && !_prepTimeModified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes to save'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final request = UpdateVendorSettingsRequest(
        averagePrepTimeMinutes: _prepTimeModified ? _prepTimeMinutes : null,
        hoursOfOperation: _hoursModified ? _hoursOfOperation : null,
      );

      await _restaurantService.updateRestaurantSettings(
        widget.token,
        widget.restaurantId,
        request,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset modification flags
        setState(() {
          _hoursModified = false;
          _prepTimeModified = false;
          _isSaving = false;
        });

        // Optionally pop back with success result
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateDefaultHours(DaySchedule schedule) {
    setState(() {
      _defaultDailyHours = schedule;
      _hoursModified = true;
      // Apply default hours to all days that are using defaults
      _applyDefaultHoursToAllDays();
    });
  }

  void _applyDefaultHoursToAllDays() {
    HoursOfOperation updated = _hoursOfOperation!;

    _useDefaultHours.forEach((day, useDefault) {
      if (useDefault) {
        switch (day.toLowerCase()) {
          case 'monday':
            updated = updated.copyWith(monday: _defaultDailyHours);
            break;
          case 'tuesday':
            updated = updated.copyWith(tuesday: _defaultDailyHours);
            break;
          case 'wednesday':
            updated = updated.copyWith(wednesday: _defaultDailyHours);
            break;
          case 'thursday':
            updated = updated.copyWith(thursday: _defaultDailyHours);
            break;
          case 'friday':
            updated = updated.copyWith(friday: _defaultDailyHours);
            break;
          case 'saturday':
            updated = updated.copyWith(saturday: _defaultDailyHours);
            break;
          case 'sunday':
            updated = updated.copyWith(sunday: _defaultDailyHours);
            break;
        }
      }
    });

    _hoursOfOperation = updated;
  }

  void _updateDaySchedule(String day, DaySchedule schedule) {
    setState(() {
      _hoursModified = true;
      switch (day.toLowerCase()) {
        case 'monday':
          _hoursOfOperation = _hoursOfOperation!.copyWith(monday: schedule);
          break;
        case 'tuesday':
          _hoursOfOperation = _hoursOfOperation!.copyWith(tuesday: schedule);
          break;
        case 'wednesday':
          _hoursOfOperation = _hoursOfOperation!.copyWith(wednesday: schedule);
          break;
        case 'thursday':
          _hoursOfOperation = _hoursOfOperation!.copyWith(thursday: schedule);
          break;
        case 'friday':
          _hoursOfOperation = _hoursOfOperation!.copyWith(friday: schedule);
          break;
        case 'saturday':
          _hoursOfOperation = _hoursOfOperation!.copyWith(saturday: schedule);
          break;
        case 'sunday':
          _hoursOfOperation = _hoursOfOperation!.copyWith(sunday: schedule);
          break;
      }
    });
  }

  void _updateUseDefault(String day, bool useDefault) {
    setState(() {
      _useDefaultHours[day] = useDefault;
      _hoursModified = true;
      if (useDefault) {
        // Apply default hours to this day
        _updateDaySchedule(day, _defaultDailyHours);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Settings'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSettings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Restaurant Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.restaurant,
                                      color: Colors.deepOrange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.restaurantName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Configure operating hours and preparation time',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Average Prep Time Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.timer,
                                      color: Colors.deepOrange),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Average Preparation Time',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                initialValue: _prepTimeMinutes.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Prep Time (minutes)',
                                  helperText:
                                      'Average time to prepare an order (1-300 minutes)',
                                  suffixText: 'min',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter prep time';
                                  }
                                  final intValue = int.tryParse(value);
                                  if (intValue == null) {
                                    return 'Please enter a valid number';
                                  }
                                  if (intValue < 1 || intValue > 300) {
                                    return 'Prep time must be between 1 and 300 minutes';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  final intValue = int.tryParse(value);
                                  if (intValue != null) {
                                    setState(() {
                                      _prepTimeMinutes = intValue;
                                      _prepTimeModified = true;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Hours of Operation Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.schedule,
                                      color: Colors.deepOrange),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hours of Operation',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Default daily hours
                              DefaultHoursEditor(
                                defaultSchedule: _defaultDailyHours,
                                onScheduleChanged: _updateDefaultHours,
                              ),
                              const SizedBox(height: 24),
                              // Day-specific overrides section header
                              Text(
                                'Day-Specific Overrides',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Customize hours for specific days or use default hours',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 16),
                              // Day editors
                              if (_hoursOfOperation != null) ...[
                                DayHoursEditor(
                                  dayName: 'Monday',
                                  daySchedule: _hoursOfOperation!.monday,
                                  defaultSchedule: _defaultDailyHours,
                                  useDefault: _useDefaultHours['monday']!,
                                  onScheduleChanged: (schedule) => _updateDaySchedule('monday', schedule),
                                  onUseDefaultChanged: (useDefault) => _updateUseDefault('monday', useDefault),
                                ),
                                DayHoursEditor(
                                  dayName: 'Tuesday',
                                  daySchedule: _hoursOfOperation!.tuesday,
                                  defaultSchedule: _defaultDailyHours,
                                  useDefault: _useDefaultHours['tuesday']!,
                                  onScheduleChanged: (schedule) => _updateDaySchedule('tuesday', schedule),
                                  onUseDefaultChanged: (useDefault) => _updateUseDefault('tuesday', useDefault),
                                ),
                                DayHoursEditor(
                                  dayName: 'Wednesday',
                                  daySchedule: _hoursOfOperation!.wednesday,
                                  defaultSchedule: _defaultDailyHours,
                                  useDefault: _useDefaultHours['wednesday']!,
                                  onScheduleChanged: (schedule) => _updateDaySchedule('wednesday', schedule),
                                  onUseDefaultChanged: (useDefault) => _updateUseDefault('wednesday', useDefault),
                                ),
                                DayHoursEditor(
                                  dayName: 'Thursday',
                                  daySchedule: _hoursOfOperation!.thursday,
                                  defaultSchedule: _defaultDailyHours,
                                  useDefault: _useDefaultHours['thursday']!,
                                  onScheduleChanged: (schedule) => _updateDaySchedule('thursday', schedule),
                                  onUseDefaultChanged: (useDefault) => _updateUseDefault('thursday', useDefault),
                                ),
                                DayHoursEditor(
                                  dayName: 'Friday',
                                  daySchedule: _hoursOfOperation!.friday,
                                  defaultSchedule: _defaultDailyHours,
                                  useDefault: _useDefaultHours['friday']!,
                                  onScheduleChanged: (schedule) => _updateDaySchedule('friday', schedule),
                                  onUseDefaultChanged: (useDefault) => _updateUseDefault('friday', useDefault),
                                ),
                                DayHoursEditor(
                                  dayName: 'Saturday',
                                  daySchedule: _hoursOfOperation!.saturday,
                                  defaultSchedule: _defaultDailyHours,
                                  useDefault: _useDefaultHours['saturday']!,
                                  onScheduleChanged: (schedule) => _updateDaySchedule('saturday', schedule),
                                  onUseDefaultChanged: (useDefault) => _updateUseDefault('saturday', useDefault),
                                ),
                                DayHoursEditor(
                                  dayName: 'Sunday',
                                  daySchedule: _hoursOfOperation!.sunday,
                                  defaultSchedule: _defaultDailyHours,
                                  useDefault: _useDefaultHours['sunday']!,
                                  onScheduleChanged: (schedule) => _updateDaySchedule('sunday', schedule),
                                  onUseDefaultChanged: (useDefault) => _updateUseDefault('sunday', useDefault),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Text('Save Settings'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }
}
