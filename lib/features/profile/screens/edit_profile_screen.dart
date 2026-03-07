import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _profilePicUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPic = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        _nameController.text = data['handle'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _profilePicUrl = data['profilePicUrl'];
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      _nameController.text = prefs.getString('handle') ?? '';
      _profilePicUrl = prefs.getString('profilePicUrl');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final picker = ImagePicker();
    XFile? pickedFile;

    try {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Supported on all platforms
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to open image picker: $e")),
        );
      }
      return;
    }

    if (pickedFile == null) return; // User canceled picking

    setState(() => _isUploadingPic = true);

    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'profile_pictures/$uid.jpg',
      );

      // Web-safe file upload using bytes
      final bytes = await pickedFile.readAsBytes();
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore immediately
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profilePicUrl': downloadUrl,
      });

      // Update SharedPrefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profilePicUrl', downloadUrl);

      if (mounted) {
        setState(() {
          _profilePicUrl = downloadUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to upload image: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPic = false);
    }
  }

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'handle': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('handle', _nameController.text.trim());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to save: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.white),
        ),
        leading: const BackButton(color: Colors.white),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MidnightTheme.primaryColor,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveProfile,
                  child: const Text(
                    "Save",
                    style: TextStyle(
                      color: MidnightTheme.primaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: MidnightTheme.primaryColor,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: MidnightTheme.surfaceColor,
                          backgroundImage:
                              _profilePicUrl != null &&
                                  _profilePicUrl!.isNotEmpty
                              ? NetworkImage(_profilePicUrl!)
                              : null,
                          child: _isUploadingPic
                              ? const CircularProgressIndicator(
                                  color: MidnightTheme.primaryColor,
                                )
                              : (_profilePicUrl == null ||
                                        _profilePicUrl!.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white,
                                      )
                                    : null),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: MidnightTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField("Username / Handle", _nameController),
                  const SizedBox(height: 24),
                  _buildTextField("Bio", _bioController, maxLines: 4),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: MidnightTheme.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: MidnightTheme.primaryColor),
            ),
          ),
        ),
      ],
    );
  }
}
