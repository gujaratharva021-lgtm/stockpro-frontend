import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/services/explore_preferences_service.dart';

/// Investment theme names, kept in one place so this screen doesn't need to
/// import the sector-quote data (and its Dio/API wiring) that lives on the
/// Explore screen -- just the theme labels are needed here.
const List<String> kInvestmentThemeNames = [
  'Banking',
  'IT',
  'Energy & Oil',
  'FMCG',
  'Auto',
  'Pharma',
  'Metals & Mining',
  'Infra & Cement',
  'Financial Services',
  'Power & Utilities',
  'Telecom',
  'New Age Tech',
];

/// Lets the user personalize the Explore screen: which investment themes to
/// surface, which sections are visible and in what order, the default
/// stock/news tabs, and the news preference. Saving persists immediately via
/// [ExplorePreferencesService] and pops back to Explore so it can re-apply.
class CustomizeExploreScreen extends StatefulWidget {
  const CustomizeExploreScreen({super.key});

  @override
  State<CustomizeExploreScreen> createState() => _CustomizeExploreScreenState();
}

class _CustomizeExploreScreenState extends State<CustomizeExploreScreen> {
  late Set<String> _selectedThemes;
  late Map<String, bool> _sectionsEnabled;
  late List<String> _sectionOrder;
  late String _newsPreference;
  late String _defaultStockTab;
  late String _defaultNewsTab;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final prefs = await ExplorePreferencesService.instance.load();
    if (!mounted) return;
    setState(() {
      _selectedThemes = Set<String>.from(prefs.selectedThemes);
      _sectionsEnabled = Map<String, bool>.from(prefs.sectionsEnabled);
      _sectionOrder = List<String>.from(prefs.sectionOrder);
      _newsPreference = prefs.newsPreference;
      _defaultStockTab = prefs.defaultStockTab;
      _defaultNewsTab = prefs.defaultNewsTab;
      _loading = false;
    });
  }

  void _applyDefaultsToState(ExplorePreferences defaults) {
    setState(() {
      _selectedThemes = Set<String>.from(defaults.selectedThemes);
      _sectionsEnabled = Map<String, bool>.from(defaults.sectionsEnabled);
      _sectionOrder = List<String>.from(defaults.sectionOrder);
      _newsPreference = defaults.newsPreference;
      _defaultStockTab = defaults.defaultStockTab;
      _defaultNewsTab = defaults.defaultNewsTab;
    });
  }

  Future<void> _handleReset() async {
    final defaults = await ExplorePreferencesService.instance.reset();
    if (!mounted) return;
    _applyDefaultsToState(defaults);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Explore reset to default')));
  }

  Future<void> _handleSave() async {
    final prefs = ExplorePreferences(
      selectedThemes: _selectedThemes,
      sectionsEnabled: _sectionsEnabled,
      sectionOrder: _sectionOrder,
      newsPreference: _newsPreference,
      defaultStockTab: _defaultStockTab,
      defaultNewsTab: _defaultNewsTab,
    );
    await ExplorePreferencesService.instance.save(prefs);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text('Customize Explore', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _loading ? null : _handleReset,
            child: const Text('Reset', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                _sectionTitle('Investment Themes'),
                _themePicker(),
                const SizedBox(height: 24),
                _sectionTitle('Section Order & Visibility'),
                _hint('Drag to reorder. Turn off any section to hide it from Explore.'),
                const SizedBox(height: 8),
                _sectionReorderList(),
                const SizedBox(height: 24),
                _sectionTitle('News Preference'),
                _choiceRow(
                  options: const [('All', 'all'), ('Portfolio', 'portfolio'), ('Watchlists', 'watchlists')],
                  value: _newsPreference,
                  onSelected: (v) => setState(() => _newsPreference = v),
                ),
                const SizedBox(height: 24),
                _sectionTitle('Default Stock Tab'),
                _choiceRow(
                  options: const [('Most Active', 'active'), ('Gainers', 'gainers'), ('Losers', 'losers'), ('IPOs', 'ipo')],
                  value: _defaultStockTab,
                  onSelected: (v) => setState(() => _defaultStockTab = v),
                ),
                const SizedBox(height: 24),
                _sectionTitle('Default News Tab'),
                _choiceRow(
                  options: const [('Overview', 'overview'), ('Portfolio', 'portfolio'), ('Watchlists', 'watchlists')],
                  value: _defaultNewsTab,
                  onSelected: (v) => setState(() => _defaultNewsTab = v),
                ),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15));
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
    );
  }

  Widget _themePicker() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: kInvestmentThemeNames.map((theme) {
          final selected = _selectedThemes.contains(theme);
          return FilterChip(
            label: Text(theme),
            selected: selected,
            onSelected: (value) {
              setState(() {
                if (value) {
                  _selectedThemes.add(theme);
                } else {
                  _selectedThemes.remove(theme);
                }
              });
            },
            showCheckmark: false,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.cardBackground,
            labelStyle: TextStyle(color: selected ? Colors.white : AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600),
            side: BorderSide(color: selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionReorderList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _sectionOrder.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final key = _sectionOrder.removeAt(oldIndex);
          _sectionOrder.insert(newIndex, key);
        });
      },
      itemBuilder: (ctx, index) {
        final key = _sectionOrder[index];
        final enabled = _sectionsEnabled[key] ?? true;
        final label = kExploreSectionLabels[key] ?? key;
        return Container(
          key: ValueKey(key),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Icon(Icons.drag_handle, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: TextStyle(color: enabled ? AppColors.textPrimary : AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13.5)),
            ),
            Switch(
              value: enabled,
              activeTrackColor: AppColors.primary,
              onChanged: (v) => setState(() => _sectionsEnabled[key] = v),
            ),
          ]),
        );
      },
    );
  }

  Widget _choiceRow({required List<(String, String)> options, required String value, required ValueChanged<String> onSelected}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final (label, val) = opt;
          final selected = value == val;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onSelected(val),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.cardBackground,
            labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
            side: BorderSide.none,
          );
        }).toList(),
      ),
    );
  }
}
