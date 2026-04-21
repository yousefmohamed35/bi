import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/navigation/route_names.dart';
import '../../core/notification_service/notification_service.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';

/// Login Screen - Clean Design like Account Page
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;
  // bool _googleLoading = false;
  // bool _appleLoading = false;

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Build device info for login
        final deviceId = await _getOrCreateDeviceId();

        if (FirebaseNotification.fcmToken == null ||
            FirebaseNotification.fcmToken!.trim().isEmpty) {
          await FirebaseNotification.getFcmToken();
        }
        final fcmToken = FirebaseNotification.fcmToken;

        final authResponse = await AuthService.instance.login(
          emailOrPhone: _emailOrPhoneController.text.trim(),
          password: _passwordController.text,
          deviceId: deviceId,
          fcmToken: fcmToken,
        );

        if (!mounted) return;

        // Save launch flag
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasLaunched', true);

        // Navigate by role: instructor → instructor flow, else → student flow
        if (mounted) {
          final role = authResponse.user.role.toLowerCase();
          if (role == 'instructor' || role == 'teacher') {
            context.go(RouteNames.instructorHome);
          } else {
            context.go(RouteNames.home);
          }
        }
      } catch (e) {
        if (!mounted) return;

        if (e is EmailNotVerifiedException) {
          final identifier = _emailOrPhoneController.text.trim();
          final isEmail =
              RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(identifier);

          if (!isEmail) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  e.message,
                  style: GoogleFonts.cairo(),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }

          try {
            final verificationToken =
                await AuthService.instance.sendRegisterVerificationCode(
              email: identifier,
            );

            if (!mounted) return;

            context.push(
              RouteNames.emailVerification,
              extra: {
                'flow': 'login',
                'email': identifier,
                'verificationToken': verificationToken,
              },
            );
            return;
          } catch (sendCodeError) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  sendCodeError.toString().replaceFirst('Exception: ', ''),
                  style: GoogleFonts.cairo(),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('device_id');
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final random = Random.secure();
    final newId =
        '${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(1 << 32)}';
    await prefs.setString('device_id', newId);
    return newId;
  }

  // Google and Apple auth - commented out
  // Future<void> _handleGoogleLogin() async {
  //   if (_googleLoading || _appleLoading) return;
  //   setState(() {
  //     _googleLoading = true;
  //     _appleLoading = false;
  //   });

  //   try {
  //     final authResponse = await AuthService.instance.signInWithGoogle();

  //     if (!mounted) return;

  //     final prefs = await SharedPreferences.getInstance();
  //     await prefs.setBool('hasLaunched', true);

  //     if (mounted) {
  //       final role = authResponse.user.role.toLowerCase();
  //       if (role == 'instructor' || role == 'teacher') {
  //         context.go(RouteNames.instructorHome);
  //       } else {
  //         context.go(RouteNames.home);
  //       }
  //     }
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           e.toString().replaceFirst('Exception: ', ''),
  //           style: GoogleFonts.cairo(),
  //         ),
  //         backgroundColor: Colors.red,
  //         duration: const Duration(seconds: 3),
  //       ),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() => _googleLoading = false);
  //     }
  //   }
  // }

  // Future<void> _handleAppleLogin() async {
  //   if (_appleLoading || _googleLoading) return;
  //   setState(() {
  //     _appleLoading = true;
  //     _googleLoading = false;
  //   });

  //   try {
  //     final authResponse = await AuthService.instance.signInWithApple();

  //     if (!mounted) return;

  //     final prefs = await SharedPreferences.getInstance();
  //     await prefs.setBool('hasLaunched', true);

  //     if (mounted) {
  //       final role = authResponse.user.role.toLowerCase();
  //       if (role == 'instructor' || role == 'teacher') {
  //         context.go(RouteNames.instructorHome);
  //       } else {
  //         context.go(RouteNames.home);
  //       }
  //     }
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           e.toString().replaceFirst('Exception: ', ''),
  //           style: GoogleFonts.cairo(),
  //         ),
  //         backgroundColor: Colors.red,
  //         duration: const Duration(seconds: 3),
  //       ),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() => _appleLoading = false);
  //     }
  //   }
  // }

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // Brand Header
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  Color.lerp(colorScheme.primary, colorScheme.shadow, 0.32)!,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
                child: Column(
                  children: [
                    // Back Button
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go(RouteNames.onboarding1),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          AppLocalizations.of(context)!.login,
                          style: GoogleFonts.cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 44),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Logo
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/play_store_512.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.school_rounded,
                            size: 45,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.welcomeBack,
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Form Container
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.background,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    40,
                    24,
                    24 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Email or Phone Field
                        _buildLabel(context,
                            AppLocalizations.of(context)!.emailOrPhone),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _emailOrPhoneController,
                          hint: AppLocalizations.of(context)!.enterEmailOrPhone,
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.text,
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        _buildLabel(
                            context, AppLocalizations.of(context)!.password),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _passwordController,
                          hint: AppLocalizations.of(context)!.enterPassword,
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                        ),
                        const SizedBox(height: 12),

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () =>
                                context.push(RouteNames.forgotPassword),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.forgotPassword,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: colorScheme.onPrimary,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    AppLocalizations.of(context)!.login,
                                    style: GoogleFonts.cairo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Apple and Google auth widget - commented out
                        // // Divider
                        // Row(
                        //   children: [
                        //     Expanded(child: Divider(color: Colors.grey[300])),
                        //     Padding(
                        //       padding:
                        //           const EdgeInsets.symmetric(horizontal: 16),
                        //       child: Text(
                        //         AppLocalizations.of(context)!.or,
                        //         style: GoogleFonts.cairo(
                        //             color: AppColors.mutedForeground),
                        //       ),
                        //     ),
                        //     Expanded(child: Divider(color: Colors.grey[300])),
                        //   ],
                        // ),
                        // const SizedBox(height: 24),

                        // // Social Buttons
                        // Row(
                        //   children: [
                        //     Expanded(
                        //         child: _buildSocialButton(
                        //       icon: Icons.g_mobiledata_rounded,
                        //       label: AppLocalizations.of(context)!.google,
                        //       onPressed: (_isLoading || _appleLoading)
                        //           ? null
                        //           : _handleGoogleLogin,
                        //       isLoading: _googleLoading,
                        //     )),
                        //     const SizedBox(width: 12),
                        //     Expanded(
                        //         child: _buildSocialButton(
                        //       icon: Icons.apple_rounded,
                        //       label: AppLocalizations.of(context)!.apple,
                        //       onPressed: (_isLoading || _googleLoading)
                        //           ? null
                        //           : _handleAppleLogin,
                        //       isLoading: _appleLoading,
                        //     )),
                        //   ],
                        // ),

                        // Register Link
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  AppLocalizations.of(context)!.noAccount,
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    context.go(RouteNames.register),
                                child: Text(
                                  AppLocalizations.of(context)!.registerNow,
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !_showPassword,
        keyboardType: keyboardType,
        style: GoogleFonts.cairo(fontSize: 15, color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.cairo(
              color: colorScheme.onSurfaceVariant, fontSize: 14),
          prefixIcon: Icon(icon, color: colorScheme.primary, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return AppLocalizations.of(context)!.fieldRequired;
          }
          // Accept any input (email or phone) - validation will be done by backend
          return null;
        },
      ),
    );
  }

  // /* Apple and Google auth widget - commented out
  // Widget _buildSocialButton({
  //   required IconData icon,
  //   required String label,
  //   VoidCallback? onPressed,
  //   bool isLoading = false,
  // }) {
  //   final isDisabled = onPressed == null || isLoading;
  //   return Opacity(
  //     opacity: isDisabled ? 0.6 : 1,
  //     child: InkWell(
  //       onTap: isDisabled ? null : onPressed,
  //       borderRadius: BorderRadius.circular(14),
  //       child: Container(
  //         height: 50,
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.circular(14),
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.black.withOpacity(0.04),
  //               blurRadius: 10,
  //               offset: const Offset(0, 4),
  //             ),
  //           ],
  //         ),
  //         child: Row(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: [
  //             if (isLoading)
  //               const SizedBox(
  //                 width: 20,
  //                 height: 20,
  //                 child: CircularProgressIndicator(
  //                   strokeWidth: 2,
  //                   color: AppColors.purple,
  //                 ),
  //               )
  //             else
  //               Icon(icon, size: 24, color: AppColors.foreground),
  //             const SizedBox(width: 8),
  //             Text(
  //               label,
  //               style: GoogleFonts.cairo(
  //                 fontSize: 14,
  //                 fontWeight: FontWeight.w600,
  //                 color: AppColors.foreground,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
}
