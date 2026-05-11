class Validators {
  static final _emailRegex = RegExp(r'^[\w\.\-\+]+@[\w\.\-]+\.\w{2,}$');
  static final _handleRegex = RegExp(r'^[a-zA-Z0-9_]+$');
  // Fixed: Allow dots in bank handle (e.g. user@ok.axis)
  static final _upiRegex = RegExp(r'^[\w\.\-]+@[\w\.]+$');
  // Fixed: Case insensitive IFSC regex (handled in validation logic)
  static final _ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$', caseSensitive: false);
  static final _accountNumberRegex = RegExp(r'^\d{9,18}$');

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
    if (value == null || value.trim().isEmpty) return null; // Optional if bank details provided
    if (!_upiRegex.hasMatch(value.trim())) return 'Invalid UPI ID (e.g., user@okaxis)';
    return null;
  }

  static String? ifscCode(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    if (!_ifscRegex.hasMatch(value.trim())) return 'Invalid IFSC (e.g., SBIN0001234)';
    return null;
  }

  static String? accountNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    if (!_accountNumberRegex.hasMatch(value.trim())) return 'Invalid account number (9-18 digits)';
    return null;
  }
}
