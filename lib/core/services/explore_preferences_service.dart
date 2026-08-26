import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys for every independently toggleable / reorderable Explore section.
/// "Investment Themes" and the search bar are not included here -- they are
/// always shown, matching the original Explore screen behaviour.
const List<String> kExploreSectionKeys = [
  'stocks',
  'world_markets',
  'sector_performance',
  'crypto',
  'learn',
  'news',
];

/// Display labels for the section keys above, used by the Customize screen.
const Map<String, String> kExploreSectionLabels = {
  'stocks': 'Stocks',
  'world_markets': 'World Markets',
  'sector_performance': 'Sector Performance',
  'crypto': 'Crypto',
  'learn': 'Learn',
  'news': 'News',
};

const List<String> kValidStockTabs = ['active', 'gainers', 'losers', 'ipo'];
const List<String> kValidNewsTabs = ['overview', 'portfolio', 'watchlists'];
const List<String> kValidNewsPreferences = ['all', 'portfolio', 'watchlists'];

/// All Explore-screen personalization settings, immutable + copy-with.
@immutable
class ExplorePreferences {
  final Set<String> selectedThemes; // keys from the sector-groups map; empty == show all
  final Map<String, bool> sectionsEnabled; // kExploreSectionKeys -> on/off
  final List<String> sectionOrder; // ordering over kExploreSectionKeys
  final String newsPreference; // all | portfolio | watchlists
  final String defaultStockTab; // active | gainers | losers | ipo
  final String defaultNewsTab; // overview | portfolio | watchlists

  const ExplorePreferences({
    required this.selectedThemes,
    required this.sectionsEnabled,
    required this.sectionOrder,
    required this.newsPreference,
    required this.defaultStockTab,
    required this.defaultNewsTab,
  });

  factory ExplorePreferences.defaults() => ExplorePreferences(
        selectedThemes: const <String>{},
        sectionsEnabled: {for (final k in kExploreSectionKeys) k: true},
        sectionOrder: List<String>.from(kExploreSectionKeys),
        newsPreference: 'all',
        defaultStockTab: 'active',
        defaultNewsTab: 'overview',
      );

  bool isSectionEnabled(String key) => sectionsEnabled[key] ?? true;

  ExplorePreferences copyWith({
    Set<String>? selectedThemes,
    Map<String, bool>? sectionsEnabled,
    List<String>? sectionOrder,
    String? newsPreference,
    String? defaultStockTab,
    String? defaultNewsTab,
  }) {
    return ExplorePreferences(
      selectedThemes: selectedThemes ?? this.selectedThemes,
      sectionsEnabled: sectionsEnabled ?? this.sectionsEnabled,
      sectionOrder: sectionOrder ?? this.sectionOrder,
      newsPreference: newsPreference ?? this.newsPreference,
      defaultStockTab: defaultStockTab ?? this.defaultStockTab,
      defaultNewsTab: defaultNewsTab ?? this.defaultNewsTab,
    );
  }

  Map<String, dynamic> toJson() => {
        'selectedThemes': selectedThemes.toList(),
        'sectionsEnabled': sectionsEnabled,
        'sectionOrder': sectionOrder,
        'newsPreference': newsPreference,
        'defaultStockTab': defaultStockTab,
        'defaultNewsTab': defaultNewsTab,
      };

  /// Builds preferences from a decoded JSON map, silently repairing anything
  /// missing, malformed, or out of date (e.g. an older save missing a newly
  /// added section key) instead of throwing. Always yields a usable result.
  factory ExplorePreferences.fromJson(Map<String, dynamic> json) {
    final defaults = ExplorePreferences.defaults();

    final rawThemes = json['selectedThemes'];
    final selectedThemes = rawThemes is List ? rawThemes.map((e) => e.toString()).toSet() : defaults.selectedThemes;

    final rawEnabled = json['sectionsEnabled'];
    final sectionsEnabled = <String, bool>{};
    for (final key in kExploreSectionKeys) {
      final value = rawEnabled is Map ? rawEnabled[key] : null;
      sectionsEnabled[key] = value is bool ? value : true;
    }

    final rawOrder = json['sectionOrder'];
    List<String> sectionOrder;
    if (rawOrder is List) {
      final cleaned = rawOrder.map((e) => e.toString()).where(kExploreSectionKeys.contains).toSet().toList();
      // Reconcile: keep known order, then append any valid keys missing from
      // the saved list (covers app updates that add new sections).
      final missing = kExploreSectionKeys.where((k) => !cleaned.contains(k));
      sectionOrder = [...cleaned, ...missing];
    } else {
      sectionOrder = List<String>.from(defaults.sectionOrder);
    }
    if (sectionOrder.isEmpty) sectionOrder = List<String>.from(defaults.sectionOrder);

    final newsPreference = kValidNewsPreferences.contains(json['newsPreference']) ? json['newsPreference'] as String : defaults.newsPreference;
    final defaultStockTab = kValidStockTabs.contains(json['defaultStockTab']) ? json['defaultStockTab'] as String : defaults.defaultStockTab;
    final defaultNewsTab = kValidNewsTabs.contains(json['defaultNewsTab']) ? json['defaultNewsTab'] as String : defaults.defaultNewsTab;

    return ExplorePreferences(
      selectedThemes: selectedThemes,
      sectionsEnabled: sectionsEnabled,
      sectionOrder: sectionOrder,
      newsPreference: newsPreference,
      defaultStockTab: defaultStockTab,
      defaultNewsTab: defaultNewsTab,
    );
  }
}

/// Loads/saves [ExplorePreferences] using the app's existing local storage
/// mechanism (`flutter_secure_storage`, already a dependency used for the
/// auth token in [ApiService]) -- no new package introduced. Exposes a
/// [ValueNotifier] so the Explore screen can react immediately after Save
/// without a manual reload plumbing dance.
class ExplorePreferencesService {
  ExplorePreferencesService._internal();
  static final ExplorePreferencesService instance = ExplorePreferencesService._internal();

  static const _storageKey = 'explore_preferences';
  static const _storage = FlutterSecureStorage();

  final ValueNotifier<ExplorePreferences> current = ValueNotifier<ExplorePreferences>(ExplorePreferences.defaults());
  bool _loaded = false;

  /// Loads preferences from disk on first call; subsequent calls return the
  /// already-loaded value so the Explore screen doesn't re-read storage on
  /// every pull-to-refresh.
  Future<ExplorePreferences> load() async {
    if (_loaded) return current.value;
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          current.value = ExplorePreferences.fromJson(decoded);
        }
      }
    } catch (_) {
      // Corrupt/unreadable save data -- fall back to defaults rather than
      // crashing Explore.
      current.value = ExplorePreferences.defaults();
    }
    _loaded = true;
    return current.value;
  }

  Future<void> save(ExplorePreferences prefs) async {
    current.value = prefs;
    _loaded = true;
    try {
      await _storage.write(key: _storageKey, value: jsonEncode(prefs.toJson()));
    } catch (_) {
      // Persistence failed silently -- in-memory value still applies for
      // this session, matching the app's existing best-effort storage style.
    }
  }

  Future<ExplorePreferences> reset() async {
    final defaults = ExplorePreferences.defaults();
    await save(defaults);
    return defaults;
  }
}
