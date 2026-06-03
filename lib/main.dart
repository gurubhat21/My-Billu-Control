import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/admin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyBilluControlApp());
}

class MyBilluControlApp extends StatelessWidget {
  const MyBilluControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Billu Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        primaryColor: const Color(0xFF7C4DFF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C4DFF),
          secondary: Color(0xFF448AFF),
          surface: Color(0xFF141929),
          error: Color(0xFFF44336),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
        cardTheme: CardThemeData(
          color: const Color(0xFF141929),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withAlpha(13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withAlpha(26)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withAlpha(26)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7C4DFF)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF141929),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isSigningIn = false;
  bool _passwordVerified = false;
  String? _errorMessage;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isReturningUser = false; // true = already logged in before
  bool _checkingState = true;

  static const String _adminEmail = 'gurubhat21@gmail.com';
  static const String _masterPassword = '9449831316@guru';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
    _initState();
  }

  Future<void> _initState() async {
    await _checkBiometrics();
    await _checkReturningUser();
    setState(() => _checkingState = false);

    // If returning user with biometrics, auto-prompt fingerprint
    if (_isReturningUser && _canCheckBiometrics) {
      Future.delayed(const Duration(milliseconds: 500), _authenticateWithFingerprint);
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      setState(() => _canCheckBiometrics = canCheck && isSupported);
    } catch (e) {
      setState(() => _canCheckBiometrics = false);
    }
  }

  Future<void> _checkReturningUser() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLoggedIn = prefs.getBool('admin_authenticated') ?? false;
    setState(() => _isReturningUser = hasLoggedIn);
  }

  Future<void> _saveLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('admin_authenticated', true);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
      if (googleUser == null) {
        setState(() => _isSigningIn = false);
        return;
      }

      if (googleUser.email != _adminEmail) {
        await GoogleSignIn().signOut();
        setState(() {
          _isSigningIn = false;
          _errorMessage = 'Access denied. Only admin can use this app.\nYour email: ${googleUser.email}';
        });
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() => _isSigningIn = false);
    } catch (e) {
      setState(() {
        _isSigningIn = false;
        _errorMessage = 'Sign-in failed: $e';
      });
    }
  }

  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (_passwordController.text == _masterPassword) {
      if (_canCheckBiometrics) {
        setState(() {
          _isLoading = false;
          _passwordVerified = true;
        });
        // Auto-prompt fingerprint
        Future.delayed(const Duration(milliseconds: 300), _authenticateWithFingerprint);
      } else {
        // No biometrics, save and go
        await _saveLoginState();
        _navigateToAdmin();
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid password. Access denied.';
      });
    }
  }

  Future<void> _authenticateWithFingerprint() async {
    setState(() => _errorMessage = null);
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to access Admin Panel',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        // If returning user, sign in with Firebase silently
        if (_isReturningUser) {
          try {
            final googleUser = await GoogleSignIn(scopes: ['email']).signInSilently();
            if (googleUser != null) {
              final googleAuth = await googleUser.authentication;
              final credential = GoogleAuthProvider.credential(
                accessToken: googleAuth.accessToken,
                idToken: googleAuth.idToken,
              );
              await FirebaseAuth.instance.signInWithCredential(credential);
            }
          } catch (_) {
            // Silent sign-in failed, proceed anyway since fingerprint verified
          }
        }
        await _saveLoginState();
        _navigateToAdmin();
      } else {
        setState(() => _errorMessage = 'Fingerprint verification failed.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Biometric error: $e');
    }
  }

  void _navigateToAdmin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AdminScreenWrapper(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingState) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E1A), Color(0xFF1A1040), Color(0xFF0A0E1A)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF7C4DFF)),
          ),
        ),
      );
    }

    final isAuthenticated = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E1A), Color(0xFF1A1040), Color(0xFF0A0E1A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C4DFF).withAlpha(77),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.admin_panel_settings, size: 50, color: Colors.white),
                      ),
                      const SizedBox(height: 32),
                      Text('My Billu Control',
                        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
                      const SizedBox(height: 8),
                      Text('Admin Control Panel',
                        style: GoogleFonts.inter(fontSize: 14, color: Colors.white54, letterSpacing: 2, fontWeight: FontWeight.w400)),
                      const SizedBox(height: 48),

                      // Glass card
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withAlpha(18)),
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 40)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // === RETURNING USER: Fingerprint only ===
                            if (_isReturningUser) ...[
                              _buildStepHeader('Welcome Back', 'Fingerprint to unlock', Icons.fingerprint, const Color(0xFF00E676)),
                              const SizedBox(height: 24),
                              Center(
                                child: GestureDetector(
                                  onTap: _authenticateWithFingerprint,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.8, end: 1.0),
                                    duration: const Duration(milliseconds: 1500),
                                    curve: Curves.easeInOut,
                                    builder: (context, value, child) {
                                      return Transform.scale(scale: value, child: child);
                                    },
                                    child: Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF00E676).withAlpha(40),
                                            const Color(0xFF00E676).withAlpha(15),
                                          ],
                                        ),
                                        border: Border.all(color: const Color(0xFF00E676).withAlpha(80), width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF00E676).withAlpha(30),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.fingerprint, size: 55, color: Color(0xFF00E676)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('Tap to verify fingerprint',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
                              const SizedBox(height: 16),
                              // Option to do full login
                              TextButton(
                                onPressed: () {
                                  setState(() => _isReturningUser = false);
                                },
                                child: Text('Use password instead',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white30)),
                              ),
                            ],

                            // === FIRST TIME: Step 1 - Google Sign-in ===
                            if (!_isReturningUser && !isAuthenticated) ...[
                              _buildStepHeader('Step 1', 'Admin Authentication', Icons.mail, const Color(0xFFFF5252)),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: _isSigningIn ? null : _signInWithGoogle,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black87,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 2,
                                  ),
                                  icon: _isSigningIn
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.mail, color: Colors.red, size: 22),
                                  label: Text(
                                    _isSigningIn ? 'Signing in...' : 'Sign in with Admin Gmail',
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Only admin Gmail is allowed', textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.white30)),
                            ],

                            // === FIRST TIME: Step 2 - Master Password ===
                            if (!_isReturningUser && isAuthenticated && !_passwordVerified) ...[
                              _buildCompletedStep('Admin Gmail verified', FirebaseAuth.instance.currentUser!.email ?? ''),
                              const SizedBox(height: 20),
                              _buildStepHeader('Step 2', 'Master Password', Icons.lock, const Color(0xFF7C4DFF)),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Enter master password',
                                  hintStyle: GoogleFonts.inter(color: Colors.white24),
                                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF7C4DFF), size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: Colors.white30, size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                onSubmitted: (_) => _login(),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C4DFF),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(0xFF7C4DFF).withAlpha(128),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 8,
                                    shadowColor: const Color(0xFF7C4DFF).withAlpha(102),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(width: 22, height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                      : Text('VERIFY',
                                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                                ),
                              ),
                            ],

                            // === FIRST TIME: Step 3 - Fingerprint ===
                            if (!_isReturningUser && isAuthenticated && _passwordVerified) ...[
                              _buildCompletedStep('Admin Gmail verified', FirebaseAuth.instance.currentUser!.email ?? ''),
                              const SizedBox(height: 12),
                              _buildCompletedStep('Master password verified', ''),
                              const SizedBox(height: 20),
                              _buildStepHeader('Step 3', 'Fingerprint Verification', Icons.fingerprint, const Color(0xFF00E676)),
                              const SizedBox(height: 20),
                              Center(
                                child: GestureDetector(
                                  onTap: _authenticateWithFingerprint,
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF00E676).withAlpha(40),
                                          const Color(0xFF00E676).withAlpha(15),
                                        ],
                                      ),
                                      border: Border.all(color: const Color(0xFF00E676).withAlpha(80), width: 2),
                                    ),
                                    child: const Icon(Icons.fingerprint, size: 50, color: Color(0xFF00E676)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('Tap the fingerprint icon to verify',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
                            ],

                            // Error message
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF44336).withAlpha(26),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFF44336).withAlpha(51)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Color(0xFFF44336), size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(_errorMessage!,
                                        style: GoogleFonts.inter(color: const Color(0xFFF44336), fontSize: 13, fontWeight: FontWeight.w500)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('Authorized Access Only',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white24, letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader(String step, String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(step, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 1)),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white60)),
        ),
      ],
    );
  }

  Widget _buildCompletedStep(String label, String detail) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4CAF50).withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF4CAF50), fontWeight: FontWeight.w500)),
                if (detail.isNotEmpty)
                  Text(detail, style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wrapper that adds exit confirmation dialog
class AdminScreenWrapper extends StatelessWidget {
  const AdminScreenWrapper({super.key});

  Future<bool> _showExitDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141929),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.exit_to_app, color: Color(0xFFFF5252), size: 22),
            ),
            const SizedBox(width: 12),
            Text('Exit App',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to exit My Billu Control?',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
              style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Exit',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog(context);
        if (shouldExit) {
          // Kill the app completely
          SystemNavigator.pop();
          exit(0);
        }
      },
      child: const AdminScreen(),
    );
  }
}
