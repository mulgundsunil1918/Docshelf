import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/family_member.dart';
import '../services/profile_service.dart';
import '../utils/app_colors.dart';

class FamilyPickerWidget extends StatelessWidget {
  const FamilyPickerWidget({
    super.key,
    required this.selectedId,
    required this.onChanged,
    this.onAddNew,
  });

  final String? selectedId;
  final ValueChanged<FamilyMember> onChanged;
  final VoidCallback? onAddNew;

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileService>(
      builder: (context, profile, _) {
        final members = profile.members;
        return SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final m in members)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _Avatar(
                    member: m,
                    selected: m.id == selectedId,
                    onTap: () => onChanged(m),
                  ),
                ),
              if (onAddNew != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: onAddNew,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(alpha: 0.18),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.5),
                            ),
                          ),
                          child:
                              const Icon(Icons.add, color: AppColors.accentDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final FamilyMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 56.0 : 50.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.06),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child:
                Text(member.avatar, style: TextStyle(fontSize: selected ? 26 : 22)),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 70,
            child: Text(
              member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
