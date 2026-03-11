class Validators {
  static final _emailRegex = RegExp(r'^[\w\.\-\+]+@[\w\.\-]+\.\w{2,}$');
  static final _handleRegex = RegExp(r'^[a-zA-Z0-9_]+$');
  static final _upiRegex = RegExp(r'^[\w\.\-]+@[\w]+$');
  static final _ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
  static final _accountNumberRegex = RegExp(r'^\d{9,18}$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain an uppercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain a number';
    return null;
  }

  static String? handle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Handle is required';
    final trimmed = value.trim();
    if (trimmed.length < 3) return 'Must be at least 3 characters';
    if (trimmed.length > 20) return 'Must be 20 characters or less';
    if (!_handleRegex.hasMatch(trimmed)) return 'Only letters, numbers, and underscores';
    return null;
  }

  static String? bio(String? value) {
    if (value != null && value.length > 200) return 'Bio must be 200 characters or less';
    return null;
  }

  static String? upiId(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    if (!_upiRegex.hasMatch(value.trim())) return 'Invalid UPI ID (e.g., user@okaxis)';
    return null;
  }

  static String? ifscCode(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    if (!_ifscRegex.hasMatch(value.trim().toUpperCase())) return 'Invalid IFSC (e.g., SBIN0001234)';
    return null;
  }

  static String? accountNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    if (!_accountNumberRegex.hasMatch(value.trim())) return 'Invalid account number (9-18 digits)';
    return null;
  }
}
