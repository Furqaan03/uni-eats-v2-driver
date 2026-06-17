import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../navigation/main_nav_shell.dart';

class OnboardingScreen extends StatefulWidget {
  final bool startAtLogin;
  const OnboardingScreen({super.key, this.startAtLogin = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0; // 0=phone, 1=otp, 2=profile, 3=docs, 4=review

  @override
  void initState() {
    super.initState();
    _step = widget.startAtLogin ? 0 : 0;
  }

  void _next() {
    if (_step < 4) {
      setState(() => _step++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavShell()),
      );
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _step == 2 || _step == 3
          ? AppColors.lightBg
          : AppColors.darkSurface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(
          key: ValueKey(_step),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _PhoneStep(onNext: _next, onBack: _back, step: 1);
      case 1:
        return _OtpStep(onNext: _next, onBack: _back);
      case 2:
        return _ProfileStep(onNext: _next, onBack: _back);
      case 3:
        return _DocsStep(onNext: _next, onBack: _back);
      case 4:
        return _ReviewStep(onFinish: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavShell()),
        ));
      default:
        return const SizedBox();
    }
  }
}

// ─── Step 1: Phone ───────────────────────────────────────────────────────────
class _PhoneStep extends StatefulWidget {
  final VoidCallback onNext, onBack;
  final int step;
  const _PhoneStep({required this.onNext, required this.onBack, required this.step});

  @override
  State<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<_PhoneStep> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 8) {
      setState(() => _error = 'Enter a valid 8-digit number');
      return;
    }
    setState(() { _loading = true; _error = null; });

    // TODO: Firebase Phone Auth — uncomment when Firebase is configured:
    //
    // await FirebaseAuth.instance.verifyPhoneNumber(
    //   phoneNumber: '+974$phone',
    //   verificationCompleted: (PhoneAuthCredential credential) async {
    //     await FirebaseAuth.instance.signInWithCredential(credential);
    //     widget.onNext();
    //   },
    //   verificationFailed: (FirebaseAuthException e) {
    //     setState(() { _error = e.message; _loading = false; });
    //   },
    //   codeSent: (String verificationId, int? resendToken) {
    //     // Store verificationId for OTP step, then navigate
    //     widget.onNext();
    //   },
    //   codeAutoRetrievalTimeout: (String verificationId) {},
    // );

    // Temporary: skip straight to OTP step
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _loading = false);
    widget.onNext();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);

    // TODO: Google Sign-In — uncomment when packages are added:
    //
    // final googleUser = await GoogleSignIn().signIn();
    // if (googleUser == null) { setState(() => _loading = false); return; }
    // final googleAuth = await googleUser.authentication;
    // final credential = GoogleAuthProvider.credential(
    //   accessToken: googleAuth.accessToken,
    //   idToken: googleAuth.idToken,
    // );
    // await FirebaseAuth.instance.signInWithCredential(credential);
    // widget.onNext();

    await Future.delayed(const Duration(milliseconds: 400));
    setState(() => _loading = false);
    widget.onNext();
  }

  Future<void> _signInWithApple() async {
    setState(() => _loading = true);

    // TODO: Apple Sign-In — uncomment when packages are added:
    //
    // final appleCredential = await SignInWithApple.getAppleIDCredential(
    //   scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    // );
    // final oauthCredential = OAuthProvider('apple.com').credential(
    //   idToken: appleCredential.identityToken,
    //   accessToken: appleCredential.authorizationCode,
    // );
    // await FirebaseAuth.instance.signInWithCredential(oauthCredential);
    // widget.onNext();

    await Future.delayed(const Duration(milliseconds: 400));
    setState(() => _loading = false);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(onBack: widget.onBack, step: 1, total: 3),
          Expanded(
            child: SingleChildScrollView(
              // Scroll when keyboard opens so the CTA stays visible
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "What's your\nphone number?",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "We'll send a code to verify it's you.",
                    style: TextStyle(fontSize: 13, color: AppColors.darkSubText),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: const Text(
                          '🇶🇦 +974',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 8,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                            letterSpacing: 1,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '5512 3344',
                            hintStyle: const TextStyle(
                              color: AppColors.darkSubText,
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor: AppColors.darkCard,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.orange),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.darkBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.orange, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.red),
                            ),
                          ),
                          onChanged: (_) => setState(() => _error = null),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(fontSize: 12, color: AppColors.red),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    '📍 Qatar numbers only (+974)',
                    style: TextStyle(fontSize: 11, color: AppColors.darkSubText),
                  ),
                  const SizedBox(height: 20),
                  _divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _SocialBtn(
                        label: 'Google',
                        logo: _GoogleLogo(),
                        onTap: _loading ? null : _signInWithGoogle,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _SocialBtn(
                        label: 'Apple',
                        logo: _AppleLogo(),
                        onTap: _loading ? null : _signInWithApple,
                      )),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _OrangeCta(
                    label: _loading ? 'Sending…' : 'Send Verification Code →',
                    onTap: _loading ? () {} : _sendCode,
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'By continuing you agree to our Terms of Service\nand Privacy Policy',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: AppColors.darkSubText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.darkCard)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('or continue with',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.darkSubText)),
          ),
          Expanded(child: Container(height: 1, color: AppColors.darkCard)),
        ],
      );
}

// ─── Step 2: OTP ─────────────────────────────────────────────────────────────
class _OtpStep extends StatefulWidget {
  final VoidCallback onNext, onBack;
  const _OtpStep({required this.onNext, required this.onBack});

  @override
  State<_OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends State<_OtpStep> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;
  int _resendSeconds = 59;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() async {
    while (mounted && _resendSeconds > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _resendSeconds--);
    }
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }
    setState(() { _loading = true; _error = null; });

    // TODO: Firebase OTP verification — uncomment when Firebase is configured:
    //
    // final credential = PhoneAuthProvider.credential(
    //   verificationId: verificationId, // passed from _PhoneStep
    //   smsCode: _otp,
    // );
    // try {
    //   await FirebaseAuth.instance.signInWithCredential(credential);
    //   widget.onNext();
    // } on FirebaseAuthException catch (e) {
    //   setState(() { _error = e.message; _loading = false; });
    // }

    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _loading = false);
    widget.onNext();
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    for (final n in _nodes) { n.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(onBack: widget.onBack, step: 1, total: 3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the code',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Sent to your phone via SMS',
                      style: TextStyle(fontSize: 13, color: AppColors.darkSubText)),
                  const SizedBox(height: 28),
                  // 6 OTP boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) => _OtpBox(
                      controller: _ctrls[i],
                      focusNode: _nodes[i],
                      onChanged: (val) {
                        if (val.isNotEmpty && i < 5) {
                          _nodes[i + 1].requestFocus();
                        } else if (val.isEmpty && i > 0) {
                          _nodes[i - 1].requestFocus();
                        }
                        setState(() => _error = null);
                        if (_otp.length == 6) _verify();
                      },
                    )),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: const TextStyle(fontSize: 12, color: AppColors.red)),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Row(
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Code sent via SMS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                              ),
                            ),
                            Text(
                              'Check your messages app',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.darkSubText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _resendSeconds > 0
                            ? '⏱ Resend in 00:${_resendSeconds.toString().padLeft(2, '0')}'
                            : 'Didn\'t receive it?',
                        style: const TextStyle(fontSize: 12, color: AppColors.darkSubText),
                      ),
                      GestureDetector(
                        onTap: _resendSeconds == 0
                            ? () {
                                setState(() => _resendSeconds = 59);
                                _startResendTimer();
                                // TODO: call Firebase verifyPhoneNumber again to resend
                              }
                            : null,
                        child: Text(
                          'Resend Code',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _resendSeconds == 0
                                ? AppColors.darkText
                                : AppColors.darkSubText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _OrangeCta(
                    label: _loading ? 'Verifying…' : 'Verify →',
                    onTap: _loading ? () {} : _verify,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.darkText,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.darkCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.orange),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.orange, width: 2),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ─── Step 3: Profile ─────────────────────────────────────────────────────────
class _ProfileStep extends StatefulWidget {
  final VoidCallback onNext, onBack;
  const _ProfileStep({required this.onNext, required this.onBack});

  @override
  State<_ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<_ProfileStep> {
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  String _campus = 'UDST';
  XFile? _photo;
  String? _nameError;

  final _campuses = ['UDST'];
  static final _nameRegex = RegExp(r"^[a-zA-Z\- ]+$");

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) setState(() => _photo = picked);
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.length < 3) {
      setState(() => _nameError = 'Enter your full name');
      return;
    }
    if (!_nameRegex.hasMatch(name)) {
      setState(() => _nameError = 'Name can only contain letters and hyphens');
      return;
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderLight(onBack: widget.onBack, step: 2, total: 3),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tell us about\nyourself',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your customers will see this info.',
                    style: TextStyle(fontSize: 13, color: AppColors.lightSubText),
                  ),
                  const SizedBox(height: 20),

                  // ── Avatar picker ──
                  Center(
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Stack(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.lightBg,
                              border: Border.all(
                                color: _photo != null ? AppColors.green : AppColors.lightBorder,
                                width: 2.5,
                              ),
                              image: _photo != null
                                  ? DecorationImage(
                                      image: FileImage(File(_photo!.path)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _photo == null
                                ? const Center(
                                    child: Text('📷', style: TextStyle(fontSize: 32)),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.orange,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _photo != null ? '✓ Photo selected · Optional' : 'Tap to add a photo (optional)',
                      style: TextStyle(
                        fontSize: 11,
                        color: _photo != null ? AppColors.green : AppColors.lightSubText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Full name ──
                  _label('FULL NAME'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.lightText,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Ahmed Al-Rashid',
                      hintStyle: const TextStyle(color: AppColors.lightSubText),
                      filled: true,
                      fillColor: AppColors.lightSurface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.orange),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.lightBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.orange, width: 2),
                      ),
                      errorText: _nameError,
                    ),
                    onChanged: (_) => setState(() => _nameError = null),
                  ),
                  const SizedBox(height: 16),

                  // ── Student ID ──
                  _label('STUDENT ID'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _idCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.lightText,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. 2023012345',
                      hintStyle: const TextStyle(color: AppColors.lightSubText),
                      filled: true,
                      fillColor: AppColors.lightSurface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.lightBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.lightBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.orange, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Campus dropdown ──
                  _label('CAMPUS'),
                  const SizedBox(height: 6),
                  _DropdownField<String>(
                    value: _campus,
                    items: _campuses,
                    labelOf: (v) => v,
                    onChanged: (v) { if (v != null) setState(() => _campus = v); },
                  ),
                  const SizedBox(height: 16),

                  // ── Delivery method ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.lightBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('🚶', style: TextStyle(fontSize: 22)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'On Foot · UDST Campus',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.lightText,
                                ),
                              ),
                              Text(
                                'All deliveries made on foot within campus.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.lightSubText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _OrangeCta(label: 'Continue →', onTap: _submit),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.lightSubText,
      letterSpacing: 0.5,
    ),
  );
}

class _DropdownField<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;
  const _DropdownField({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.lightText,
          ),
          items: items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(labelOf(item)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─── Step 4: Documents ───────────────────────────────────────────────────────
class _DocItem {
  final String emoji;
  final String name;
  final bool required;
  XFile? imageFile;
  String? pdfPath;
  String? get fileName => imageFile?.name ?? (pdfPath != null ? pdfPath!.split('\\').last.split('/').last : null);
  bool get hasFile => imageFile != null || pdfPath != null;
  _DocItem({required this.emoji, required this.name, this.required = true});
}

class _DocsStep extends StatefulWidget {
  final VoidCallback onNext, onBack;
  const _DocsStep({required this.onNext, required this.onBack});

  @override
  State<_DocsStep> createState() => _DocsStepState();
}

class _DocsStepState extends State<_DocsStep> {
  final _picker = ImagePicker();
  late final List<_DocItem> _docs;

  @override
  void initState() {
    super.initState();
    _docs = [
      _DocItem(emoji: '🪪', name: 'QID (Qatar ID)'),
      _DocItem(emoji: '🎓', name: 'Student ID'),
      _DocItem(emoji: '📅', name: 'Class Schedule'),
      _DocItem(emoji: '📄', name: 'CV / Resume', required: false),
    ];
  }

  Future<void> _pickDoc(int index) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFE53935)),
              title: const Text('Upload PDF'),
              subtitle: const Text('Select a PDF from your files app'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    if (choice == 'pdf') {
      // image_picker.pickMedia opens Android's media/file picker on API 21+
      // On Android 13+ this includes documents; on older devices it falls back to images.
      final picked = await _picker.pickMedia();
      if (picked != null) {
        final isPdf = picked.name.toLowerCase().endsWith('.pdf');
        setState(() {
          _docs[index].imageFile = isPdf ? null : picked;
          _docs[index].pdfPath = isPdf ? picked.path : null;
          // If not a PDF (user picked an image via media picker), treat as imageFile
          if (!isPdf) _docs[index].imageFile = picked;
        });
      }
    } else {
      final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final picked = await _picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() {
          _docs[index].imageFile = picked;
          _docs[index].pdfPath = null;
        });
      }
    }
  }

  int get _uploaded => _docs.where((d) => d.hasFile).length;
  int get _required => _docs.where((d) => d.required).length;
  int get _requiredUploaded => _docs.where((d) => d.required && d.hasFile).length;

  void _submit() {
    if (_requiredUploaded < _required) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload all required documents first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _uploaded / _docs.length;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderLight(onBack: widget.onBack, step: 3, total: 3),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload your\ndocuments',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Required to verify your account. Reviewed within 24hrs.',
                    style: TextStyle(fontSize: 13, color: AppColors.lightSubText),
                  ),
                  const SizedBox(height: 20),

                  ...List.generate(_docs.length, (i) {
                    final doc = _docs[i];
                    return Padding(
                      padding: EdgeInsets.only(bottom: i < _docs.length - 1 ? 10 : 0),
                      child: GestureDetector(
                        onTap: () => _pickDoc(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: doc.hasFile ? AppColors.green.withValues(alpha: 0.40) : AppColors.lightBorder,
                              width: doc.hasFile ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: doc.hasFile
                                      ? AppColors.green.withValues(alpha: 0.10)
                                      : AppColors.lightBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: doc.imageFile != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          File(doc.imageFile!.path),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Center(
                                        child: doc.pdfPath != null
                                            ? const Icon(Icons.picture_as_pdf,
                                                color: Color(0xFFE53935), size: 22)
                                            : Text(doc.emoji,
                                                style: const TextStyle(fontSize: 18)),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          doc.name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.lightText,
                                          ),
                                        ),
                                        if (!doc.required) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0F0F0),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'optional',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.lightSubText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      doc.hasFile
                                          ? '✓ ${doc.fileName}'
                                          : 'Tap to upload · Photo or PDF',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: doc.hasFile ? AppColors.green : AppColors.lightSubText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                doc.hasFile ? Icons.check_circle : Icons.upload_rounded,
                                color: doc.hasFile ? AppColors.green : const Color(0xFFCCCCCC),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  // Progress bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _uploaded == _docs.length
                          ? AppColors.green.withValues(alpha: 0.06)
                          : AppColors.orange.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _uploaded == _docs.length
                            ? AppColors.green.withValues(alpha: 0.20)
                            : AppColors.orange.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_uploaded of ${_docs.length} documents uploaded',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _uploaded == _docs.length
                                ? AppColors.green
                                : AppColors.orange,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: AppColors.lightBorder,
                            color: _uploaded == _docs.length
                                ? AppColors.green
                                : AppColors.orange,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onNext,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.lightSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.lightBorder),
                            ),
                            child: const Text(
                              'Save & Continue Later',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.lightSubText,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _OrangeCta(label: 'Submit →', onTap: _submit),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 5: Under Review ────────────────────────────────────────────────────
class _ReviewStep extends StatelessWidget {
  final VoidCallback onFinish;
  const _ReviewStep({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            children: [
              const Spacer(),
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.yellow.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.yellow.withValues(alpha: 0.30),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Text('⏳', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Application\nUnder Review',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We're verifying your documents. This usually takes 24-48 hours. We'll notify you via SMS when you're approved.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.darkSubText,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              // Steps card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Column(
                  children: [
                    _reviewRow('✓', 'Account created', 'Verified via phone', AppColors.green),
                    const SizedBox(height: 12),
                    _reviewRow('✓', 'Profile submitted', '2 of 4 docs uploaded', AppColors.green),
                    const SizedBox(height: 12),
                    _reviewRow('⏳', 'Document review', 'In progress · ~24hrs', AppColors.yellow),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: 0.4,
                      child: _reviewRow('🚀', 'Ready to deliver', 'Awaiting approval', AppColors.darkSubText),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _OrangeCta(
                label: '📤 Upload Remaining Docs',
                onTap: onFinish,
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onFinish,
                child: RichText(
                  text: const TextSpan(
                    text: 'Questions? ',
                    style: TextStyle(fontSize: 11, color: AppColors.darkSubText),
                    children: [
                      TextSpan(
                        text: 'Contact Support',
                        style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewRow(String icon, String title, String sub, Color color) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              Text(
                sub,
                style: TextStyle(fontSize: 10, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────
// ─── Social auth buttons ──────────────────────────────────────────────────────
class _SocialBtn extends StatelessWidget {
  final String label;
  final Widget logo;
  final VoidCallback? onTap;
  const _SocialBtn({required this.label, required this.logo, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            logo,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Google "G" logo painted with official colors
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 18),
      painter: _GooglePainter(),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Blue arc (right)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -0.3,
      2.0,
      false,
      Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.stroke..strokeWidth = size.width * 0.22,
    );
    // Red arc (top-left)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      3.7,
      1.6,
      false,
      Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.stroke..strokeWidth = size.width * 0.22,
    );
    // Yellow arc (bottom-left)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      2.2,
      1.5,
      false,
      Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.stroke..strokeWidth = size.width * 0.22,
    );
    // Green arc (bottom)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      1.2,
      1.0,
      false,
      Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.stroke..strokeWidth = size.width * 0.22,
    );
    // Horizontal bar (the G bar)
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - size.height * 0.13, r, size.height * 0.26),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GooglePainter _) => false;
}

// Apple  logo
class _AppleLogo extends StatelessWidget {
  const _AppleLogo();
  @override
  Widget build(BuildContext context) {
    return const Text('', style: TextStyle(fontSize: 17, color: AppColors.darkText));
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final int step, total;
  const _Header({required this.onBack, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: const Center(
                    child: Text('←',
                        style: TextStyle(fontSize: 16, color: AppColors.darkText)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.orangeTintDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Step $step of $total',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(total, (i) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i < step ? AppColors.orange : AppColors.darkCard,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _HeaderLight extends StatelessWidget {
  final VoidCallback onBack;
  final int step, total;
  const _HeaderLight({required this.onBack, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.lightBorder),
                  ),
                  child: const Center(
                    child: Text('←',
                        style: TextStyle(fontSize: 16, color: AppColors.lightText)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: List.generate(total, (i) {
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i < step ? AppColors.orange : const Color(0xFFDDDDDD),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$step of $total',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lightSubText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrangeCta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OrangeCta({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.orangeLight, AppColors.orangeDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withValues(alpha: 0.30),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
