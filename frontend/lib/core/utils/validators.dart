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

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? mobile(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim().length < 8) {
      return 'Enter a valid phone number';
    }
    return null;
  }
}
