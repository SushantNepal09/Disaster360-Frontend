import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:disaster360/providers/report_provider.dart';
import 'package:disaster360/utils/status_helper.dart';

class CitizenReportDetailScreen extends StatelessWidget {
  final ReportModel report;

  const CitizenReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final steps = ['Pending', 'Verified', 'Assigned', 'In Progress', 'Resolved'];
    final currentIndex = _currentStepIndex(report.status);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1117),
        elevation: 0,
        titleSpacing: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
        ),
        title: Text(
          'REPORT #${report.id}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white.withOpacity(0.06), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Title
            Text(
              report.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            
            // Metadata
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Text(
                  _relativeDate(report.createdAt),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Status Pills
            Row(
              children: [
                _buildPill(report.disasterType.toUpperCase()),
                const SizedBox(width: 8),
                _buildPill('SEV: ${report.severity.toUpperCase()}'),
                const SizedBox(width: 8),
                _buildDynamicStatusPill(report.status),
              ],
            ),
            
            const SizedBox(height: 32),
            Container(height: 1, color: Colors.white.withOpacity(0.06)),
            const SizedBox(height: 32),
            
            // Description
            Text(
              report.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            
            const SizedBox(height: 32),
            if (report.mediaUrls.isNotEmpty) ...[
              _MinimalMediaGallery(urls: report.mediaUrls),
              const SizedBox(height: 32),
            ],
            
            // Teams
            const Text(
              'ASSIGNED TEAMS',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _MinimalTeamCard(
              teamName: report.rescueTeam.isNotEmpty ? report.rescueTeam : 'Unassigned',
              role: 'First Responders',
              status: report.rescueTeam.isNotEmpty ? 'En route' : 'Standby',
            ),
            
            const SizedBox(height: 32),
            _MinimalTimeline(steps: steps, currentIndex: currentIndex),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(String text, {bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: isPrimary ? Colors.cyanAccent.withOpacity(0.3) : Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isPrimary ? Colors.cyanAccent : Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDynamicStatusPill(String status) {
    final color = StatusHelper.getStatusColor(status);
    final text = StatusHelper.getStatusText(status).toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _relativeDate(String dateStr) {
    if (dateStr.isEmpty) return 'Just now';
    try {
      if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
        dateStr += 'Z';
      }
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return dateStr.split("T").first;
    }
  }

  int _currentStepIndex(String status) {
    final s = status.toLowerCase();
    if (s == 'pending') return 0;
    if (s == 'verified') return 1;
    if (s == 'assigned') return 2;
    if (s == 'acknowledged') return 2;
    if (s.contains('progress')) return 3;
    if (s.contains('resolved') || s.contains('controlled')) return 4;
    return 0;
  }
}


// ─── Minimal Timeline ────────────────────────────────────────────────────────

class _MinimalTimeline extends StatelessWidget {
  final List<String> steps;
  final int currentIndex;

  const _MinimalTimeline({required this.steps, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STATUS TIMELINE',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(steps.length, (i) {
          final isDone = i <= currentIndex;
          final isCurrent = i == currentIndex;
          final isLast = i == steps.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent 
                              ? Colors.cyanAccent 
                              : (isDone ? Colors.white30 : Colors.transparent),
                          border: Border.all(
                            color: isCurrent 
                                ? Colors.cyanAccent 
                                : (isDone ? Colors.white30 : Colors.white12),
                            width: 2,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            color: isDone && i < currentIndex
                                ? Colors.white30
                                : Colors.white12,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].toUpperCase(),
                        style: TextStyle(
                          color: isCurrent
                              ? Colors.cyanAccent
                              : (isDone ? Colors.white : Colors.white30),
                          fontSize: 13,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Current Stage',
                          style: TextStyle(
                            color: Colors.cyanAccent.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── Minimal Media Gallery ───────────────────────────────────────────────────

class _MinimalMediaGallery extends StatelessWidget {
  final List<String> urls;
  const _MinimalMediaGallery({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EVIDENCE MEDIA',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        // Featured Image (16:9)
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.06)),
              image: DecorationImage(
                image: NetworkImage(urls[0]),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        // Thumbnails
        if (urls.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            children: urls.skip(1).take(3).map((url) {
              return Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: EdgeInsets.only(
                      right: url == urls.last || url == urls[Math.min(3, urls.length - 1)] ? 0 : 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                      image: DecorationImage(
                        image: NetworkImage(url),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ─── Minimal Team Card ───────────────────────────────────────────────────────

class _MinimalTeamCard extends StatelessWidget {
  final String teamName;
  final String role;
  final String status;

  const _MinimalTeamCard({
    required this.teamName,
    required this.role,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                teamName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: status.toLowerCase() == 'on-site' 
                      ? Colors.greenAccent 
                      : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            role,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Imports ──────────────────────────────────────────────────────────

