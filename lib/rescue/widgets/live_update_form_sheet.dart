import 'package:flutter/material.dart';
import 'package:disaster360/colors.dart';
import 'package:disaster360/services/rescue_service.dart';

class LiveUpdateFormSheet extends StatefulWidget {
  final int incidentId;

  const LiveUpdateFormSheet({super.key, required this.incidentId});

  @override
  State<LiveUpdateFormSheet> createState() => _LiveUpdateFormSheetState();
}

class _LiveUpdateFormSheetState extends State<LiveUpdateFormSheet> {
  final _messageController = TextEditingController();
  final RescueService _rescueService = RescueService();
  
  String _selectedCategory = 'Rescue Ongoing';
  String _selectedSeverity = 'Normal';
  bool _isLoading = false;

  final List<String> _categories = [
    'Arrival',
    'Rescue Ongoing',
    'Evacuation',
    'Medical',
    'Hazard',
    'Road Blocked',
    'Weather',
    'Resources Needed',
    'Fire Under Control',
    'General',
  ];

  final List<String> _severities = ['Normal', 'Important', 'Critical'];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _submitUpdate() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final payload = {
      "category": _selectedCategory,
      "severity": _selectedSeverity,
      "message": message,
      "visibility": "Public",
      // "media_url": null, // Media upload integration can be added here
      "device_time": DateTime.now().toIso8601String(),
    };

    final result = await _rescueService.postLiveUpdate(widget.incidentId, payload);
    
    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (result['success'] == true) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(result['message'] ?? 'Update Shared Successfully'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to share update.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Title
            const Text(
              "Send Live Situation Update",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Share a short field update that will immediately be visible to Administrators and Citizens following this disaster.",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // Message Input
            TextField(
              controller: _messageController,
              maxLength: 250,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Example:\nRescue team has reached the affected area.\nFlood water rising rapidly.",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: AppColors.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),
            
            // Category
            const Text(
              "Category",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  backgroundColor: AppColors.bgDark,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            
            // Severity
            const Text(
              "Severity Indicator",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: _severities.map((sev) {
                final isSelected = _selectedSeverity == sev;
                Color activeColor;
                if (sev == 'Critical') activeColor = AppColors.danger;
                else if (sev == 'Important') activeColor = AppColors.warning;
                else activeColor = AppColors.success;
                
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => setState(() => _selectedSeverity = sev),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor.withOpacity(0.15) : AppColors.bgDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? activeColor : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          sev,
                          style: TextStyle(
                            color: isSelected ? activeColor : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "POST LIVE UPDATE",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
