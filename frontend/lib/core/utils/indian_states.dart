class IndianStates {
  static const Map<String, String> codeToState = {
    '01': 'Jammu & Kashmir',
    '02': 'Himachal Pradesh',
    '03': 'Punjab',
    '04': 'Chandigarh',
    '05': 'Uttarakhand',
    '06': 'Haryana',
    '07': 'Delhi',
    '08': 'Rajasthan',
    '09': 'Uttar Pradesh',
    '10': 'Bihar',
    '11': 'Sikkim',
    '12': 'Arunachal Pradesh',
    '13': 'Nagaland',
    '14': 'Manipur',
    '15': 'Mizoram',
    '16': 'Tripura',
    '17': 'Meghalaya',
    '18': 'Assam',
    '19': 'West Bengal',
    '20': 'Jharkhand',
    '21': 'Odisha',
    '22': 'Chhattisgarh',
    '23': 'Madhya Pradesh',
    '24': 'Gujarat',
    '26': 'Dadra & Nagar Haveli and Daman & Diu',
    '27': 'Maharashtra',
    '29': 'Karnataka',
    '30': 'Goa',
    '31': 'Lakshadweep',
    '32': 'Kerala',
    '33': 'Tamil Nadu',
    '34': 'Puducherry',
    '35': 'Andaman & Nicobar Islands',
    '36': 'Telangana',
    '37': 'Andhra Pradesh',
    '38': 'Ladakh',
  };

  static const List<String> allStates = [
    'Gujarat',
    'Maharashtra',
    'Rajasthan',
    'Madhya Pradesh',
    'Karnataka',
    'Delhi',
    'Haryana',
    'Punjab',
    'Uttar Pradesh',
    'Tamil Nadu',
    'Telangana',
    'Andhra Pradesh',
    'West Bengal',
    'Kerala',
    'Goa',
    'Bihar',
    'Odisha',
    'Jharkhand',
    'Chhattisgarh',
    'Assam',
    'Uttarakhand',
    'Himachal Pradesh',
    'Chandigarh',
    'Jammu & Kashmir',
    'Puducherry',
  ];

  static String? getStateFromGst(String? gst) {
    if (gst == null) return null;
    final trimmed = gst.trim();
    if (trimmed.length >= 2) {
      final code = trimmed.substring(0, 2);
      if (codeToState.containsKey(code)) {
        return codeToState[code];
      }
    }
    return null;
  }

  static String? getCodeFromState(String? stateName) {
    if (stateName == null) return null;
    final lower = stateName.trim().toLowerCase();
    for (final entry in codeToState.entries) {
      if (entry.value.toLowerCase() == lower) {
        return entry.key;
      }
    }
    if (lower == 'gujarat') return '24';
    if (lower == 'maharashtra') return '27';
    if (lower == 'rajasthan') return '08';
    if (lower == 'madhya pradesh') return '23';
    if (lower == 'karnataka') return '29';
    if (lower == 'delhi') return '07';
    return null;
  }

  static String? detectStateFromAddress(String? address) {
    if (address == null || address.trim().isEmpty) return null;
    final lower = address.trim().toLowerCase();

    // Maharashtra cities & regions
    if (lower.contains('pune') ||
        lower.contains('mumbai') ||
        lower.contains('thane') ||
        lower.contains('nagpur') ||
        lower.contains('nashik') ||
        lower.contains('navi mumbai') ||
        lower.contains('aurangabad') ||
        lower.contains('kolhapur') ||
        lower.contains('solapur') ||
        lower.contains('maharashtra')) {
      return 'Maharashtra';
    }

    // Gujarat cities & regions
    if (lower.contains('ahmedabad') ||
        lower.contains('surat') ||
        lower.contains('vadodara') ||
        lower.contains('baroda') ||
        lower.contains('rajkot') ||
        lower.contains('gandhinagar') ||
        lower.contains('bhavnagar') ||
        lower.contains('jamnagar') ||
        lower.contains('anand') ||
        lower.contains('morbi') ||
        lower.contains('gujarat')) {
      return 'Gujarat';
    }

    // Karnataka
    if (lower.contains('bengaluru') || lower.contains('bangalore') || lower.contains('karnataka')) {
      return 'Karnataka';
    }

    // Delhi
    if (lower.contains('delhi') || lower.contains('new delhi')) {
      return 'Delhi';
    }

    // Rajasthan
    if (lower.contains('jaipur') || lower.contains('jodhpur') || lower.contains('udaipur') || lower.contains('rajasthan')) {
      return 'Rajasthan';
    }

    // Madhya Pradesh
    if (lower.contains('indore') || lower.contains('bhopal') || lower.contains('gwalior') || lower.contains('madhya pradesh')) {
      return 'Madhya Pradesh';
    }

    // West Bengal
    if (lower.contains('kolkata') || lower.contains('calcutta') || lower.contains('west bengal')) {
      return 'West Bengal';
    }

    // Tamil Nadu
    if (lower.contains('chennai') || lower.contains('madras') || lower.contains('coimbatore') || lower.contains('tamil nadu')) {
      return 'Tamil Nadu';
    }

    // Telangana
    if (lower.contains('hyderabad') || lower.contains('secunderabad') || lower.contains('telangana')) {
      return 'Telangana';
    }

    return null;
  }

  static bool isGujarat(String? stateOrCode) {
    if (stateOrCode == null) return true; // default seller home state
    final trimmed = stateOrCode.trim().toLowerCase();
    return trimmed == 'gujarat' || trimmed == '24';
  }
}
