import 'dart:ui';

/// Pre-built Instagram-style color filters using ColorFilter matrices.
/// These can be applied to images via ColorFiltered widget.
class NearfoFilters {
  static const String none = 'Normal';
  static const String clarendon = 'Clarendon';
  static const String gingham = 'Gingham';
  static const String moon = 'Moon';
  static const String lark = 'Lark';
  static const String reyes = 'Reyes';
  static const String juno = 'Juno';
  static const String slumber = 'Slumber';
  static const String aden = 'Aden';
  static const String perpetua = 'Perpetua';
  static const String ludwig = 'Ludwig';
  static const String valencia = 'Valencia';

  static List<String> get allNames => [
    none, clarendon, gingham, moon, lark, reyes,
    juno, slumber, aden, perpetua, ludwig, valencia,
  ];

  /// Get ColorFilter matrix for a given filter name
  static ColorFilter? getFilter(String name) {
    switch (name) {
      case 'Normal':
        return null; // No filter
      case 'Clarendon':
        return const ColorFilter.matrix(<double>[
          1.2, 0, 0, 0, 10,
          0, 1.2, 0, 0, 10,
          0, 0, 1.3, 0, 20,
          0, 0, 0, 1, 0,
        ]);
      case 'Gingham':
        return const ColorFilter.matrix(<double>[
          1.0, 0.1, 0.1, 0, 20,
          0.1, 1.0, 0.1, 0, 20,
          0.1, 0.1, 1.0, 0, 20,
          0, 0, 0, 1, 0,
        ]);
      case 'Moon':
        return const ColorFilter.matrix(<double>[
          0.33, 0.33, 0.33, 0, 10,
          0.33, 0.33, 0.33, 0, 10,
          0.33, 0.33, 0.33, 0, 10,
          0, 0, 0, 1, 0,
        ]);
      case 'Lark':
        return const ColorFilter.matrix(<double>[
          1.2, 0.1, 0, 0, 15,
          0, 1.1, 0, 0, 10,
          0, 0, 0.9, 0, -5,
          0, 0, 0, 1, 0,
        ]);
      case 'Reyes':
        return const ColorFilter.matrix(<double>[
          1.1, 0, 0, 0, 30,
          0, 1.0, 0, 0, 20,
          0, 0, 0.9, 0, 10,
          0, 0, 0, 0.9, 0,
        ]);
      case 'Juno':
        return const ColorFilter.matrix(<double>[
          1.3, 0, 0, 0, -10,
          0, 1.1, 0, 0, 0,
          0, 0, 0.8, 0, 20,
          0, 0, 0, 1, 0,
        ]);
      case 'Slumber':
        return const ColorFilter.matrix(<double>[
          0.9, 0.1, 0.1, 0, 15,
          0, 0.9, 0.1, 0, 10,
          0.1, 0, 0.9, 0, 20,
          0, 0, 0, 0.95, 0,
        ]);
      case 'Aden':
        return const ColorFilter.matrix(<double>[
          1.0, 0.1, 0, 0, 20,
          0, 1.0, 0.05, 0, 15,
          0, 0, 0.9, 0, 10,
          0, 0, 0, 0.9, 0,
        ]);
      case 'Perpetua':
        return const ColorFilter.matrix(<double>[
          1.05, 0, 0.1, 0, 10,
          0, 1.1, 0, 0, 15,
          0, 0.05, 1.0, 0, 20,
          0, 0, 0, 1, 0,
        ]);
      case 'Ludwig':
        return const ColorFilter.matrix(<double>[
          1.15, 0, 0, 0, -5,
          0, 1.05, 0, 0, 0,
          0, 0, 1.1, 0, 5,
          0, 0, 0, 1, 0,
        ]);
      case 'Valencia':
        return const ColorFilter.matrix(<double>[
          1.1, 0.1, 0, 0, 15,
          0, 1.0, 0.05, 0, 10,
          0, 0, 0.85, 0, 5,
          0, 0, 0, 1, 0,
        ]);
      default:
        return null;
    }
  }
}
