import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/presentation/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final List<String> _otpDigits = List.filled(6, '');
  int _otpCursor = 0;

  bool _isOTPSent = false;
  bool _isWelcomeBack = false;

  int _countdownSeconds = 60;
  Timer? _countdownTimer;

  String _selectedCountryCode = '+91';
  bool _isPhoneFocused = false;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    // Simulate detecting a saved profile for Welcome Back/Session Recovery state
    final authState = ref.read(authProvider);
    if (authState.user != null) {
      _isWelcomeBack = true;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdownSeconds = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
        } else {
          _countdownTimer?.cancel();
        }
      });
    });
  }

  void _handleSendOTP() async {
    final phone = _phoneController.text.trim();
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');

    if (_selectedCountryCode == '+91') {
      if (digitsOnly.length != 10) {
        setState(() {
          _phoneError = 'Please enter a valid 10-digit mobile number.';
        });
        return;
      }
    } else {
      if (digitsOnly.length < 8) {
        setState(() {
          _phoneError = 'Please enter a valid phone number (at least 8 digits).';
        });
        return;
      }
    }

    setState(() {
      _phoneError = null;
    });

    await ref.read(authProvider.notifier).sendOTP('$_selectedCountryCode $phone');
    setState(() {
      _isOTPSent = true;
      _otpCursor = 0;
      _otpDigits.fillRange(0, 6, '');
    });
    _startTimer();
  }

  void _handleVerifyOTP() async {
    final otpCode = _otpDigits.join();
    if (otpCode.length < 6) return;

    final success = await ref.read(authProvider.notifier).verifyOTP(otpCode);
    if (success && mounted) {
      // Direct user to role selection screen first
      context.go('/role-selection');
    } else if (mounted) {
      // Reset OTP digits on failure
      setState(() {
        _otpDigits.fillRange(0, 6, '');
        _otpCursor = 0;
      });
    }
  }

  void _handleBiometricAuth() async {
    // Trigger biometric simulation
    await ref.read(authProvider.notifier).signInBiometrically();
    if (mounted) {
      context.go('/role-selection');
    }
  }

  void _handleDigitPressed(String digit) {
    if (_otpCursor < 6) {
      setState(() {
        _otpDigits[_otpCursor] = digit;
        _otpCursor++;
      });
      if (_otpCursor == 6) {
        _handleVerifyOTP();
      }
    }
  }

  void _handleDigitDeleted() {
    if (_otpCursor > 0) {
      setState(() {
        _otpCursor--;
        _otpDigits[_otpCursor] = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isWelcomeBack
              ? _buildWelcomeBackView(authState)
              : !_isOTPSent
                  ? _buildPhoneInputView(authState)
                  : _buildOTPVerificationView(authState),
        ),
      ),
    );
  }

  // State 1: Welcome Back (Session Recovery & Biometrics)
  Widget _buildWelcomeBackView(AuthState authState) {
    final user = authState.user;
    return Padding(
      key: const ValueKey('welcomeBack'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Profile image
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.surfaceContainerHigh,
            backgroundImage: user?.profileImageUrl != null ? NetworkImage(user!.profileImageUrl!) : null,
            child: user?.profileImageUrl == null
                ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome back,',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            user?.name ?? 'Alex Chen',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
          ),
          const SizedBox(height: 12),
          // Device Trust badge
          _buildDeviceTrustBadge(),
          const Spacer(),

          // Fast unlocking actions
          if (user?.biometricsEnabled ?? true) ...[
            BentoCard(
              onTap: _handleBiometricAuth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fingerprint, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Unlock with Face / Touch ID',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isWelcomeBack = false;
                  _isOTPSent = false;
                });
              },
              child: const Text('Use a different phone number'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // State 2: Phone Number Input View
  Widget _buildPhoneInputView(AuthState authState) {
    return LayoutBuilder(
      key: const ValueKey('phoneInput'),
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 32.0,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Enter phone number',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: AppColors.onSurface,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ZeroPay uses your secure phone token to authenticate transactions on-chain.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Custom Input Container with focus and error outlines
                  Focus(
                    onFocusChange: (hasFocus) {
                      setState(() {
                        _isPhoneFocused = hasFocus;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(
                          color: _phoneError != null
                              ? AppColors.error
                              : _isPhoneFocused
                                  ? AppColors.primary
                                  : AppColors.outlineVariant.withOpacity(0.5),
                          width: _isPhoneFocused || _phoneError != null ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Country Code Dropdown
                          DropdownButton<String>(
                            value: _selectedCountryCode,
                            underline: const SizedBox(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                    _selectedCountryCode = newValue;
                                });
                              }
                            },
                            items: <String>['+1', '+44', '+49', '+81', '+91']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurface,
                                      ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 24,
                            color: AppColors.outlineVariant,
                          ),
                          const SizedBox(width: 12),
                          // Phone Number field
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(_selectedCountryCode == '+91' ? 10 : 15),
                              ],
                              style: Theme.of(context).textTheme.bodyLarge,
                              onChanged: (val) {
                                if (_phoneError != null) {
                                  setState(() {
                                    _phoneError = null;
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                hintText: '9876543210',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_phoneError != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _phoneError!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  _buildDeviceTrustBadge(),
                  const Spacer(),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      text: 'Send Verification Code',
                      isLoading: authState.isLoading,
                      onPressed: _handleSendOTP,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // State 3: OTP Code Cells & Keypad
  Widget _buildOTPVerificationView(AuthState authState) {
    final hasError = authState.errorMessage != null;

    return Padding(
      key: const ValueKey('otpVerification'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Heading
          Text(
            'Verification Code',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sent to $_selectedCountryCode ${_phoneController.text}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isOTPSent = false;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Icon(Icons.edit, size: 14, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),

          // Code cells with error and focus borders
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              final digit = _otpDigits[index];
              final isFocused = _otpCursor == index;
              return Container(
                width: 46,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasError
                        ? AppColors.error
                        : isFocused
                            ? AppColors.primary
                            : AppColors.outlineVariant.withOpacity(0.5),
                    width: isFocused || hasError ? 2.0 : 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  digit,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hasError ? AppColors.error : AppColors.primary,
                      ),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Resend Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_countdownSeconds > 0) ...[
                Text(
                  'Resend code in ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
                Text(
                  '${_countdownSeconds}s',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: _handleSendOTP,
                  child: Text(
                    'Resend Verification Code',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              ],
            ],
          ),
          
          if (hasError) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    authState.errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // Custom Keypad
          _buildCustomKeypad(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Device Trust Indicator Badge
  Widget _buildDeviceTrustBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: AppColors.tertiary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: AppColors.tertiary.withOpacity(0.15),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.security, size: 16, color: AppColors.tertiary),
          const SizedBox(width: 8),
          Text(
            'Secure Enclave Active • Device Trust Verified',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.tertiary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  // Revolut-style custom numeric keypad
  Widget _buildCustomKeypad() {
    final double buttonSize = 64;

    Widget buildButton(String label, {VoidCallback? onTap, IconData? icon}) {
      return Container(
        width: buttonSize,
        height: buttonSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 24, color: AppColors.onSurface)
                  : Text(
                      label,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                    ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildButton('1', onTap: () => _handleDigitPressed('1')),
            buildButton('2', onTap: () => _handleDigitPressed('2')),
            buildButton('3', onTap: () => _handleDigitPressed('3')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildButton('4', onTap: () => _handleDigitPressed('4')),
            buildButton('5', onTap: () => _handleDigitPressed('5')),
            buildButton('6', onTap: () => _handleDigitPressed('6')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildButton('7', onTap: () => _handleDigitPressed('7')),
            buildButton('8', onTap: () => _handleDigitPressed('8')),
            buildButton('9', onTap: () => _handleDigitPressed('9')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Left action (biometrics inside OTP keypad as recovery helper)
            buildButton('', icon: Icons.fingerprint, onTap: _handleBiometricAuth),
            buildButton('0', onTap: () => _handleDigitPressed('0')),
            // Right action (backspace)
            buildButton('', icon: Icons.backspace_outlined, onTap: _handleDigitDeleted),
          ],
        ),
      ],
    );
  }
}
