import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:disaster360/colors.dart';
import 'package:disaster360/providers/report_provider.dart';
import 'package:disaster360/citizen/citizen_report_card.dart';

class CitizenClosedReportsScreen extends StatelessWidget {
  const CitizenClosedReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final closedReports = context.watch<ReportProvider>().closedReports;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('Closed Reports', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: closedReports.isEmpty
          ? const Center(
              child: Text(
                'No closed reports yet.',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: closedReports.length,
              itemBuilder: (context, index) {
                final report = closedReports[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CitizenReportCard(
                    key: ValueKey(report.id.toString()),
                    report: report,
                    onUpvote: () => context.read<ReportProvider>().toggleReaction(report.id, 'LIKE'),
                    onDownvote: () => context.read<ReportProvider>().toggleReaction(report.id, 'DISLIKE'),
                  ),
                );
              },
            ),
    );
  }
}
