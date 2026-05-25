import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/symptom.dart';
import '../utils/app_theme.dart';

class SymptomChipWidget extends StatelessWidget {
  final Symptom symptom;
  final VoidCallback onTap;

  const SymptomChipWidget({
    super.key,
    required this.symptom,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: symptom.isSelected
              ? AppTheme.primary
              : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: symptom.isSelected
                ? AppTheme.primary
                : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: symptom.isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (symptom.isSelected) ...[
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    symptom.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: symptom.isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: symptom.isSelected
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(target: symptom.isSelected ? 1 : 0)
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.03, 1.03),
          duration: 150.ms,
        );
  }
}
