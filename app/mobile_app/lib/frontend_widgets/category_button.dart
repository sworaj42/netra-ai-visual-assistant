import 'package:flutter/material.dart';

import '../frontend_theme/app_theme.dart';


class CategoryButton extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon; // New Icon parameter
  final VoidCallback onTap;

  const CategoryButton({
    super.key,
    required this.label,
    required this.hint,
    required this.icon, // Required parameter
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Semantics(
          label: label,
          hint: hint,
          button: true, // Merged semantics
          excludeSemantics: true,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(
                color: AppTheme.borderColor,
                width: 1,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 28, // Slightly smaller for balance
                      color: AppTheme.primaryBrand, 
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 13, // Prevent wrapping
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

