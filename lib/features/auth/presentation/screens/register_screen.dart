import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:test_flutter/core/errors/exceptions.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  Object? _error; // Local error state
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  String? _getFieldError(Object? error, String field) {
    if (error == null) return null;
    if (error is ValidationException) {
      final errors = error.errors;
      if (errors.containsKey(field)) {
        final fieldErrors = errors[field];
        if (fieldErrors is List && fieldErrors.isNotEmpty) {
          return fieldErrors.first.toString();
        } else if (fieldErrors is String) {
          return fieldErrors;
        }
      }
    }
    return null;
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final message = await ref
          .read(authControllerProvider.notifier)
          .register(
            _nameController.text,
            _emailController.text,
            _passwordController.text,
            _passwordConfirmationController.text,
          );

      if (mounted) {
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.neonCyan,
            ),
          );
        }
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
        });
        if (e is! ValidationException) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
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
    // Listen only for successful login (optional, if we want to be sure)
    // Actually, since register() awaits, we handled success in the try block.
    // But keeping the listener for success is harmless if we check for data.
    // However, we removed the error handling from here.
    ref.listen(authControllerProvider, (previous, next) {
      // We only care about success here, but our await handles it too.
      // Let's rely on the await for flow control to keep it simple and local.
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 68),
              Hero(
                tag: 'app_logo',
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      FontAwesomeIcons.tiktok,
                      size: 80,
                      color: Colors.white,
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign up for GV Live',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a profile, follow other accounts, \nmake your own videos, and more.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              AuthTextField(
                controller: _nameController,
                hintText: 'Full Name',
                icon: Icons.person_outline,
                errorText: _getFieldError(_error, 'name'),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _emailController,
                hintText: 'Email',
                keyboardType: TextInputType.emailAddress,
                icon: Icons.email_outlined,
                errorText: _getFieldError(_error, 'email'),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _passwordController,
                hintText: 'Password',
                isObscure: true,
                icon: Icons.lock_outline,
                errorText: _getFieldError(_error, 'password'),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _passwordConfirmationController,
                hintText: 'Confirm Password',
                isObscure: true,
                icon: Icons.lock_outline,
                errorText: _getFieldError(_error, 'password_confirmation'),
              ),
              const SizedBox(height: 24),
              AuthButton(
                text: 'Sign up',
                onPressed: _isLoading ? null : _register,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Already have an account? ",
                    style: TextStyle(color: Colors.grey),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Log in',
                      style: TextStyle(
                        color: AppColors.neonPink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
