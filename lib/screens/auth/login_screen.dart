import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:galaxy_truck/services/auth_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:galaxy_truck/models/user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final authService = context.read<AuthService>();
    final success = await authService.login(
        _emailController.text.trim(), _passwordController.text);
    if (!mounted) return;
    if (success) {
      final role = await authService.refreshCurrentUserFromFirestore();
      if (!mounted) return;
      if (role == UserRole.admin) { context.go('/admin/dashboard'); return; }
      if (role == UserRole.driver) { context.go('/driver/dashboard'); return; }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account role is not assigned. Please contact admin.')));
      setState(() => _isLoading = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid credentials')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      body: isWide ? _buildWide(context) : _buildNarrow(context),
    );
  }

  Widget _buildWide(BuildContext context) {
    return Row(children: [
      Expanded(flex: 5, child: _buildBrandPanel()),
      Expanded(
        flex: 4,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _buildFormContent(context),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildNarrow(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF0D1F38)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _buildLogo(light: true),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  )],
                ),
                child: _buildFormContent(context),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF0D1F38)],
        ),
      ),
      child: Stack(children: [
        Positioned(top: -80, left: -80,
          child: _circle(300, const Color(0xFFFF6B35), 0.07)),
        Positioned(bottom: -100, right: -100,
          child: _circle(400, const Color(0xFFFF6B35), 0.05)),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 60),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(light: true),
                const SizedBox(height: 48),
                const _FeatureBullet(icon: Icons.gps_fixed_rounded,       label: 'Live GPS Fleet Tracking'),
                const _FeatureBullet(icon: Icons.assignment_turned_in_rounded, label: 'Smart Rental Approvals'),
                const _FeatureBullet(icon: Icons.build_circle_rounded,    label: 'Maintenance Management'),
                const _FeatureBullet(icon: Icons.bar_chart_rounded,       label: 'Fleet Analytics & Reports'),
                const SizedBox(height: 48),
                const Text(
                  '"Powering Australia's\nfleet forward."',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _circle(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );

  Widget _buildLogo({bool light = false}) {
    return Column(children: [
      Container(
        width: 76, height: 76,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF9565)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )],
        ),
        child: const Icon(Icons.local_shipping_rounded, size: 42, color: Colors.white),
      ),
      const SizedBox(height: 14),
      Text('Galaxy Truck', style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: light ? Colors.white : const Color(0xFFFF6B35),
      )),
      const SizedBox(height: 4),
      Text('FLEET MANAGEMENT', style: TextStyle(
        fontSize: 11,
        letterSpacing: 2.5,
        fontWeight: FontWeight.w600,
        color: light ? Colors.white38 : Colors.grey.shade500,
      )),
    ]);
  }

  Widget _buildFormContent(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Welcome back',
          style: context.textStyles.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Sign in to your account',
          style: context.textStyles.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        _buildField(context,
          controller: _emailController,
          label: 'Email address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Email is required';
            if (!v.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildField(context,
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _isLoading
                  ? null
                  : const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF9260)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _isLoading ? [] : [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withOpacity(0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Sign In', style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  )),
            ),
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: _isLoading ? null : () => context.push('/register'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.4)),
          ),
          child: const Text('Create Driver Account'),
        ),
      ]),
    );
  }

  TextFormField _buildField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: cs.onSurfaceVariant),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.25))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 1.5)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error)),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error, width: 1.5)),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureBullet({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withOpacity(0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFFF6B35), size: 17),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(
          color: Colors.white,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        )),
      ]),
    );
  }
}
