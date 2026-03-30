import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/navigation/route_names.dart';
import '../../core/notification_service/notification_service.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';

extension _RegisterScreenL10n on AppLocalizations {
  String get firstNameLabel =>
      localeName == 'ar' ? 'الاسم الأول' : 'First Name';

  String get pleaseEnterFirstName =>
      localeName == 'ar' ? 'أدخل اسمك الأول' : 'Enter your first name';

  String get lastNameLabel => localeName == 'ar' ? 'اسم العائلة' : 'Last Name';

  String get pleaseEnterLastName =>
      localeName == 'ar' ? 'أدخل اسم العائلة' : 'Enter your last name';

  String get usernameLabel => localeName == 'ar' ? 'اسم المستخدم' : 'Username';

  String get pleaseEnterUsername =>
      localeName == 'ar' ? 'اختر اسم مستخدم' : 'Choose a username';

  String get whatsAppNumberLabel =>
      localeName == 'ar' ? 'رقم الواتساب' : 'WhatsApp Number';

  String get whatsAppNumberPlaceholder => localeName == 'ar'
      ? 'رقم الواتساب (01xxxxxxxxx)'
      : 'WhatsApp number (01xxxxxxxxx)';

  String get nationalIdLabel =>
      localeName == 'ar' ? 'الرقم القومي' : 'National ID';

  String get nationalIdPlaceholder => localeName == 'ar'
      ? 'الرقم القومي المكون من ١٤ رقماً'
      : '14-digit national ID';

  String get invalidNationalId => localeName == 'ar'
      ? 'الرقم القومي غير صحيح'
      : 'Invalid Egyptian national ID';

  String get profileImageLabel =>
      localeName == 'ar' ? 'صورة الحساب (اختياري)' : 'Profile Image (optional)';

  String get tapToUploadProfileImage => localeName == 'ar'
      ? 'اضغط لرفع صورة حسابك'
      : 'Tap to upload your profile image';
}

/// Register Screen - Clean Design like Account Page
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsAppController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  bool _showPassword = false;
  bool _showPasswordConfirmation = false;
  bool _isLoading = false;
  bool _acceptTerms = false;
  String? _studentType;
  File? _profileImage;

  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
      });
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

  Future<void> _handleRegister() async {
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseAcceptTerms,
              style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
              .trim();

      // Validate password confirmation
      if (_passwordController.text != _passwordConfirmationController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.passwordMismatch,
                style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Build device info for registration
        final deviceId = await _getOrCreateDeviceId();
        final deviceInfoPlugin = DeviceInfoPlugin();
        String deviceName = 'Unknown';
        String platform = 'unknown';

        if (Platform.isAndroid) {
          final info = await deviceInfoPlugin.androidInfo;
          deviceName = info.model;
          platform = 'Android';
        } else if (Platform.isIOS) {
          final info = await deviceInfoPlugin.iosInfo;
          deviceName = info.utsname.machine;
          platform = 'iOS';
        }

        final fcmToken = FirebaseNotification.fcmToken;

        final email = _emailController.text.trim();
        final verificationToken =
            await AuthService.instance.sendRegisterVerificationCode(
          email: email,
        );

        if (!mounted) return;

        // Verification code sent, continue with verify-code screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إرسال رمز التحقق إلى بريدك الإلكتروني',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        context.push(
          RouteNames.emailVerification,
          extra: {
            'flow': 'register',
            'email': email,
            'verificationToken': verificationToken,
            'registrationData': {
              'name': fullName,
              'email': email,
              'username': _usernameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'whatsAppNumber': _whatsAppController.text.trim(),
              'nationalId': _nationalIdController.text.trim(),
              'password': _passwordController.text,
              'passwordConfirmation': _passwordConfirmationController.text,
              'acceptTerms': _acceptTerms,
              'studentType': _studentType ?? 'online',
              'deviceId': deviceId,
              'deviceName': deviceName,
              'platform': platform,
              'fcmToken': fcmToken,
            },
          },
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _whatsAppController.dispose();
    _nationalIdController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
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
      body: Column(
        children: [
          // Brand Header (smaller for register)
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  children: [
                    // Back Button & Title
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go(RouteNames.login),
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
                          AppLocalizations.of(context)!.register,
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
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.joinUsMessage,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.85),
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
              offset: const Offset(0, -20),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.background,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First Name Field
                        _buildLabel(context,
                            AppLocalizations.of(context)!.firstNameLabel),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _firstNameController,
                          hint: AppLocalizations.of(context)!
                              .pleaseEnterFirstName,
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),

                        // Last Name Field
                        _buildLabel(context,
                            AppLocalizations.of(context)!.lastNameLabel),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _lastNameController,
                          hint:
                              AppLocalizations.of(context)!.pleaseEnterLastName,
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),

                        // Username Field
                        _buildLabel(context,
                            AppLocalizations.of(context)!.usernameLabel),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _usernameController,
                          hint:
                              AppLocalizations.of(context)!.pleaseEnterUsername,
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 16),

                        // Email Field
                        _buildLabel(
                            context, AppLocalizations.of(context)!.email),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _emailController,
                          hint: 'example@email.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validatorType: 'email',
                        ),
                        const SizedBox(height: 16),

                        // Phone Field
                        _buildLabel(
                            context, AppLocalizations.of(context)!.phone),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _phoneController,
                          hint: AppLocalizations.of(context)!.phonePlaceholder,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validatorType: 'phone',
                        ),
                        const SizedBox(height: 16),

                        // WhatsApp Number Field
                        _buildLabel(context,
                            AppLocalizations.of(context)!.whatsAppNumberLabel),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _whatsAppController,
                          hint: AppLocalizations.of(context)!
                              .whatsAppNumberPlaceholder,
                          icon: Icons.chat_bubble_outline,
                          keyboardType: TextInputType.phone,
                          validatorType: 'phone',
                        ),
                        const SizedBox(height: 16),

                        // National ID Field
                        _buildLabel(context,
                            AppLocalizations.of(context)!.nationalIdLabel),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _nationalIdController,
                          hint: AppLocalizations.of(context)!
                              .nationalIdPlaceholder,
                          icon: Icons.credit_card,
                          keyboardType: TextInputType.number,
                          validatorType: 'nationalId',
                        ),
                        const SizedBox(height: 16),

                        // Profile Image (optional)
                        _buildLabel(context,
                            AppLocalizations.of(context)!.profileImageLabel),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickImage,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                backgroundImage: _profileImage != null
                                    ? FileImage(_profileImage!)
                                    : null,
                                child: _profileImage == null
                                    ? Icon(Icons.camera_alt_outlined,
                                        color: colorScheme.primary)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)!
                                      .tapToUploadProfileImage,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Student Type Selector
                        //   _buildLabel(context, AppLocalizations.of(context)!.studentType),
                        // const SizedBox(height: 8),
                        // _buildStudentTypeSelector(context),
                        // const SizedBox(height: 16),

                        // Password Field
                        _buildLabel(
                            context, AppLocalizations.of(context)!.password),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _passwordController,
                          hint: AppLocalizations.of(context)!.enterPassword,
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          passwordFieldType: 'password',
                        ),
                        const SizedBox(height: 16),

                        // Password Confirmation Field
                        _buildLabel(context,
                            AppLocalizations.of(context)!.confirmNewPassword),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _passwordConfirmationController,
                          hint:
                              AppLocalizations.of(context)!.enterPasswordAgain,
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          passwordFieldType: 'confirmation',
                        ),
                        const SizedBox(height: 16),

                        // Terms Checkbox
                        GestureDetector(
                          onTap: () =>
                              setState(() => _acceptTerms = !_acceptTerms),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.shadow
                                      .withValues(alpha: 0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: _acceptTerms
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _acceptTerms
                                          ? colorScheme.primary
                                          : colorScheme.outline,
                                      width: 2,
                                    ),
                                  ),
                                  child: _acceptTerms
                                      ? Icon(Icons.check,
                                          size: 14,
                                          color: colorScheme.onPrimary)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text:
                                          '${AppLocalizations.of(context)!.iAgreeTo} ',
                                      style: GoogleFonts.cairo(
                                          fontSize: 13,
                                          color: colorScheme.onSurfaceVariant),
                                      children: [
                                        TextSpan(
                                          text: AppLocalizations.of(context)!
                                              .termsAndConditions,
                                          style: GoogleFonts.cairo(
                                            fontSize: 13,
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
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
                                        strokeWidth: 2.5),
                                  )
                                : Text(
                                    AppLocalizations.of(context)!.createAccount,
                                    style: GoogleFonts.cairo(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Login Link
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppLocalizations.of(context)!
                                    .alreadyHaveAccount,
                                style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant),
                              ),
                              TextButton(
                                onPressed: () => context.go(RouteNames.login),
                                child: Text(
                                  AppLocalizations.of(context)!.login,
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
    return Text(
      text,
      style: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  // ignore: unused_element
  Widget _buildStudentTypeSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (label: l10n.onlineStudent, value: 'online'),
      (label: l10n.inPersonStudent, value: 'offline'),
    ];

    return Row(
      children: [
        for (int i = 0; i < options.length; i++) ...[
          Expanded(
            child: _buildStudentTypeOption(
              context: context,
              label: options[i].label,
              value: options[i].value,
              isSelected: _studentType == options[i].value,
            ),
          ),
          if (i != options.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildStudentTypeOption({
    required BuildContext context,
    required String label,
    required String value,
    required bool isSelected,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _studentType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? cs.primary : cs.outline,
                  width: 2,
                ),
                color: isSelected ? cs.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 12, color: cs.onPrimary)
                  : null,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String passwordFieldType = 'password',
    String? validatorType,
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
              offset: const Offset(0, 4)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword &&
            (passwordFieldType == 'password'
                ? !_showPassword
                : !_showPasswordConfirmation),
        keyboardType: keyboardType,
        style: GoogleFonts.cairo(fontSize: 15, color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.cairo(
              color: colorScheme.onSurfaceVariant, fontSize: 14),
          prefixIcon: Icon(icon, color: colorScheme.primary, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  onPressed: () => setState(() {
                    if (passwordFieldType == 'password') {
                      _showPassword = !_showPassword;
                    } else {
                      _showPasswordConfirmation = !_showPasswordConfirmation;
                    }
                  }),
                  icon: Icon(
                    (passwordFieldType == 'password'
                            ? _showPassword
                            : _showPasswordConfirmation)
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                )
              : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        validator: (value) {
          final l10n = AppLocalizations.of(context)!;
          if (value == null || value.isEmpty) {
            return l10n.fieldRequired;
          }
          if (validatorType == 'email' ||
              (validatorType == null &&
                  keyboardType == TextInputType.emailAddress)) {
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(value)) {
              return l10n.invalidEmail;
            }
          }
          if (isPassword &&
              passwordFieldType == 'password' &&
              value.length < 6) {
            return l10n.passwordMinLength;
          }
          if (isPassword && passwordFieldType == 'confirmation') {
            if (value != _passwordController.text) {
              return l10n.passwordMismatch;
            }
          }
          if (validatorType == 'phone' ||
              (validatorType == null && keyboardType == TextInputType.phone)) {
            final phoneRegex = RegExp(r'^01[0-2,5]{1}[0-9]{8}$');
            if (!phoneRegex.hasMatch(value)) {
              return l10n.invalidPhone;
            }
          }
          if (validatorType == 'nationalId') {
            // Basic Egyptian national ID validation: 14 digits, starting with 2 or 3
            final nationalIdRegex = RegExp(r'^[23][0-9]{13}$');
            if (!nationalIdRegex.hasMatch(value)) {
              return l10n.invalidNationalId;
            }
          }
          return null;
        },
      ),
    );
  }
}
