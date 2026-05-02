import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_colors.dart';

class EmojiPickerButton extends StatelessWidget {
  const EmojiPickerButton({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final String current;
  final ValueChanged<String> onChanged;

  static const _options = [
    '📁', '📂', '🪪', '💰', '🏥', '🏠', '🚗', '🎓', '💼', '🧾', '✈️',
    '👨‍👩‍👧', '📦', '🏦', '📈', '💳', '📊', '💊', '🧪', '🛡️', '🏘️',
    '📜', '🌿', '📑', '🏆', '📨', '💵', '📝', '📄', '⚡', '💧', '🌐',
    '📱', '🎟️', '🛂', '🏨', '👶', '💍', '📸', '⭐', '🔖', '🎵', '🎥',
    '🖼️', '🆔', '📘', '🗳️', '🚙',
  ];

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pick an emoji',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in _options)
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(e),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: e == current
                                  ? AppColors.primary.withValues(alpha: 0.16)
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(current, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}
