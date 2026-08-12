import 'package:flutter/foundation.dart';

/// App-wide privacy mode toggle (session only, resets on app restart).
class PrivacyModeService {
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
}