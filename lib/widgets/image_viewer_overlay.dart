import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:disaster360/colors.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  FULL-SCREEN IMAGE VIEWER OVERLAY (FIXED: full width & height)
// ══════════════════════════════════════════════════════════════════════════════

class ImageViewerOverlay extends StatefulWidget {
  final List<String> mediaUrls;
  final int initialIndex;
  final String reportId;

  const ImageViewerOverlay({
    super.key,
    required this.mediaUrls,
    required this.initialIndex,
    required this.reportId,
  });

  @override
  State<ImageViewerOverlay> createState() => _ImageViewerOverlayState();
}

class _ImageViewerOverlayState extends State<ImageViewerOverlay>
    with SingleTickerProviderStateMixin {
  late PageController _pageCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  int _currentIndex = 0;

  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _focusNode = FocusNode()..requestFocus();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _close() {
    _fadeCtrl.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              if (_currentIndex > 0) {
                _pageCtrl.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              if (_currentIndex < widget.mediaUrls.length - 1) {
                _pageCtrl.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              _close();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            // Blurred + darkened background
            GestureDetector(
              onTap: _close,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: Colors.black.withOpacity(0.88)),
              ),
            ),

            // Full-screen swipeable images – now edge‑to‑edge
            PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.mediaUrls.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) {
                return Container(
                  color: AppColors.bgDark,
                  child: Center(
                    child: Image.network(
                      widget.mediaUrls[i],
                      fit: BoxFit.contain,
                      errorBuilder:
                          (context, error, stackTrace) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white.withOpacity(0.2),
                                size: 72,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Error loading image',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.45),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                    ),
                  ),
                );
              },
            ),

            // Next/Prev Arrows (Desktop navigation)
            if (widget.mediaUrls.length > 1) ...[
              if (_currentIndex > 0)
                Positioned(
                  left: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        _pageCtrl.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
              if (_currentIndex < widget.mediaUrls.length - 1)
                Positioned(
                  right: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
            ],

            // Top bar: report ID (left), counter (center), close button (right)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '#${widget.reportId}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'Photo ${_currentIndex + 1} of ${widget.mediaUrls.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _close,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dot indicators at bottom
            if (widget.mediaUrls.length > 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.mediaUrls.length, (i) {
                    final active = i == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? AppColors.orange : Colors.white30,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
