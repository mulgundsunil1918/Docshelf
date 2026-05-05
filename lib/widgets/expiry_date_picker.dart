import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../utils/app_colors.dart';
import '../utils/constants.dart';

class ExpiryDatePicker extends StatefulWidget {
  const ExpiryDatePicker({
    super.key,
    this.initialDate,
    this.initialReminderDays = 30,
    required this.onChanged,
  });

  final DateTime? initialDate;
  final int initialReminderDays;

  /// Called whenever the user toggles or changes the values.
  /// `date` is null when the toggle is off.
  final void Function(DateTime? date, int reminderDays) onChanged;

  @override
  State<ExpiryDatePicker> createState() => _ExpiryDatePickerState();
}

class _ExpiryDatePickerState extends State<ExpiryDatePicker> {
  late bool _enabled;
  DateTime? _date;
  late int _reminderDays;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _enabled = widget.initialDate != null;
    _reminderDays = widget.initialReminderDays;
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 365)),
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now.add(const Duration(days: 365 * 30)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      widget.onChanged(_date, _reminderDays);
    }
  }

  String? _reminderPreview() {
    if (_date == null) return null;
    final remind = _date!.subtract(Duration(days: _reminderDays));
    return "You'll be notified on ${DateFormat('d MMM yyyy').format(remind)}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  size: 20, color: AppColors.accentDark),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This document has an expiry date',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '(like insurance, policy, contract, passport, license)',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _enabled,
                onChanged: (v) {
                  setState(() {
                    _enabled = v;
                    if (!v) _date = null;
                  });
                  widget.onChanged(_enabled ? _date : null, _reminderDays);
                },
              ),
            ],
          ),
          if (_enabled) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: _pick,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.event, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _date == null
                          ? 'Pick expiry date'
                          : DateFormat('d MMM yyyy').format(_date!),
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined, size: 18),
                const SizedBox(width: 8),
                const Text('Remind me'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _reminderDays,
                  underline: const SizedBox.shrink(),
                  items: AppConstants.reminderDayOptions
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text('$d days before'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _reminderDays = v);
                      widget.onChanged(_date, _reminderDays);
                    }
                  },
                ),
              ],
            ),
            if (_reminderPreview() != null)
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 2),
                child: Text(
                  _reminderPreview()!,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
