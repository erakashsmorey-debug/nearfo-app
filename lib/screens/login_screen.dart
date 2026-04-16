import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../l10n/l10n_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  String _countryCode = '+91';
  bool _showPhoneLogin = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _signInWithGoogle() async {
    if (context.read<AuthProvider>().isLoading) return;

    final success = await context.read<AuthProvider>().signInWithGoogle();

    if (!mounted) return;

    if (success) {
      final auth = context.read<AuthProvider>();
      if (auth.needsProfileSetup) {
        Navigator.pushReplacementNamed(context, NearfoRoutes.setupProfile);
      } else {
        Navigator.pushReplacementNamed(context, NearfoRoutes.home);
      }
    }
  }

  void _sendOTP() async {
    // Prevent double-tap
    if (context.read<AuthProvider>().isLoading) return;

    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.loginInvalidPhone),
          backgroundColor: NearfoColors.danger,
        ),
      );
      return;
    }

    final fullPhone = '$_countryCode$phone';
    final success = await context.read<AuthProvider>().sendOTP(fullPhone);

    if (!mounted) return;

    if (success) {
      Navigator.pushNamed(
        context,
        NearfoRoutes.otpVerify,
        arguments: {'phone': fullPhone},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: NearfoColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: NearfoColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NearfoColors.border),
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: NearfoColors.text, size: 22),
                ),
              ),
              const SizedBox(height: 40),

              // Header
              ShaderMask(
                shaderCallback: (bounds) => NearfoColors.primaryGradient.createShader(bounds),
                child: const Text('nearfo', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              Text(context.l10n.loginWelcome, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                context.l10n.loginSubtitle,
                style: TextStyle(color: NearfoColors.textMuted, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 40),

              // Error
              if (auth.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: NearfoColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NearfoColors.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: NearfoColors.danger, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text(auth.error!, style: TextStyle(color: NearfoColors.danger, fontSize: 13))),
                    ],
                  ),
                ),

              // Google Sign-In Button (PRIMARY)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.white.withOpacity(0.15), blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: auth.isLoading ? null : _signInWithGoogle,
                    icon: auth.isLoading
                        ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.red, fontFamily: 'sans-serif')),
                    label: Text(
                      auth.isLoading ? context.l10n.signingIn : context.l10n.loginContinueWithGoogle,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: NearfoColors.border, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(context.l10n.or, style: TextStyle(color: NearfoColors.textDim, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Expanded(child: Divider(color: NearfoColors.border, thickness: 1)),
                ],
              ),
              const SizedBox(height: 24),

              // Phone Login Toggle / Section
              if (!_showPhoneLogin)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _showPhoneLogin = true),
                    icon: Icon(Icons.phone_android, size: 22, color: NearfoColors.text),
                    label: Text(
                      context.l10n.loginContinueWithPhone,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NearfoColors.text,
                      side: BorderSide(color: NearfoColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: NearfoColors.card,
                    ),
                  ),
                )
              else ...[
                // Phone Input
                Container(
                  decoration: BoxDecoration(
                    color: NearfoColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: NearfoColors.border),
                  ),
                  child: Row(
                    children: [
                      // Country code
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: NearfoColors.border)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('\u{1F1EE}\u{1F1F3}', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 6),
                            Text(_countryCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          ],
                        ),
                      ),
                      // Phone number
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: 1.5),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            hintText: context.l10n.loginEnterMobile,
                            hintStyle: TextStyle(color: NearfoColors.textDim),
                            border: InputBorder.none,
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Send OTP Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: NearfoColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: NearfoColors.primary.withOpacity(0.4), blurRadius: 16, offset: Offset(0, 6)),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _sendOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: auth.isLoading
                          ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(context.l10n.loginSendOtp, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ],
              SizedBox(height: 24),

              // Terms
              Center(
                child: Text.rich(
                  TextSpan(
                    text: context.l10n.loginTermsAgreement,
                    style: TextStyle(color: NearfoColors.textDim, fontSize: 12),
                    children: [
                      TextSpan(
                        text: context.l10n.loginTermsOfService,
                        style: TextStyle(color: NearfoColors.primaryLight),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: context.l10n.loginPrivacyPolicy,
                        style: TextStyle(color: NearfoColors.primaryLight),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
