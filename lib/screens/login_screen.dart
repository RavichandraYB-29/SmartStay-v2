import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../widgets/custom_textfield.dart';
import '../widgets/forgot_password_dialog.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_text_styles.dart';

import 'admin_dashboard.dart';
import 'resident_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoginTab = true;
  bool isLoading = false;

  String selectedRole = 'resident';

  final loginEmailController = TextEditingController();
  final loginPasswordController = TextEditingController();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  void _clearLoginFields() {
    loginEmailController.clear();
    loginPasswordController.clear();
  }

  void _clearRegisterFields() {
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    passwordController.clear();
  }

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
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isError
                      ? Colors.red.withOpacity(0.1)
                      : const Color(0xFF6C3BFF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: isError ? Colors.red : const Color(0xFF6C3BFF),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: AppTextStyles.h3),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C3BFF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _ensureUserProfile(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'name': user.displayName ?? nameController.text.trim(),
        'email': user.email ?? loginEmailController.text.trim(),
        'phone': user.phoneNumber ?? phoneController.text.trim(),
        'role': selectedRole,
        'authProvider': user.providerData.isNotEmpty
            ? user.providerData.first.providerId
            : 'email',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return selectedRole;
    }

    final data = snap.data() ?? {};
    final role = data['role'];
    if (role is String && role.isNotEmpty) {
      return role;
    }

    await ref.update({'role': selectedRole});
    return selectedRole;
  }

  // ---------------- LOGIN ----------------
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

    setState(() => isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: loginEmailController.text.trim(),
        password: loginPasswordController.text.trim(),
      );

      final role = await _ensureUserProfile(cred.user!);

      _clearLoginFields();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => role == 'admin'
              ? const AdminDashboard()
              : const ResidentDashboard(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showAuthDialog(
        title: 'Login Failed',
        message: e.message ?? 'Authentication error',
        isError: true,
      );
    } catch (e) {
      _showAuthDialog(
        title: 'Login Failed',
        message: e.toString(),
        isError: true,
      );
    }

    setState(() => isLoading = false);
  }

  // ---------------- REGISTER ----------------
  Future<void> registerUser() async {
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

    setState(() => isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
            'name': nameController.text.trim(),
            'email': emailController.text.trim(),
            'phone': phoneController.text.trim(),
            'role': selectedRole,
            'authProvider': 'email',
            'createdAt': FieldValue.serverTimestamp(),
          });

      _clearRegisterFields();

      _showAuthDialog(
        title: 'Success',
        message: 'Account created successfully.',
      );

      setState(() => isLoginTab = true);
    } on FirebaseAuthException catch (e) {
      _showAuthDialog(
        title: 'Registration Failed',
        message: e.message ?? 'Registration error',
        isError: true,
      );
    } catch (e) {
      _showAuthDialog(
        title: 'Registration Failed',
        message: e.toString(),
        isError: true,
      );
    }

    setState(() => isLoading = false);
  }

  // ---------------- GOOGLE SIGN-IN ----------------
  Future<void> signInWithGoogle() async {
    setState(() => isLoading = true);

    try {
      UserCredential userCred;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        userCred = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          setState(() => isLoading = false);
          return;
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCred.user!;

      final role = await _ensureUserProfile(user);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => role == 'admin'
              ? const AdminDashboard()
              : const ResidentDashboard(),
        ),
      );
    } catch (e) {
      _showAuthDialog(
        title: 'Google Sign-In Failed',
        message: e.toString(),
        isError: true,
      );
    }

    setState(() => isLoading = false);
  }

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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF0FF), Colors.white],
        ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
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

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            isLoginTab = loginTab;
            loginTab ? _clearRegisterFields() : _clearLoginFields();
          });
        },
        child: Column(
          children: [
            Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: active ? const Color(0xFF6C3BFF) : Colors.grey,
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

    final activeColor = role == 'resident'
        ? const Color(0xFF22B8A7)
        : const Color(0xFF6C3BFF);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? activeColor.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? activeColor : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? activeColor : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? activeColor : Colors.grey,
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
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const ForgotPasswordDialog(),
            ),
            child: Text('Forgot password?', style: AppTextStyles.bodySmall),
          ),
        ),
        GradientButton(
          text: 'Sign In',
          isLoading: isLoading,
          onPressed: loginUser,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: signInWithGoogle,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/google.png', height: 20),
              const SizedBox(width: 12),
              Text(
                'Continue with Google',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
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
          onPressed: registerUser,
        ),
      ],
    );
  }
}
