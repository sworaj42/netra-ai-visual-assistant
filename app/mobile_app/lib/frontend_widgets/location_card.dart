import 'package:flutter/material.dart';
import '../frontend_models/location_model.dart';
import '../frontend_theme/app_theme.dart';


class LocationCard extends StatelessWidget {
  final LocationModel location;
  final VoidCallback? onTap;

  const LocationCard({
    super.key,
    required this.location,
    this.onTap,
  });

  String _formatDistance(double? distance) {
    if (distance == null) return 'Distance unknown';
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} meters';
    } else {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final distanceText = _formatDistance(location.distance);
    
    // Construct a comprehensive semantic label
    final semanticLabel = '${location.name}, $distanceText away. '
        '${location.address != null ? "Located at ${location.address}. " : ""}'
        'Double tap for details and navigation.';

    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true, // Read our custom label, ignore child text nodes
      container: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM, vertical: AppTheme.spacingS),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            splashColor: AppTheme.primaryBlue.withOpacity(0.1),
            highlightColor: AppTheme.primaryBlue.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // Align to top if text wraps
                    children: [
                      Expanded(
                        child: Text(
                          location.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      if (location.distance != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          ),
                          child: Text(
                            distanceText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (location.address != null) ...[
                    const SizedBox(height: AppTheme.spacingS),
                    Row(
                      children: [
                        Icon(Icons.place, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location.address!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacingS),
                  Divider(color: Colors.grey.withOpacity(0.1)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.my_location,
                        size: 14,
                        color: AppTheme.textSecondary.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary.withOpacity(0.7),
                        ),
                      ),
                      const Spacer(),
                       const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryGreen), // Crimson Arrow
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
