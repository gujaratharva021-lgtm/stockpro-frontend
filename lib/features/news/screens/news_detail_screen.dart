import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

Uint8List _decodeImage(dynamic imageUrl) {
  try {
    final str = imageUrl.toString();
    final base64Str = str.contains(',') ? str.split(',').last : str;
    return base64Decode(base64Str);
  } catch (_) {
    return Uint8List(0);
  }
}

class NewsDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  const NewsDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final hasImage = (item['image_url'] ?? '').toString().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'News',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          color: AppColors.border.withOpacity(0.3),
                          child: Image.memory(
                            _decodeImage(item['image_url']),
                            width: double.infinity,
                            fit: BoxFit.fitWidth,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    if (hasImage) const SizedBox(height: 20),
                    Text(
                      item['title'] ?? '',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold, height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          item['source'] ?? '',
                          style: const TextStyle(color: AppColors.primaryDark, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (item['published_at'] ?? '').toString().split('T').first,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      item['content'] ?? '',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}