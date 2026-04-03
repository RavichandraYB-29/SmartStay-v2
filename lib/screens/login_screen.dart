import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/custom_textfield.dart';
import '../widgets/forgot_password_dialog.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_text_styles.dart';
import '../utils/admin_design_system.dart';

import 'admin_dashboard.dart';
import 'resident_dashboard.dart';
import 'set_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoginTab = true;
  bool isLoading = false;
  bool rememberMe = true;

  /// UI role selector (UI ONLY, not security)
  String selectedRole = 'resident';

  final loginEmailController = TextEditingController();
  final loginPasswordController = TextEditingController();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loginEmailController.addListener(_refreshFormState);
    loginPasswordController.addListener(_refreshFormState);
    nameController.addListener(_refreshFormState);
    emailController.addListener(_refreshFormState);
    phoneController.addListener(_refreshFormState);
    passwordController.addListener(_refreshFormState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _attemptAutoLogin());
  }

  @override
  void dispose() {
    loginEmailController.dispose();
    loginPasswordController.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10;
  }

  bool _isStrongPassword(String password) {
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    return password.length >= 8 && hasUpper && hasLower && hasDigit;
  }

  Future<bool> _sendVerificationEmail(User user) async {
    try {
      debugPrint('VERIFY_EMAIL: start uid=${user.uid}');
      await user.sendEmailVerification();
      debugPrint('VERIFY_EMAIL: success uid=${user.uid}');
      if (mounted) {
        _showAuthDialog(
          title: 'Verification Email Sent',
          message: 'Please check your inbox and spam folder.',
        );
      }
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'VERIFY_EMAIL: failed uid=${user.uid} code=${e.code} message=${e.message}',
      );
      _showAuthDialog(
        title: 'Verification Failed',
        message: e.message ?? 'Unable to send verification email.',
        isError: true,
      );
      return false;
    } catch (e) {
      debugPrint('VERIFY_EMAIL: failed uid=${user.uid} error=$e');
      _showAuthDialog(
        title: 'Verification Failed',
        message: 'Unable to send verification email. Please try again.',
        isError: true,
      );
      return false;
    }
  }

  bool get _canLogin {
    return _isValidEmail(loginEmailController.text.trim()) &&
        loginPasswordController.text.trim().isNotEmpty;
  }

  bool get _canRegister {
    return nameController.text.trim().isNotEmpty &&
        _isValidEmail(emailController.text.trim()) &&
        _isValidPhone(phoneController.text.trim()) &&
        _isStrongPassword(passwordController.text.trim());
  }

  void _refreshFormState() {
    if (mounted) setState(() {});
  }

  Future<void> _attemptAutoLogin() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => isLoading = true);

    try {
      if (!currentUser.emailVerified) {
        final sent = await _sendVerificationEmail(currentUser);
        if (!sent) return;
        // Do not sign out before verification request completes.
        await Future.delayed(const Duration(milliseconds: 800));
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _showAuthDialog(
          title: 'Email Verification Required',
          message:
              'Please verify your email before logging in. A link was sent.',
          isError: true,
        );
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        return;
      }

      final role = userDoc['role'];
      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else {
        final residentSnap = await FirebaseFirestore.instance
            .collection('residents')
            .where('uid', isEqualTo: currentUser.uid)
            .limit(1)
            .get();
        final residentDoc = residentSnap.docs.isNotEmpty
            ? residentSnap.docs.first
            : await FirebaseFirestore.instance
                  .collection('residents')
                  .doc('_missing')
                  .get();

        if (!residentDoc.exists) {
          await FirebaseAuth.instance.signOut();
          _showAuthDialog(
            title: 'Resident Not Found',
            message: 'Your resident profile is missing. Contact admin.',
            isError: true,
          );
          return;
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ResidentDashboard()),
        );
      }
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _showAuthDialog(
        title: 'Login Failed',
        message: 'Unable to restore session. Please login again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /* ====================== DIALOG ====================== */

  void _showAuthDialog({
    required String title,
    required String message,
    bool isError = false,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.red : const Color(0xFF6C3BFF),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(title, style: AppTextStyles.h3),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ====================== REGISTER ====================== */

  Future<void> registerUser() async {
    if (selectedRole == 'resident') {
      _showAuthDialog(
        title: 'Residents Cannot Self‑Register',
        message:
            'Residents must be invited by an admin. Please log in with your invited email after verification.',
        isError: true,
      );
      return;
    }

    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        phoneController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _showAuthDialog(
        title: 'Missing Details',
        message: 'Please fill in all fields.',
        isError: true,
      );
      return;
    }

    if (!_isValidEmail(emailController.text.trim())) {
      _showAuthDialog(
        title: 'Invalid Email',
        message: 'Please enter a valid email address.',
        isError: true,
      );
      return;
    }

    if (!_isValidPhone(phoneController.text.trim())) {
      _showAuthDialog(
        title: 'Invalid Phone',
        message: 'Please enter a valid 10-digit phone number.',
        isError: true,
      );
      return;
    }

    if (!_isStrongPassword(passwordController.text.trim())) {
      _showAuthDialog(
        title: 'Weak Password',
        message:
            'Password must be at least 8 characters with upper, lower, and a number.',
        isError: true,
      );
      return;
    }

    setState(() => isLoading = true);

    User? createdUser;

    try {
      /// 🔐 ADMIN REGISTRATION
      {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        createdUser = cred.user;

        final currentUser = FirebaseAuth.instance.currentUser ?? cred.user;
        if (currentUser != null && !currentUser.emailVerified) {
          final sent = await _sendVerificationEmail(currentUser);
          if (!sent) {
            await currentUser.delete();
            return;
          }
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
              'name': nameController.text.trim(),
              'email': emailController.text.trim(),
              'phone': phoneController.text.trim(),
              'role': 'admin',
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      _showAuthDialog(
        title: 'Success',
        message: 'Account created. Please verify your email before logging in.',
      );

      // Do not sign out before verification request completes.
      await Future.delayed(const Duration(milliseconds: 800));
      await FirebaseAuth.instance.signOut();
      setState(() => isLoginTab = true);
    } on FirebaseAuthException catch (e) {
      _showAuthDialog(
        title: 'Registration Failed',
        message: e.message ?? 'Registration error',
        isError: true,
      );
    } on FirebaseException catch (e) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }
      _showAuthDialog(
        title: 'Registration Failed',
        message: e.message ?? 'Registration error',
        isError: true,
      );
    } catch (e) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }
      _showAuthDialog(
        title: 'Registration Failed',
        message: 'Unable to complete registration. Please try again.',
        isError: true,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /* ====================== LOGIN ====================== */

  Future<void> loginUser() async {
    if (loginEmailController.text.isEmpty ||
        loginPasswordController.text.isEmpty) {
      _showAuthDialog(
        title: 'Missing Details',
        message: 'Please enter email and password.',
        isError: true,
      );
      return;
    }

    if (!_isValidEmail(loginEmailController.text.trim())) {
      _showAuthDialog(
        title: 'Invalid Email',
        message: 'Please enter a valid email address.',
        isError: true,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(
          rememberMe ? Persistence.LOCAL : Persistence.SESSION,
        );
      }

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: loginEmailController.text.trim().toLowerCase(),
        password: loginPasswordController.text.trim(),
      );

      if (!cred.user!.emailVerified) {
        final sent = await _sendVerificationEmail(cred.user!);
        if (sent) {
          // Do not sign out before verification request completes.
          await Future.delayed(const Duration(milliseconds: 800));
        }
        await FirebaseAuth.instance.signOut();
        _showAuthDialog(
          title: 'Email Verification Required',
          message:
              'Please verify your email first. We just sent a verification link.',
          isError: true,
        );
        return;
      }

      // Admin flow (uses users collection)
      if (selectedRole == 'admin') {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .get();

        if (!userDoc.exists || userDoc['role'] != 'admin') {
          await FirebaseAuth.instance.signOut();
          _showAuthDialog(
            title: 'Access Denied',
            message: 'This account is not authorized to access this portal.',
            isError: true,
          );
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else {
        // Resident flow (uses residents collection with authUid)
        final residentSnap = await FirebaseFirestore.instance
            .collection('residents')
            .where('authUid', isEqualTo: cred.user!.uid)
            .limit(1)
            .get();

        if (residentSnap.docs.isEmpty) {
          await FirebaseAuth.instance.signOut();
          _showAuthDialog(
            title: 'Resident Not Found',
            message: 'Your resident profile is missing. Contact admin.',
            isError: true,
          );
          return;
        }

        final residentRef = residentSnap.docs.first.reference;
        final residentData = residentSnap.docs.first.data();

        if (residentData['role'] != null &&
            residentData['role'].toString() != 'resident') {
          await FirebaseAuth.instance.signOut();
          _showAuthDialog(
            title: 'Access Denied',
            message: 'This account is not authorized to access this portal.',
            isError: true,
          );
          return;
        }

        if (residentData['status'] == 'invited') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SetPasswordScreen(
                residentId: residentRef.id,
                authUid: cred.user!.uid,
                email: cred.user!.email ?? '',
              ),
            ),
          );
          return;
        }

        if (residentData['status'] != 'active') {
          await FirebaseAuth.instance.signOut();
          _showAuthDialog(
            title: 'Access Denied',
            message: 'Your account is not active yet. Contact admin.',
            isError: true,
          );
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ResidentDashboard()),
        );
      }
    } on FirebaseAuthException catch (e) {
      final code = e.code.toLowerCase();
      String message = e.message ?? 'Authentication error';

      if (code == 'user-not-found' || code == 'invalid-credential') {
        message =
            'No account found for this email. If you were invited, please sign up first using the same email.';
      } else if (code == 'wrong-password') {
        message = 'Incorrect password. Please try again.';
      } else if (code == 'user-disabled') {
        message = 'This account is disabled. Contact the admin.';
      }

      _showAuthDialog(title: 'Login Failed', message: message, isError: true);
    } catch (e) {
      _showAuthDialog(
        title: 'Login Failed',
        message: 'Unable to login. Please try again.',
        isError: true,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /* ====================== GOOGLE SIGN-IN ====================== */

  Future<void> signInWithGoogle() async {
    _showAuthDialog(
      title: 'Disabled',
      message: 'Google Sign-In is currently disabled.',
      isError: true,
    );
  }

  /* ====================== UI ====================== */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _mainUI(),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mainUI() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.scaffold(context),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [_header(), const SizedBox(height: 24), _authCard()],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: const [
        Icon(Icons.apartment, size: 60, color: Color(0xFF6C3BFF)),
        SizedBox(height: 12),
        Text('SmartStay', style: AppTextStyles.h1),
      ],
    );
  }

  Widget _authCard() {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AdminColors.border(context)),
        boxShadow: AdminShadows.card,
      ),
      child: Column(
        children: [
          _tabs(),
          const SizedBox(height: 20),
          _roleSelector(),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isLoginTab ? _loginForm() : _registerForm(),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Row(
      children: [_tabItem('Sign In', true), _tabItem('Sign Up', false)],
    );
  }

  Widget _tabItem(String text, bool loginTab) {
    final active = isLoginTab == loginTab;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isLoginTab = loginTab),
        child: Column(
          children: [
            Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: active 
                    ? const Color(0xFF6C3BFF) 
                    : (isDark ? Colors.grey.shade500 : Colors.grey),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 3,
              width: active ? 40 : 0,
              decoration: BoxDecoration(
                color: const Color(0xFF6C3BFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleSelector() {
    return Row(
      children: [
        _roleButton('resident', 'Resident', Icons.person),
        const SizedBox(width: 12),
        _roleButton('admin', 'Admin', Icons.admin_panel_settings),
      ],
    );
  }

  Widget _roleButton(String role, String label, IconData icon) {
    final selected = selectedRole == role;
    final color = role == 'resident'
        ? const Color(0xFF22B8A7)
        : const Color(0xFF6C3BFF);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected 
                ? color.withOpacity(0.12) 
                : AdminColors.card(context),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected 
                  ? color 
                  : (isDark ? const Color(0xFF2E3347) : Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon, 
                size: 18, 
                color: selected 
                    ? color 
                    : (isDark ? Colors.grey.shade400 : Colors.grey),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected 
                      ? color 
                      : (isDark ? Colors.grey.shade400 : Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loginForm() {
    return Column(
      children: [
        CustomTextField(
          controller: loginEmailController,
          label: 'Email',
          hintText: 'your.email@example.com',
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: loginPasswordController,
          label: 'Password',
          isPassword: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: rememberMe,
              onChanged: (value) => setState(() => rememberMe = value ?? true),
            ),
            Text('Remember me', style: AppTextStyles.bodySmall),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const ForgotPasswordDialog(),
            ),
            child: Text(
              'Forgot password?', 
              style: AppTextStyles.bodySmall.copyWith(
                color: AdminColors.primaryLight,
              ),
            ),
          ),
        ),
        GradientButton(
          text: 'Sign In',
          isLoading: isLoading,
          onPressed: isLoading ? null : loginUser,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: signInWithGoogle,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AdminColors.border(context)),
            foregroundColor: AdminColors.text(context),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _googleLogoIcon(),
              const SizedBox(width: 8),
              const Text('Continue with Google'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _registerForm() {
    return Column(
      children: [
        CustomTextField(controller: nameController, label: 'Full Name'),
        const SizedBox(height: 12),
        CustomTextField(controller: emailController, label: 'Email'),
        const SizedBox(height: 12),
        CustomTextField(controller: phoneController, label: 'Phone Number'),
        const SizedBox(height: 12),
        CustomTextField(
          controller: passwordController,
          label: 'Password',
          isPassword: true,
        ),
        const SizedBox(height: 20),
        GradientButton(
          text: 'Create Account',
          isLoading: isLoading,
          onPressed: _canRegister ? registerUser : null,
        ),
      ],
    );
  }

  Widget _googleLogoIcon() {
    const colors = [
      Color(0xFF4285F4),
      Color(0xFFDB4437),
      Color(0xFFF4B400),
      Color(0xFF0F9D58),
      Color(0xFF4285F4),
    ];

    return SizedBox(
      width: 18,
      height: 18,
      child: ShaderMask(
        shaderCallback: (rect) =>
            const SweepGradient(colors: colors).createShader(rect),
        child: const Text(
          'G',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
