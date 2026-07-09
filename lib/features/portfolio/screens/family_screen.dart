import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/services/family_service.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  void _showAddDialog() {
    final nameController = TextEditingController();
    final relationController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Family Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: relationController, decoration: const InputDecoration(labelText: 'Relation (e.g. Spouse, Parent)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              FamilyService().addMember(nameController.text, relationController.text);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = FamilyService().members;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Family', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
        ],
      ),
      body: members.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline, color: AppColors.textMuted, size: 40),
                    const SizedBox(height: 12),
                    const Text('No family members added', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text('Added members are kept for this session only', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _showAddDialog,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Add Member', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final m = members[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                        child: Center(child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(m.relation, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                        onPressed: () => setState(() => FamilyService().removeMember(m.id)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}