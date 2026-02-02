import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

import 'login_screen.dart';

class AddResidentScreen extends StatefulWidget {
  final String adminId;
  final VoidCallback? onBack;
  const AddResidentScreen({super.key, required this.adminId, this.onBack});

  @override
  State<AddResidentScreen> createState() => _AddResidentScreenState();
}

class _AddResidentScreenState extends State<AddResidentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isSaving = false;

  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10;
  }

  void _showDialog(String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  bool get _canSubmit {
    return !isSaving &&
        fullNameController.text.trim().isNotEmpty &&
        _isValidEmail(emailController.text.trim()) &&
        _isValidPhone(phoneController.text.trim());
  }

  @override
  void initState() {
    super.initState();
    _ensureAdminAccess();
    fullNameController.addListener(_refreshFormState);
    phoneController.addListener(_refreshFormState);
    emailController.addListener(_refreshFormState);
  }

  Future<void> _ensureAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _redirectToLogin();
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = userDoc.data()?['role'];
      if (role != 'admin') {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Access Denied'),
            content: const Text(
              'This account is not authorized to invite residents.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        _redirectToLogin();
      }
    } catch (_) {
      _redirectToLogin();
    }
  }

  void _redirectToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void _refreshFormState() {
    if (mounted) setState(() {});
  }

  /* ======================
     SAVE RESIDENT (INVITE ONLY)
     YES: With strict role separation + invitation-only signup,
     permission-denied errors from mixed roles are eliminated.
  ====================== */
  Future<void> _saveResident() async {
    if (!_formKey.currentState!.validate()) {
      _showDialog(
        'Missing Details',
        'Please fill all required fields.',
        isError: true,
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final email = emailController.text.trim().toLowerCase();
      final tempPassword =
          'Tmp@${DateTime.now().millisecondsSinceEpoch % 1000000}';

      String? authUid;
      FirebaseApp? secondaryApp;
      try {
        // Create auth user in a secondary app so admin stays signed in
        secondaryApp = await Firebase.initializeApp(
          name: 'invite-${DateTime.now().microsecondsSinceEpoch}',
          options: DefaultFirebaseOptions.currentPlatform,
        );
        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
        final cred = await secondaryAuth.createUserWithEmailAndPassword(
          email: email,
          password: tempPassword,
        );
        authUid = cred.user?.uid;
        await cred.user?.sendEmailVerification();
        await secondaryAuth.sendPasswordResetEmail(email: email);
        await secondaryAuth.signOut();
      } on FirebaseAuthException catch (e) {
        debugPrint('INVITE_AUTH_ERROR: ${e.code} ${e.message}');
        if (e.code == 'email-already-in-use') {
          _showDialog(
            'Account Exists',
            'This email is already registered. Ask the resident to reset password from the login screen.',
            isError: true,
          );
          return;
        }
        rethrow;
      } finally {
        if (secondaryApp != null) {
          await secondaryApp.delete();
        }
      }

      if (authUid == null) {
        _showDialog(
          'Invitation Failed',
          'Unable to create authentication record for this resident.',
          isError: true,
        );
        return;
      }

      // Store resident document linked to auth uid
      await FirebaseFirestore.instance.collection('residents').add({
        'name': fullNameController.text.trim(),
        'fullName': fullNameController.text.trim(),
        'email': email,
        'phone': phoneController.text.trim(),
        'role': 'resident',
        'authUid': authUid,
        'isEmailVerified': false,
        'status': 'invited',
        'hostelId': null,
        'floorId': null,
        'roomId': null,
        'bedId': null,
        'isAllocated': false,
        'uid': null, // backward compatibility
        'adminId': widget.adminId,
        'createdByAdminId': widget.adminId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Invitation Sent'),
          content: const Text(
            'Verification email sent. The resident must verify and set a password before first login.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (e) {
      debugPrint('INVITE_RESIDENT_ERROR: ${e.code} ${e.message}');
      _showDialog(
        'Invitation Failed',
        e.message ?? 'Unable to invite resident.',
        isError: true,
      );
    } catch (e) {
      debugPrint('INVITE_RESIDENT_ERROR: $e');
      _showDialog('Invitation Failed', e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  InputDecoration _input(BuildContext context, String hint) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: theme.textTheme.bodySmall,
      filled: true,
      fillColor: theme.cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
      ),
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Color> headerGradient,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: headerGradient),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: headerGradient.last),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => widget.onBack != null
                        ? widget.onBack!()
                        : Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.arrow_back),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x334F46E5),
                          blurRadius: 10,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_add, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Resident',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1B4B),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Dashboard → Residents → Add Resident',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _sectionCard(
                        context: context,
                        title: 'Personal Details',
                        icon: Icons.person,
                        headerGradient: const [
                          Color(0xFFEFF6FF),
                          Color(0xFFEDE9FE),
                        ],
                        child: Column(
                          children: [
                            _fieldLabel('Full Name *'),
                            TextFormField(
                              controller: fullNameController,
                              decoration: _input(context, 'Enter full name'),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel('Phone Number *', icon: Icons.phone),
                            TextFormField(
                              controller: phoneController,
                              decoration: _input(context, '+91 98765 43210'),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                return _isValidPhone(v)
                                    ? null
                                    : 'Enter a valid 10-digit phone number';
                              },
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel('Email Address *', icon: Icons.mail),
                            TextFormField(
                              controller: emailController,
                              decoration: _input(
                                context,
                                'resident@example.com',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                return _isValidEmail(v)
                                    ? null
                                    : 'Enter a valid email';
                              },
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This action invites the resident. They must sign up using the same email to activate their account.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              label: const Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _canSubmit ? _saveResident : null,
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(
                                isSaving ? 'Sending...' : 'Send Invite',
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                backgroundColor: const Color(0xFF4F46E5),
                                disabledBackgroundColor: const Color(
                                  0xFF9CA3AF,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }
}
