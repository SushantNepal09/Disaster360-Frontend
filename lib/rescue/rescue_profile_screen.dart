import 'package:provider/provider.dart';
import 'package:disaster360/providers/auth_provider.dart';
import 'package:disaster360/auth/change_password_screen.dart';
import 'package:disaster360/providers/rescue_provider.dart';
import 'package:disaster360/utils/secure_logout.dart';
import 'package:disaster360/colors.dart';
import 'package:flutter/material.dart';
import 'package:disaster360/rescue/rescue_tasks_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  RESCUE PROFILE SCREEN — Disaster360 Rescue Module
//
//  Data sources:
//    • AuthProvider.user  — registration data (name, email, phone, role)
//    • RescueProvider.profile — mission stats from /rescue/profile API
//
//  Sections (top → bottom):
//    1. Header: "My Profile" + Edit button
//    2. Avatar with online indicator
//    3. Name + role badge (Rescue Team)
//    4. Stats row: Completed · Total · Active
//    5. Details info card (email, phone from registration)
//    6. System Online toggle card
//    7. Duty Status card with animated indicator
//    8. Provide Feedback row
//    9. Go Off Duty + Sign Out buttons
// ═══════════════════════════════════════════════════════════════════════════════

class RescueProfileScreen extends StatefulWidget {
  const RescueProfileScreen({super.key});

  @override
  State<RescueProfileScreen> createState() => _RescueProfileScreenState();
}

class _RescueProfileScreenState extends State<RescueProfileScreen> {
  // ── System / duty state ────────────────────────────────────────────────────
  bool _isOnDuty = true;

  @override
  void initState() {
    super.initState();
    // Fetch rescue-specific stats from the backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RescueProvider>().fetchProfile();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'RT';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final rescue = context.watch<RescueProvider>();

    final user = auth.user;
    final profile = rescue.profile;

    final name = user?.fullName ?? 'Rescue Member';
    final email = user?.email ?? 'N/A';
    final phone = user?.phone ?? 'N/A';
    final role = user?.role ?? 'rescue';
    final specialization = user?.specialization ?? 'Not Specified';
    final initials = _getInitials(name);

    // Dynamic Stats from myAssignments
    final myAssignments = rescue.myAssignments;
    final completedOps = myAssignments.where((t) => t.status == TaskStatus.completed).length;
    final totalOps = myAssignments.length;
    final activeOps = myAssignments.where((t) => t.status == TaskStatus.pending || t.status == TaskStatus.active).length;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeader(context),
              const SizedBox(height: 28),
              _buildAvatar(initials),
              const SizedBox(height: 14),
              _buildNameAndBadge(name, role, specialization),
              const SizedBox(height: 20),
              _buildStatsRow(completedOps, totalOps, activeOps),
              const SizedBox(height: 20),
              _buildDetailsCard(email, phone, specialization),
              const SizedBox(height: 16),
              _buildChangePasswordButton(context),
              const SizedBox(height: 12),
              _buildSignOutButton(context),
              const SizedBox(height: 28),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
        _ProfileTextButton(
          label: 'Edit',
          color: AppColors.orange,
          onTap: () => _showEditDialog(context),
        ),
      ],
    );
  }

  // ── 2. Avatar ──────────────────────────────────────────────────────────────
  Widget _buildAvatar(String initials) {
    return Stack(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.success.withOpacity(0.4),
              width: 3,
            ),
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _isOnDuty ? AppColors.success : Colors.white38,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bgPrimary, width: 2.5),
            ),
            child: Icon(
              _isOnDuty ? Icons.shield_rounded : Icons.shield_outlined,
              color: Colors.white,
              size: 10,
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. Name + role badge ───────────────────────────────────────────────────
  Widget _buildNameAndBadge(String name, String role, String specialization) {
    return Column(
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 8),
        _roleBadge('Rescue Team', AppColors.success),
        const SizedBox(height: 6),
        _roleBadge(
          specialization,
          specialization == 'Not Specified' ? Colors.white38 : AppColors.orange,
        ),
      ],
    );
  }

  Widget _roleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── 4. Stats row ───────────────────────────────────────────────────────────
  Widget _buildStatsRow(int completed, int total, int active) {
    final statList = [
      _Stat('Missions\nCompleted', '$completed', AppColors.success),
      _Stat('Total\nMissions', '$total', AppColors.info),
      _Stat('Currently\nActive', '$active', AppColors.warning),
    ];

    return Row(
      children:
          statList.map((s) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      s.value,
                      style: TextStyle(
                        color: s.color,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  // ── 5. Details card (from registration) ───────────────────────────────────
  Widget _buildDetailsCard(String email, String phone, String specialization) {
    final rows = [
      _InfoRow(label: 'Email', value: email),
      _InfoRow(label: 'Phone', value: phone.isNotEmpty ? phone : 'N/A'),
      _InfoRow(
        label: 'Role',
        value: 'Rescue Team',
        valueColor: AppColors.success,
      ),
      _InfoRow(label: 'Department', value: specialization),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final row = rows[i];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Text(
                      row.label,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: row.valueColor ?? Colors.white,
                          fontSize: 13,
                          fontWeight:
                              row.valueColor != null
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < rows.length - 1)
                const Divider(height: 1, color: AppColors.border, indent: 16),
            ],
          );
        }),
      ),
    );
  }

  // ── 9a. Change Password button ─────────────────────────────────────────────
  Widget _buildChangePasswordButton(BuildContext context) {
    return _ProfileActionButton(
      label: 'Change Password',
      icon: Icons.lock_outline_rounded,
      color: Colors.white,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
        );
      },
    );
  }

  // ── 9b. Sign Out button ────────────────────────────────────────────────────
  Widget _buildSignOutButton(BuildContext context) {
    return _ProfileActionButton(
      label: 'Sign Out',
      icon: Icons.logout_rounded,
      color: AppColors.danger,
      onTap: () => _showSignOutDialog(context),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  DIALOGS
  // ════════════════════════════════════════════════════════════════════════════

  void _showEditDialog(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final nameCtrl = TextEditingController(text: user?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final deptCtrl = TextEditingController(text: user?.specialization ?? '');

    showDialog(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor: AppColors.bgSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  title: const Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  content: SizedBox(
                    width: 400,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _DialogField(
                            controller: nameCtrl,
                            label: 'Full Name',
                          ),
                          const SizedBox(height: 12),
                          _DialogField(controller: phoneCtrl, label: 'Phone'),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: deptCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Department Name',
                              labelStyle: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await context.read<AuthProvider>().updateProfile(
                            fullName: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            specialization: deptCtrl.text.trim().isEmpty ? null : deptCtrl.text.trim(),
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Profile updated successfully.',
                                ),
                                backgroundColor: AppColors.success.withOpacity(
                                  0.9,
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }


  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border),
            ),
            title: const Text(
              'Sign Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: const Text(
              'Are you sure you want to sign out of your rescue account?',
              style: TextStyle(color: Colors.white54, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
              ElevatedButton(
                onPressed: () => SecureLogout.performLogout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _showSnack(String msg, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: color.withOpacity(0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ACTION BUTTON with scale + hover animations
// ══════════════════════════════════════════════════════════════════════════════

class _ProfileActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ProfileActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ProfileActionButton> createState() => _ProfileActionButtonState();
}

class _ProfileActionButtonState extends State<_ProfileActionButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _tapCtrl;
  late Animation<double> _tapAnim;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _tapAnim = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _tapCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _tapCtrl.forward(),
        onTapUp: (_) {
          _tapCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _tapCtrl.reverse(),
        child: ScaleTransition(
          scale: _tapAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color:
                  _hovered
                      ? widget.color.withOpacity(0.22)
                      : widget.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.color.withOpacity(_hovered ? 0.65 : 0.4),
              ),
              boxShadow:
                  _hovered
                      ? [
                        BoxShadow(
                          color: widget.color.withOpacity(0.10),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                      : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: _hovered ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(widget.icon, color: widget.color, size: 18),
                ),
                const SizedBox(width: 8),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    color: widget.color,
                    fontSize: _hovered ? 15.2 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Menu tile with hover ───────────────────────────────────────────────────────
class _ProfileMenuTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ProfileMenuTile> createState() => _ProfileMenuTileState();
}

class _ProfileMenuTileState extends State<_ProfileMenuTile> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        color: _h ? Colors.white.withOpacity(0.03) : Colors.transparent,
        child: ListTile(
          onTap: widget.onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 2,
          ),
          leading: Icon(
            widget.icon,
            color: _h ? Colors.white70 : Colors.white60,
            size: 20,
          ),
          title: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            style: TextStyle(
              color: Colors.white,
              fontSize: _h ? 14.5 : 14,
              fontWeight: FontWeight.w500,
            ),
            child: Text(widget.label),
          ),
          trailing: AnimatedScale(
            scale: _h ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 140),
            child: Icon(
              Icons.chevron_right,
              color: _h ? Colors.white54 : Colors.white30,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hover text button (Edit) ───────────────────────────────────────────────────
class _ProfileTextButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ProfileTextButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ProfileTextButton> createState() => _ProfileTextButtonState();
}

class _ProfileTextButtonState extends State<_ProfileTextButton> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            color: _h ? widget.color.withOpacity(0.7) : widget.color,
            fontSize: _h ? 15.5 : 15,
            fontWeight: FontWeight.w600,
            decoration: _h ? TextDecoration.underline : TextDecoration.none,
            decorationColor: widget.color.withOpacity(0.5),
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

// ── Dialog text field ──────────────────────────────────────────────────────────
class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _DialogField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        filled: true,
        fillColor: AppColors.bgPrimary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ══════════════════════════════════════════════════════════════════════════════

class _Stat {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);
}

class _InfoRow {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.label, required this.value, this.valueColor});
}
