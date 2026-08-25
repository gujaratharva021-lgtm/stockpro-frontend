import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

/// Trading Presets -- lets the trader set defaults that other order
/// screens can read (default order type, default quantity, whether to
/// show a confirmation step before placing an order). These are kept
/// in-memory for the current app session; no backend endpoint exists yet
/// to persist them across restarts.
class TradingPresetsScreen extends StatefulWidget {
  const TradingPresetsScreen({super.key});

  @override
  State<TradingPresetsScreen> createState() => _TradingPresetsScreenState();
}

class _TradingPresetsScreenState extends State<TradingPresetsScreen> {
  String _defaultOrderType = 'Market';
  int _defaultQuantity = 1;
  bool _confirmBeforeOrder = true;

  void _saved() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trading presets updated for this session')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Trading Presets', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Customize Your Trade Defaults', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Default Order Type', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Pre-selected when you open the order screen', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _typeChip('Market'),
                    const SizedBox(width: 10),
                    _typeChip('Limit'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Default Quantity', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Starting quantity pre-filled on new orders', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stepperButton(Icons.remove, onTap: _defaultQuantity > 1 ? () => setState(() => _defaultQuantity--) : null),
                    Container(
                      width: 56,
                      alignment: Alignment.center,
                      child: Text('$_defaultQuantity', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    _stepperButton(Icons.add, onTap: () => setState(() => _defaultQuantity++)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: SwitchListTile(
              value: _confirmBeforeOrder,
              onChanged: (v) => setState(() => _confirmBeforeOrder = v),
              activeThumbColor: AppColors.primary,
              title: const Text('Confirm before placing order', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text('Show a review step before every order', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saved,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Preferences', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('Applies for this session only', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String label) {
    final selected = _defaultOrderType == label;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _defaultOrderType = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(color: selected ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _stepperButton(IconData icon, {required VoidCallback? onTap}) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: enabled ? AppColors.textPrimary : AppColors.textMuted, size: 18),
      ),
    );
  }
}
