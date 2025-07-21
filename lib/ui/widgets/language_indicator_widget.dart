import 'package:flutter/material.dart';

/// Language indicator widget showing current language and allowing manual override
class LanguageIndicatorWidget extends StatelessWidget {
  final String currentLanguage;
  final Function(String) onLanguageChange;

  const LanguageIndicatorWidget({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChange,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: currentLanguage,
      onSelected: onLanguageChange,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'en',
          child: Row(
            children: [
              Text('🇺🇸'),
              SizedBox(width: 8),
              Text('English'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'vi',
          child: Row(
            children: [
              Text('🇻🇳'),
              SizedBox(width: 8),
              Text('Vietnamese'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_getLanguageFlag(currentLanguage)),
            const SizedBox(width: 4),
            Text(
              _getLanguageCode(currentLanguage).toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  String _getLanguageFlag(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'en':
        return '🇺🇸';
      case 'vi':
        return '🇻🇳';
      default:
        return '🌍';
    }
  }

  String _getLanguageCode(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'en':
        return 'EN';
      case 'vi':
        return 'VI';
      default:
        return 'XX';
    }
  }
}
