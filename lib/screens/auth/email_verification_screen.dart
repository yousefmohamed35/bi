import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/navigation/route_names.dart';
import '../../services/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> args;

  const EmailVerificationScreen({
    super.key,
    required this.args,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isResending = false;
  late String _email;
  late String _verificationToken;
  late String _flow;
  Map<String, dynamic>? _registrationData;

  @override
  void initState() {
    super.initState();
    _email = widget.args['email']?.toString() ?? '';
    _verificationToken = widget.args['verificationToken']?.toString() ?? '';
    _flow = widget.args['flow']?.toString() ?? 'register';
    _registrationData =
        widget.args['registrationData'] as Map<String, dynamic>?;
    _codeFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final verifiedToken = await AuthService.instance.verifyRegisterEmailCode(
        email: _email,
        code: _codeController.text.trim(),
        verificationToken: _verificationToken,
      );

      if (_flow == 'register') {
        final data = _registrationData;
        if (data == null) {
          throw Exception('بيانات التسجيل غير متاحة');
        }
        await AuthService.instance.register(
          name: data['name']?.toString() ?? '',
          email: data['email']?.toString() ?? '',
          username: data['username']?.toString(),
          phone: data['phone']?.toString(),
          whatsAppNumber: data['whatsAppNumber']?.toString(),
          nationalId: data['nationalId']?.toString(),
          password: data['password']?.toString() ?? '',
          passwordConfirmation: data['passwordConfirmation']?.toString() ?? '',
          acceptTerms: data['acceptTerms'] == true,
          studentType: data['studentType']?.toString(),
          deviceId: data['deviceId']?.toString() ?? '',
          deviceName: data['deviceName']?.toString() ?? '',
          platform: data['platform']?.toString() ?? '',
          fcmToken: data['fcmToken']?.toString(),
          emailVerifiedToken: verifiedToken,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _flow == 'register'
                ? 'تم التحقق وإنشاء الحساب بنجاح. يمكنك تسجيل الدخول الآن.'
                : 'تم التحقق من البريد الإلكتروني بنجاح. قم بتسجيل الدخول.',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
        ),
      );
      context.go(RouteNames.login);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    try {
      final token = await AuthService.instance.sendRegisterVerificationCode(
        email: _email,
      );
      _verificationToken = token;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إعادة إرسال رمز التحقق إلى البريد الإلكتروني',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Email Verification', style: GoogleFonts.cairo()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the 6-digit code sent to:',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _email,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => _codeFocusNode.requestFocus(),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          final char = index < _codeController.text.length
                              ? _codeController.text[index]
                              : '';
                          final isActive = _codeFocusNode.hasFocus &&
                              _codeController.text.length == index;
                          return Container(
                            width: 46,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive
                                    ? colorScheme.primary
                                    : colorScheme.outline
                                        .withValues(alpha: 0.4),
                                width: isActive ? 1.8 : 1.1,
                              ),
                            ),
                            child: Text(
                              char,
                              style: GoogleFonts.cairo(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          );
                        }),
                      ),
                      Opacity(
                        opacity: 0,
                        child: TextFormField(
                          controller: _codeController,
                          focusNode: _codeFocusNode,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final code = value?.trim() ?? '';
                            if (code.length != 6) {
                              return 'Code must be 6 digits';
                            }
                            if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                              return 'Code must contain numbers only';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Verify', style: GoogleFonts.cairo()),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isResending ? null : _resendCode,
                  child: Text(
                    _isResending ? 'Sending...' : 'Resend code',
                    style: GoogleFonts.cairo(),
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
