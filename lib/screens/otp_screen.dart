import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../l10n/l10n_helper.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String get _otp => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _verifyOTP() async {
    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.otpIncomplete), backgroundColor: NearfoColors.danger),
      );
      return;
    }

    final args = (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?);
    final phone = ((args?['phone'] as String?) ?? '');

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.otpPhoneMissing), backgroundColor: NearfoColors.danger),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOTP(_otp, phone);

    if (!mounted) return;

    if (success) {
      final nextRoute = auth.needsProfileSetup ? NearfoRoutes.setupProfile : NearfoRoutes.home;
      Navigator.pushNamedAndRemoveUntil(
        context,
        NearfoRoutes.permissions,
        (r) => false,
        arguments: {'nextRoute': nextRoute},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final args = (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?);
    final phone = ((args?['phone'] as String?) ?? '');

    return Scaffold(
      backgroundColor: NearfoColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 40),
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

              Text(context.l10n.otpTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                context.l10n.otpSubtitle(phone: phone),
                style: TextStyle(color: NearfoColors.textMuted, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 40),

              // OTP Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => SizedBox(
                  width: 50,
                  height: 60,
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: NearfoColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: NearfoColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: NearfoColors.primary, width: 2),
                      ),
                    ),
                    onChanged: (val) {
                      if (val.isNotEmpty && i < 5) {
                        _focusNodes[i + 1].requestFocus();
                      }
                      if (val.isEmpty && i > 0) {
                        _focusNodes[i - 1].requestFocus();
                      }
                      if (_otp.length == 6 && !context.read<AuthProvider>().isLoading) _verifyOTP();
                    },
                  ),
                )),
              ),
              const SizedBox(height: 32),

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

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: NearfoColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: auth.isLoading
                        ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(context.l10n.otpVerify, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Dev OTP hint (only shows in dev mode when server returns OTP)
              if (auth.devOtp != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: NearfoColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NearfoColors.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bug_report, color: NearfoColors.success, size: 20),
                      const SizedBox(width: 8),
                      Text(context.l10n.otpDevCode(otp: auth.devOtp!), style: TextStyle(color: NearfoColors.success, fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),

              // Resend
              Center(
                child: TextButton(
                  onPressed: () async {
                    await context.read<AuthProvider>().sendOTP(phone);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.otpResent), backgroundColor: NearfoColors.success),
                      );
                    }
                  },
                  child: Text(context.l10n.otpResend, style: TextStyle(color: NearfoColors.primaryLight, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
