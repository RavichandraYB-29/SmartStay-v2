import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_text_styles.dart';
import '../utils/admin_design_system.dart';
import 'login_screen.dart';

class SetPasswordScreen extends StatefulWidget {
  final String residentId;
  final String authUid;
  final String email;

  const SetPasswordScreen({
    super.key,
    required this.residentId,
    required this.authUid,
    required this.email,
  });

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;

  bool _isStrongPassword(String password) {
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    return password.length >= 8 && hasUpper && hasLower && hasDigit;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _completeActivation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != widget.authUid) {
        await _showDialog(
          'Session Expired',
          'Please log in again to set your password.',
          isError: true,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      if (!user.emailVerified) {
        _showDialog(
          'Email Not Verified',
          'Please verify your email first, then try again.',
          isError: true,
        );
        return;
      }

      await user.updatePassword(_passwordController.text.trim());

      final residentRef = FirebaseFirestore.instance
          .collection('residents')
          .doc(widget.residentId);
      await residentRef.update({
        'isEmailVerified': true,
        'status': 'active',
        'authUid': widget.authUid,
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.authUid)
          .set({
            'email': widget.email,
            'role': 'resident',
            'residentId': widget.residentId,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      await _showDialog(
        'Account Activated',
        'Your account is now active. Please log in with your new password.',
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      _showDialog(
        'Password Update Failed',
        e.message ?? 'Try again.',
        isError: true,
      );
    } catch (_) {
      _showDialog('Activation Failed', 'Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showDialog(
    String title,
    String message, {
    bool isError = false,
  }) async {
    await showDialog(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Password'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      ),
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AdminColors.card(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AdminShadows.card,
            border: Border.all(color: AdminColors.border(context)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Create Your Password', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                Text(
                  'Your email is verified. Set a password to activate your account.',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                  validator: (value) {
                    final text = value ?? '';
                    if (text.isEmpty) return 'Enter a password';
                    if (!_isStrongPassword(text)) {
                      return 'Use 8+ chars with upper, lower, and a number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                  validator: (value) {
                    if ((value ?? '').isEmpty) return 'Confirm your password';
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _completeActivation,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C3BFF), Color(0xFF8E6CFF)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Activate Account',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
