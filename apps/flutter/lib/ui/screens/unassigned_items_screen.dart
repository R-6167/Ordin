import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass.dart';
import 'goal_detail_screen.dart';
import 'project_detail_screen.dart';

/// Goals and projects with no life area — opened from the Life "Unassigned" card.
class UnassignedItemsScreen extends StatelessWidget {
  const UnassignedItemsScreen({
    super.key,
    required this.goals,
    required this.projects,
  });

  final List<Goal> goals;
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Unassigned'),
        ),
        body: (goals.isEmpty && projects.isEmpty)
            ? const Center(
                child: EmptyState(
                  title: 'Nothing unassigned',
                  detail:
                      'New goals and projects without a life area show up here.',
                  icon: Icons.inbox_outlined,
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  if (projects.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8, top: 4),
                      child: Text(
                        'Projects',
                        style: TextStyle(
                          color: AppTheme.silverMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    ...projects.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProjectDetailScreen(projectId: p.id),
                              ),
                            );
                          },
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              p.title,
                              style: const TextStyle(
                                color: AppTheme.silver,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              p.goalId != null && p.goalId!.isNotEmpty
                                  ? 'Linked to a goal · no life area'
                                  : 'No life area',
                              style: TextStyle(
                                color: AppTheme.silver.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: AppTheme.silver.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (goals.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8, top: 12),
                      child: Text(
                        'Goals',
                        style: TextStyle(
                          color: AppTheme.silverMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    ...goals.map(
                      (g) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GoalDetailScreen(goalId: g.id),
                              ),
                            );
                          },
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              g.title,
                              style: const TextStyle(
                                color: AppTheme.silver,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'No life area',
                              style: TextStyle(
                                color: AppTheme.silver.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: AppTheme.silver.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Tip: open an item and assign a life area so it appears under that domain on Life.',
                    style: TextStyle(
                      color: AppTheme.silver.withValues(alpha: 0.45),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
