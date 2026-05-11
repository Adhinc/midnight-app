import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/theme.dart';
import '../../../core/validators.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _profilePicUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPic = false;
  List<String> _selectedLanguages = [];
  final List<String> _allLanguages = [
    'English',
    'Hindi',
    'Malayalam',
    'Tamil',
    'Telugu',
    'Kannada',
    'Bengali',
    'Marathi',
    'Gujarati',
  ];

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
        _selectedLanguages = List<String>.from(data['languages'] ?? ['English']);
        if (_selectedLanguages.isEmpty) _selectedLanguages = ['English'];
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
        imageQuality: 70,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to open image picker: $e")),
        );
      }
      return;
    }

    if (pickedFile == null) return;
    
    // File Size Validation (Max 5MB)
    final bytes = await pickedFile.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Image size must be less than 5MB")),
        );
      }
      return;
    }

    setState(() => _isUploadingPic = true);

    try {
      // Use unique filename to prevent cache/corruption issues
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/$uid/$fileName');

      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profilePicUrl': downloadUrl,
      });

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to upload image: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPic = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one language")));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    setState(() => _isSaving = true);
    final handle = _nameController.text.trim();

    try {
      // Handle Uniqueness Check (if changed)
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final currentHandle = doc.data()?['handle'];
      
      if (handle != currentHandle) {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('handle', isEqualTo: handle)
            .limit(1)
            .get();
        
        if (query.docs.isNotEmpty) {
          throw "Handle already taken. Please choose another one.";
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'handle': handle,
        'bio': _bioController.text.trim(),
        'languages': _selectedLanguages,
        'profilePicUrl': _profilePicUrl, // Sync URL
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('handle', handle);
      if (_profilePicUrl != null) await prefs.setString('profilePicUrl', _profilePicUrl!);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
        title: const Text("Edit Profile", style: TextStyle(color: Colors.white)),
        leading: const BackButton(color: Colors.white),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: MidnightTheme.primaryColor)),
                )
              : TextButton(
                  onPressed: _saveProfile,
                  child: const Text("Save", style: TextStyle(color: MidnightTheme.primaryColor, fontSize: 16)),
                ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: MidnightTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                children: [
                  GestureDetector(
                    onTap: _isUploadingPic ? null : _pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: MidnightTheme.surfaceColor,
                          backgroundImage: _profilePicUrl != null && _profilePicUrl!.isNotEmpty ? NetworkImage(_profilePicUrl!) : null,
                          child: _isUploadingPic
                              ? const CircularProgressIndicator(color: MidnightTheme.primaryColor)
                              : (_profilePicUrl == null || _profilePicUrl!.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.white) : null),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: MidnightTheme.primaryColor, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField("Username / Handle", _nameController, maxLength: 20, validator: Validators.handle),
                  const SizedBox(height: 24),
                  _buildTextField("Bio", _bioController, maxLines: 4, maxLength: 200, validator: Validators.bio),
                  const SizedBox(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Spoken Languages", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allLanguages.map((lang) {
                      final isSelected = _selectedLanguages.contains(lang);
                      return FilterChip(
                        label: Text(lang),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedLanguages.add(lang);
                            } else {
                              if (_selectedLanguages.length > 1) {
                                _selectedLanguages.remove(lang);
                              }
                            }
                          });
                        },
                        backgroundColor: MidnightTheme.surfaceColor,
                        selectedColor: MidnightTheme.primaryColor.withOpacity(0.2),
                        checkmarkColor: MidnightTheme.primaryColor,
                        labelStyle: TextStyle(color: isSelected ? MidnightTheme.primaryColor : Colors.white),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? MidnightTheme.primaryColor : Colors.white.withOpacity(0.1))),
                      );
                    }).toList(),
                  ),
                ],
              ),
              ),
            ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, int? maxLength, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: MidnightTheme.surfaceColor,
            counterStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MidnightTheme.primaryColor)),
          ),
        ),
      ],
    );
  }
}
