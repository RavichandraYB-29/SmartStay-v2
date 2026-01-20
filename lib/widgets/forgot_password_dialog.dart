import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'custom_textfield.dart';
import 'gradient_button.dart';
import '../theme/app_text_styles.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final emailController = TextEditingController();
  bool isLoading = false;

  // ================= UTIL =================

  void _showMessage(String msg, {bool success = false}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: success ? cs.primary : Colors.black87,
      ),
    );
  }

  // ================= LOGIC =================

  Future<void> sendResetLink() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Please enter your email');
      return;
    }

    if (!email.contains('@')) {
      _showMessage('Enter a valid email address');
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      Navigator.pop(context);
      _showMessage('Password reset link sent to your email', success: true);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showMessage('No account found with this email');
      } else if (e.code == 'invalid-email') {
        _showMessage('Invalid email address');
      } else {
        _showMessage('Unable to send reset link. Try again later');
      }
    } catch (_) {
      _showMessage('Something went wrong. Please try again');
    }

    if (mounted) setState(() => isLoading = false);
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.dialogBackgroundColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reset Password',
                style: AppTextStyles.h2.copyWith(
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your registered email address',
                style: AppTextStyles.bodySmall.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 20),

              CustomTextField(
                controller: emailController,
                label: 'Email',
                hintText: 'your.email@example.com',
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 140,
                    child: GradientButton(
                      text: 'Send Link',
                      isLoading: isLoading,
                      onPressed: isLoading ? null : sendResetLink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
