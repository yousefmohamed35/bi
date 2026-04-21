import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/localization/localization_helper.dart';
import '../l10n/app_localizations.dart';

/// Premium Course Card - Modern and Attractive Design
class PremiumCourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onTap;

  const PremiumCourseCard({
    super.key,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isFree = course['is_free'] ?? course['isFree'] ?? false;
    final imagePath = course['thumbnail'] ?? course['image'] ?? '';
    final categoryName = course['category'] is Map
        ? context.localizedApiText(
            Map<String, dynamic>.from(course['category'] as Map),
            'name',
          )
        : (course['category'] ?? '').toString();
    final title = context.localizedApiText(course, 'title');
    final instructorName = course['instructor'] is Map
        ? context.localizedApiText(
            Map<String, dynamic>.from(course['instructor'] as Map),
            'name',
          )
        : (course['instructor'] ?? '').toString();
    final rating = course['rating'] ?? 0.0;
    final hours = course['duration_hours'] ?? course['hours'] ?? 0;
    final lessons = course['lessons_count'] ?? course['lessons'] ?? 0;
    final price = course['price'] ?? 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Stack(
                    children: [
                      Container(
                        height: 130,
                        width: double.infinity,
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        child: imagePath.toString().isNotEmpty
                            ? (imagePath.toString().startsWith('http') ||
                                    imagePath.toString().startsWith('https')
                                ? Image.network(
                                    imagePath.toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      child: Icon(Icons.image,
                                          color: colorScheme.primary, size: 40),
                                    ),
                                  )
                                : Image.asset(
                                    imagePath.toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      child: Icon(Icons.image,
                                          color: colorScheme.primary, size: 40),
                                    ),
                                  ))
                            : Container(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.1),
                                child: Icon(Icons.image,
                                    color: colorScheme.primary, size: 40),
                              ),
                      ),
                      Container(
                        height: 130,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          categoryName.toString(),
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Price/Free Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: isFree
                          ? const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)])
                          : const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isFree
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B))
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      isFree
                          ? l10n.free
                          : l10n
                              .egyptianPound(price is num ? price.toInt() : 0),
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Play button overlay
                Positioned(
                  bottom: -20,
                  left: 16,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          Color.lerp(
                            colorScheme.primary,
                            colorScheme.shadow,
                            0.28,
                          )!,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.play_arrow_rounded,
                        color: colorScheme.onPrimary, size: 26),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 28, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toString(),
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Instructor
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withValues(alpha: 0.1),
                        ),
                        child: Icon(Icons.person,
                            size: 14, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        instructorName.toString(),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stats Row
                  Row(
                    children: [
                      // Rating
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text(
                              rating.toString(),
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Hours
                      Icon(Icons.access_time_rounded,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        '$hours${l10n.hourShort}',
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      // Lessons
                      Icon(Icons.menu_book_rounded,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        l10n.lessonsCount(lessons is num ? lessons.toInt() : 0),
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
