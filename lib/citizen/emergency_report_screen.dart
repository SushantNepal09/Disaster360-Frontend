import 'dart:async';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:disaster360/utils/sms_helper.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:disaster360/colors.dart';
import 'package:disaster360/services/session_service.dart';
import 'package:disaster360/services/api_service.dart';
import 'package:disaster360/services/gis_cache_service.dart';
import 'package:disaster360/services/supabase_storage_service.dart';
import 'package:disaster360/auth/auth_wrapper.dart';

class _SeverityMeta {
  final int level;
  final String label;
  final String description;
  final Color color;

  const _SeverityMeta({
    required this.level,
    required this.label,
    required this.description,
    required this.color,
  });
}

class EmergencyReportScreen extends StatefulWidget {
  const EmergencyReportScreen({super.key});

  @override
  State<EmergencyReportScreen> createState() => _EmergencyReportScreenState();
}

class _EmergencyReportScreenState extends State<EmergencyReportScreen> {
  bool _isLoadingGps = true;
  bool _isSubmitting = false;
  Position? _currentPosition;
  String _gpsStatus = "Acquiring GPS...";

  final _descriptionController = TextEditingController(); // Empty by default
  final List<String> _disasterTypes = [
    'Earthquake',
    'Flood',
    'Landslide',
    'Fire',
    'Other',
  ];
  String _selectedDisaster = 'Earthquake';

  int _severityLevel = 5; // Hardcoded to 5 (Critical)
  final List<String> _uploadedPhotos = []; // Simulated file paths

  static const List<_SeverityMeta> _severityLevels = [
    _SeverityMeta(
      level: 1,
      label: 'Low',
      description: 'Minor incident, no immediate danger to life or property.',
      color: Color(0xFF4CAF50),
    ),
    _SeverityMeta(
      level: 2,
      label: 'Moderate',
      description: 'Some risk present. Caution advised in the affected area.',
      color: Color(0xFF8BC34A),
    ),
    _SeverityMeta(
      level: 3,
      label: 'High',
      description: 'Significant danger. Evacuation or immediate action needed.',
      color: Color(0xFFFFB800),
    ),
    _SeverityMeta(
      level: 4,
      label: 'Severe',
      description: 'Major disaster. Multiple areas affected, lives at risk.',
      color: Color(0xFFFF6B2B),
    ),
    _SeverityMeta(
      level: 5,
      label: 'Extreme',
      description:
          'Catastrophic event. Maximum emergency response required immediately.',
      color: Color(0xFFFF3B3B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkSessionAndInitGps();
  }

  void _checkSessionAndInitGps() {
    final user = SessionService().currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      });
      return;
    }
    _fetchGps();
  }

  Future<void> _fetchGps() async {
    setState(() {
      _isLoadingGps = true;
      _gpsStatus = "Acquiring precise location...";
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services disabled.");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Location permissions denied.");
        }
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        throw Exception("Location permissions denied forever.");
      }

      Position? position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingGps = false;
          _gpsStatus = "GPS Locked Successfully";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsStatus = "Falling back to last known location...";
        });
      }
      try {
        Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (mounted) {
          setState(() {
            _currentPosition = lastKnown;
            _isLoadingGps = false;
            _gpsStatus =
                lastKnown != null
                    ? "Using cached location"
                    : "GPS failed completely";
          });
        }
      } catch (fallbackErr) {
        if (mounted) {
          setState(() {
            _isLoadingGps = false;
            _gpsStatus = "GPS failed completely";
          });
        }
      }
    }
  }

  void _simulatePhotoUpload() {
    _snack(
      'Camera/Gallery upload must be linked to backend. Currently simulated.',
    );
  }

  void _removePhoto(int index) {
    setState(() => _uploadedPhotos.removeAt(index));
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.bgSurface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitEmergencyReport() async {
    final user = SessionService().currentUser;
    if (user == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
      return;
    }

    if (_currentPosition == null) {
      _snack('Please wait for GPS lock or retry.');
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _snack('Please provide details about the emergency.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Offline SMS Fallback Check
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult.contains(ConnectivityResult.none) || connectivityResult.isEmpty;

      if (isOffline) {
        setState(() {
          _isSubmitting = false;
        });
        
        final userName = user.fullName ?? user.email ?? "Unknown User";
        final userId = user.id;
        final lat = _currentPosition?.latitude.toStringAsFixed(4) ?? "0.0";
        final lng = _currentPosition?.longitude.toStringAsFixed(4) ?? "0.0";
        
        final success = await SmsHelper.launchSmsFallback(
          title: 'EMERGENCY: $_selectedDisaster',
          description: _descriptionController.text.trim(),
          severity: "Severe",
          latitude: lat,
          longitude: lng,
          disasterType: _selectedDisaster,
          userName: userName,
          userId: userId,
        );

        if (success) {
          _snack('Opened SMS app for offline emergency reporting.');
        } else {
          _snack('Could not launch SMS app.');
        }
        return;
      }

      String severityStr = _severityLevels[_severityLevel - 1].label;

      List<String> adminAreas = ["Unknown", "Unknown", "Unknown"];
      try {
        adminAreas = await GisCacheService().identifyAdministrativeAreas(
          _currentPosition!.latitude, 
          _currentPosition!.longitude
        );
      } catch (e) {
        debugPrint("Failed to identify administrative areas: $e");
      }

      final payload = {
        'title': 'EMERGENCY: $_selectedDisaster',
        'disaster_type': _selectedDisaster,
        'description': _descriptionController.text.trim(),
        'severity': severityStr,
        'location': adminAreas,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'status': 'Pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final api = ApiService();
      final storageService = SupabaseStorageService();
      
      // Step 1: Upload images to Supabase
      List<File> filesToUpload = _uploadedPhotos.map((path) => File(path)).toList();
      List<String> uploadedUrls = await storageService.uploadImages(filesToUpload);

      final response = await api.post('/reports/', body: payload);
      final reportId = response['report_id'];
      final subId = response['submission_id'] ?? reportId;
      final merged = response.containsKey('merged') ? response['merged'] : false;

      // Step 3: Attach Media URLs to the report
      if (uploadedUrls.isNotEmpty) {
        if (merged) {
          await api.post(
            '/reports/submissions/$subId/media',
            body: {"media_urls": uploadedUrls, "file_type": "image"},
          );
        } else {
          await api.post(
            '/reports/$reportId/media',
            body: {"media_urls": uploadedUrls, "file_type": "image"},
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Emergency report submitted successfully.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _exitScreen(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _exitScreen(bool submitted) {
    if (submitted) {
      // Clean stack and go to Dashboard
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } else {
      // Cancelled
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        // App was launched cold into this screen; exit app normally 
        // by popping the only route or pushing AuthWrapper if preferred.
        // As per the plan, exiting the app is acceptable here.
        Navigator.pop(context); // Will exit the app
      }
    }
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  
  Widget _buildPhotoEvidence() {
    return Column(
      children: [
        if (_uploadedPhotos.isNotEmpty) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _uploadedPhotos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, i) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: Colors.white38,
                        size: 32,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _removePhoto(i),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Photo ${i + 1}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        if (_uploadedPhotos.length < 5)
          GestureDetector(
            onTap: _simulatePhotoUpload,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border,
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white38,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to upload photo/video',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_uploadedPhotos.length}/5 uploaded',
                    style: const TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService().currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: const Text(
          'QUICK EMERGENCY',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.danger,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => _exitScreen(false),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.15),
                border: Border.all(
                  color: AppColors.danger.withOpacity(0.5),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: AppColors.danger,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "HIGH PRIORITY",
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Reporting as: ${user.fullName ?? user.email}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // GPS Section
            _sectionLabel('GPS LOCATION (REQUIRED)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _isLoadingGps
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.info,
                        ),
                      )
                      : const Icon(
                        Icons.location_on,
                        color: AppColors.success,
                        size: 24,
                      ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _gpsStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (_currentPosition != null)
                          Text(
                            "${_currentPosition!.latitude.toStringAsFixed(5)}°N, ${_currentPosition!.longitude.toStringAsFixed(5)}°E",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.white70),
                    onPressed: _isLoadingGps ? null : _fetchGps,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _sectionLabel('DISASTER TYPE'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDisaster,
              dropdownColor: AppColors.bgSurface,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bgSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.orange,
                    width: 1.5,
                  ),
                ),
              ),
              items:
                  _disasterTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDisaster = val);
              },
            ),

            const SizedBox(height: 24),
            _sectionLabel('DETAILS (REQUIRED)'),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "E.g. Road is completely blocked by debris...",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: AppColors.bgSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.orange,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            _sectionLabel('PHOTO / VIDEO (OPTIONAL)'),
            const SizedBox(height: 8),
            _buildPhotoEvidence(),

            const SizedBox(height: 36),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed:
                    _isSubmitting || _currentPosition == null
                        ? null
                        : _submitEmergencyReport,
                child:
                    _isSubmitting
                        ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Text(
                              'SUBMIT EMERGENCY',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
