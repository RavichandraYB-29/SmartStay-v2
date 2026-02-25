import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import 'login_screen.dart';
import '../utils/admin_design_system.dart';
import '../widgets/admin_widgets.dart';

class AddResidentScreen extends StatefulWidget {
  final String adminId;
  final VoidCallback? onBack;
  const AddResidentScreen({super.key, required this.adminId, this.onBack});

  @override
  State<AddResidentScreen> createState() => _AddResidentScreenState();
}

class _AddResidentScreenState extends State<AddResidentScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0; // 0 = Personal Info, 1 = Review & Invite
  bool isSaving = false;

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _isValidEmail(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
  bool _isValidPhone(String p) => p.replaceAll(RegExp(r'\D'), '').length == 10;

  @override
  void initState() {
    super.initState();
    _ensureAdminAccess();
    for (final c in [_fullNameCtrl, _phoneCtrl, _emailCtrl]) {
      c.addListener(() { if (mounted) setState(() {}); });
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _redirectToLogin(); return; }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.data()?['role'] != 'admin') {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        await showDialog(context: context, builder: (_) => AlertDialog(
          title: const Text('Access Denied'),
          content: const Text('Not authorized to invite residents.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ));
        _redirectToLogin();
      }
    } catch (_) { _redirectToLogin(); }
  }

  void _redirectToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  bool get _step0Valid =>
      _fullNameCtrl.text.trim().isNotEmpty &&
      _isValidEmail(_emailCtrl.text.trim()) &&
      _isValidPhone(_phoneCtrl.text.trim());

  Future<void> _sendInvite() async {
    setState(() => isSaving = true);
    try {
      final email = _emailCtrl.text.trim().toLowerCase();
      final tempPassword = 'Tmp@${DateTime.now().millisecondsSinceEpoch % 1000000}';
      String? authUid;
      FirebaseApp? secondaryApp;
      try {
        secondaryApp = await Firebase.initializeApp(
          name: 'invite-${DateTime.now().microsecondsSinceEpoch}',
          options: DefaultFirebaseOptions.currentPlatform,
        );
        final auth = FirebaseAuth.instanceFor(app: secondaryApp!);
        final cred = await auth.createUserWithEmailAndPassword(email: email, password: tempPassword);
        authUid = cred.user?.uid;
        await cred.user?.sendEmailVerification();
        await auth.sendPasswordResetEmail(email: email);
        await auth.signOut();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          if (mounted) await showDialog(context: context, builder: (_) => AlertDialog(
            title: const Text('Account Exists'),
            content: const Text('This email is already registered. Ask the resident to reset their password.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ));
          return;
        }
        rethrow;
      } finally {
        await secondaryApp?.delete();
      }

      if (authUid == null) return;

      await FirebaseFirestore.instance.collection('residents').add({
        'name': _fullNameCtrl.text.trim(),
        'fullName': _fullNameCtrl.text.trim(),
        'email': email,
        'phone': _phoneCtrl.text.trim(),
        'role': 'resident',
        'authUid': authUid,
        'isEmailVerified': false,
        'status': 'invited',
        'hostelId': null, 'pgId': null, 'floorId': null, 'roomId': null, 'bedId': null,
        'isAllocated': false,
        'uid': null,
        'adminId': widget.adminId,
        'createdByAdminId': widget.adminId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      await showAdminSuccessDialog(
        context,
        title: 'Invitation Sent!',
        message: 'A verification email was sent to $email. The resident must verify and set a password before logging in.',
      );
    } on FirebaseException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Invitation failed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : AdminColors.scaffoldLight,
      body: SafeArea(child: Column(children: [
        AdminPageHeader(
          title: 'Add Resident',
          subtitle: 'Dashboard → Residents → Add Resident',
          icon: Icons.person_add_rounded,
          iconGradient: AdminGradients.indigo,
          onBack: () => widget.onBack != null ? widget.onBack!() : Navigator.pop(context),
        ),
        // Step indicator
        _StepIndicator(currentStep: _step),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Form(key: _formKey, child: _step == 0 ? _step0() : _step1()),
        )),
      ])),
    );
  }

  Widget _step0() {
    return Column(children: [
      AdminSectionCard(
        title: 'Personal Information', icon: Icons.person_rounded,
        headerGradient: AdminGradients.headerLight, iconColor: AdminColors.primary,
        child: Column(children: [
          AdminTextField(label: 'Full Name *', hint: 'Enter full name', controller: _fullNameCtrl,
            prefixIcon: Icons.badge_rounded,
            validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null),
          const SizedBox(height: 16),
          AdminTextField(label: 'Phone Number *', hint: '+91 98765 43210', controller: _phoneCtrl,
            prefixIcon: Icons.phone_rounded, keyboardType: TextInputType.phone,
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : _isValidPhone(v) ? null : 'Enter a valid 10-digit number'),
          const SizedBox(height: 16),
          AdminTextField(label: 'Email Address *', hint: 'resident@example.com', controller: _emailCtrl,
            prefixIcon: Icons.email_rounded, keyboardType: TextInputType.emailAddress,
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : _isValidEmail(v) ? null : 'Enter a valid email'),
        ]),
      ),
      const SizedBox(height: 16),
      const AdminInfoBanner(
        message: 'An invitation email will be sent. The resident must verify and set a password before first login.',
        icon: Icons.info_outline_rounded,
      ),
      const SizedBox(height: 24),
      AdminPrimaryButton(
        label: 'Next: Review & Invite',
        icon: Icons.arrow_forward_rounded,
        onPressed: _step0Valid ? () {
          if (_formKey.currentState!.validate()) setState(() => _step = 1);
        } : null,
      ),
    ]);
  }

  Widget _step1() {
    return Column(children: [
      AdminSectionCard(
        title: 'Review Details', icon: Icons.preview_rounded,
        headerGradient: AdminGradients.headerPurple, iconColor: AdminColors.primary,
        child: Column(children: [
          _ReviewRow(label: 'Full Name', value: _fullNameCtrl.text.trim()),
          const Divider(height: 24),
          _ReviewRow(label: 'Phone', value: _phoneCtrl.text.trim()),
          const Divider(height: 24),
          _ReviewRow(label: 'Email', value: _emailCtrl.text.trim()),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFEDE9FE), Color(0xFFF3E8FF)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC4B5FD)),
        ),
        child: Row(children: [
          const Icon(Icons.mark_email_read_rounded, color: AdminColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Invitation Flow', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, fontFamily: 'Inter', color: AdminColors.primary)),
            const SizedBox(height: 4),
            Text(
              '1. Account created for ${_emailCtrl.text.trim()}\n2. Verification email sent\n3. Password reset link sent\n4. Resident activates via email',
              style: const TextStyle(fontSize: 12, color: Color(0xFF5B21B6), fontFamily: 'Inter', height: 1.6),
            ),
          ])),
        ]),
      ),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: isSaving ? null : () => setState(() => _step = 0),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Go Back'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: const BorderSide(color: AdminColors.cardBorder),
          ),
        )),
        const SizedBox(width: 16),
        Expanded(child: AdminPrimaryButton(
          label: isSaving ? 'Sending...' : 'Send Invite',
          icon: Icons.send_rounded,
          isLoading: isSaving,
          onPressed: isSaving ? null : _sendInvite,
        )),
      ]),
    ]);
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: isDark ? const Color(0xFF1A1D27) : Colors.white,
      child: Row(children: [
        _StepDot(label: 'Personal Info', number: 1, isActive: currentStep == 0, isDone: currentStep > 0),
        Expanded(child: Container(height: 2, color: currentStep >= 1 ? AdminColors.primary : const Color(0xFFE5E7EB))),
        _StepDot(label: 'Review & Invite', number: 2, isActive: currentStep == 1, isDone: false),
      ]),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final int number;
  final bool isActive, isDone;
  const _StepDot({required this.label, required this.number, required this.isActive, required this.isDone});

  @override
  Widget build(BuildContext context) {
    final color = isActive || isDone ? AdminColors.primary : const Color(0xFFE5E7EB);
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 30, height: 30,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(child: isDone
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : Text('$number', style: TextStyle(color: isActive ? Colors.white : AdminColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Inter'))),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, fontFamily: 'Inter', fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? AdminColors.primary : AdminColors.textMuted)),
    ]);
  }
}

class _ReviewRow extends StatelessWidget {
  final String label, value;
  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13, color: AdminColors.textSecondary, fontFamily: 'Inter'))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
    ]);
  }
}
