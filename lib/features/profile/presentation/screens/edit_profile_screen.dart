import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neon_border_container.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/services/profile_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> user; // Pass current user data

  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  File? _selectedImage;
  bool _isLoading = false;
  Object? _error;
  final _profileService = ProfileService();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name']);
    _usernameController = TextEditingController(
      text: widget.user['username'] ?? '',
    );
    _bioController = TextEditingController(text: widget.user['bio'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
        });
        // Only show snackbar for non-validation errors
        if (e is! ValidationException) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error picking image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String? _getFieldError(String field) {
    if (_error == null) return null;
    if (_error is ValidationException) {
      final errors = (_error as ValidationException).errors;
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

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      // Upload image first if selected
      if (_selectedImage != null) {
        await _profileService.uploadProfileImage(_selectedImage!.path);
      }

      // Update profile data
      await _profileService.updateProfile(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
      );

      // Refetch user data to get correct avatar URL after upload
      final currentUser = await _profileService.getCurrentUser();

      // Update auth state with refreshed user data
      if (mounted) {
        setState(() {
          _error = null;
        });

        ref.read(authControllerProvider.notifier).updateUser(currentUser);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.neonCyan,
          ),
        );

        Navigator.pop(context, currentUser);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
        });
        // Only show snackbar for non-validation errors
        if (e is! ValidationException) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating profile: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepVoid,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    "EDIT PROFILE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: AppColors.neonCyan.withOpacity(0.8),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.neonPink,
                              ),
                            ),
                          )
                        : const Text(
                            "Save",
                            style: TextStyle(
                              color: AppColors.neonPink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Avatar Picker
                    Stack(
                      children: [
                        NeonBorderContainer(
                          shape: BoxShape.circle,
                          borderWidth: 3,
                          padding: const EdgeInsets.all(4),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!) as ImageProvider
                                : NetworkImage(
                                    widget.user['avatar'] ??
                                        'https://via.placeholder.com/150',
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isLoading ? null : _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.neonPink,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Name Field
                    _buildLabel("Display Name"),
                    const SizedBox(height: 8),
                    _buildGlassTextField(
                      _nameController,
                      "Enter your name",
                      errorText: _getFieldError('name'),
                    ),

                    const SizedBox(height: 24),

                    // Username Field
                    _buildLabel("Username"),
                    const SizedBox(height: 8),
                    _buildGlassTextField(
                      _usernameController,
                      "Enter username",
                      errorText: _getFieldError('username'),
                    ),

                    const SizedBox(height: 24),

                    // Bio Field
                    _buildLabel("Bio"),
                    const SizedBox(height: 8),
                    _buildGlassTextField(
                      _bioController,
                      "Enter a short bio",
                      maxLines: 4,
                      errorText: _getFieldError('bio'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildGlassTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText != null
                  ? Colors.red
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
