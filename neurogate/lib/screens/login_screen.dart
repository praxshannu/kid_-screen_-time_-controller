import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorDetail;
  late GoogleSignIn _googleSignIn;

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(
      serverClientId: '86841428362-n7hnl1itoe4onhfc1envlt7eo27ibgkd.apps.googleusercontent.com',
      scopes: [
        'email',
      ],
    );
  }

  Future<void> _handleSignIn(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _errorDetail = null;
    });

    try {
      // Sign out first to clear any stale sessions
      await _googleSignIn.signOut();

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        final GoogleSignInAuthentication auth = await account.authentication;
        final String? token = auth.accessToken;
        
        if (token != null) {
          if (mounted) {
            final appState = Provider.of<AppState>(context, listen: false);
            await appState.setGoogleAccessToken(token);
          }
        } else {
          debugPrint('Failed to get access token');
          if (mounted) {
            setState(() {
              _errorDetail = 'Missing access token from Google';
            });
          }
        }
      } else {
        debugPrint('Sign in cancelled by user');
      }
    } catch (error) {
      debugPrint("Sign in error: $error");
      String message = error.toString();
      
      // Parse common error codes for user-friendly messages
      if (message.contains('ApiException: 7')) {
        message = 'Network error. Check your internet connection and ensure Google Play Services is up to date.';
      } else if (message.contains('ApiException: 10')) {
        message = 'Developer error: SHA-1 fingerprint mismatch. Contact the app developer.';
      } else if (message.contains('ApiException: 12500')) {
        message = 'Sign-in failed. Ensure your device has the latest Google Play Services.';
      }
      
      if (mounted) {
        setState(() {
          _errorDetail = message;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Transform.rotate(
                      angle: -0.2, // ~ -12 degrees as in prototype
                      child: const Icon(
                        Icons.generating_tokens, // Brain-like or AI icon
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'NeuroGate AI',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Authorize your Google Account to enable Gemini AI cognitive tolls and scaffolded parental controls.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.blue)
                  else
                    ElevatedButton(
                      onPressed: () => _handleSignIn(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E293B),
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        minimumSize: const Size(double.infinity, 60),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.g_mobiledata, size: 32),
                          SizedBox(width: 8),
                          Text(
                            'Authorize with Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_errorDetail != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorDetail!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'By continuing, you agree to the Terms of Service. Secure connection to Gemini via OAuth.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
