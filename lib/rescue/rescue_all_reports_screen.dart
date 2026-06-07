import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:disaster360/colors.dart';
import 'package:disaster360/providers/rescue_provider.dart';
import 'package:disaster360/rescue/rescue_tasks_screen.dart';

class RescueAllReportsScreen extends StatefulWidget {
  const RescueAllReportsScreen({super.key});

  @override
  State<RescueAllReportsScreen> createState() => _RescueAllReportsScreenState();
}

class _RescueAllReportsScreenState extends State<RescueAllReportsScreen> {
  String _searchQuery = '';

  List<RescueTask> _filteredTasks(List<RescueTask> allTasks) {
    if (_searchQuery.isEmpty) return allTasks;
    final q = _searchQuery.toLowerCase();
    return allTasks
        .where(
          (t) =>
              t.taskId.toLowerCase().contains(q) ||
              t.type.toLowerCase().contains(q) ||
              t.location.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RescueProvider>(
      builder: (context, provider, _) {
        final allTasks = provider.allVerifiedReports;
        final filtered = _filteredTasks(allTasks);

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'All Verified Reports',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.info.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.info.withOpacity(0.4)),
                            ),
                            child: Text(
                              '${allTasks.length} Total',
                              style: const TextStyle(
                                color: AppColors.info,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Search reports...',
                            hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: Colors.white30, size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: provider.isLoading && allTasks.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                          ),
                        )
                      : filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No verified reports available.',
                                style: TextStyle(color: Colors.white54, fontSize: 15),
                              ),
                            )
                          : RefreshIndicator(
                              color: AppColors.orange,
                              backgroundColor: AppColors.bgSurface,
                              onRefresh: () => provider.fetchAll(),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 14),
                                itemBuilder: (context, i) {
                                  final task = filtered[i];
                                  return _ReportCard(task: task);
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final RescueTask task;
  const _ReportCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                task.type.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                task.assignedAgo,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.description.isEmpty ? 'No description provided' : task.description,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.danger, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  task.location,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
