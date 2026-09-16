class Validators {
  Validators._();

  static String? requiredField(String? value, [String message = 'This field is required']) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? positiveNumber(String? value, [String message = 'Enter a valid number greater than 0']) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    final num = double.tryParse(value.trim());
    if (num == null || num <= 0) {
      return message;
    }
    return null;
  }

  static String? nonNegativeNumber(String? value, [String message = 'Enter a valid non-negative number']) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    final num = double.tryParse(value.trim());
    if (num == null || num < 0) {
      return message;
    }
    return null;
  }

  /// Optional email (valid format if provided)
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Required email validator
  static String? requiredEmail(String? value, [String message = 'Valid email address is required']) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return email(value);
  }

  /// Optional mobile number
  static String? mobile(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.length < 10 || cleaned.length > 15 || !RegExp(r'^\+?[0-9]{10,15}$').hasMatch(cleaned)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  /// Required mobile number
  static String? requiredMobile(String? value, [String message = 'Mobile number is required']) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return mobile(value);
  }

  /// Statutory 15-character GSTIN validator (e.g., 24AAATE1234F1Z5)
  static String? gst(String? value, [bool isRequired = true]) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'GST Number is required' : null;
    }
    final cleaned = value.trim().toUpperCase();
    final gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    if (!gstRegex.hasMatch(cleaned)) {
      return 'Enter valid 15-character GSTIN (e.g., 24AAATE1234F1Z5)';
    }
    return null;
  }

  /// Statutory 10-character PAN validator (e.g., AAATE1234F)
  static String? pan(String? value, [bool isRequired = true]) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'PAN Number is required' : null;
    }
    final cleaned = value.trim().toUpperCase();
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    if (!panRegex.hasMatch(cleaned)) {
      return 'Enter valid 10-character PAN (e.g., AAATE1234F)';
    }
    return null;
  }
}
