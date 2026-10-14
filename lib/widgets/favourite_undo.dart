import 'package:flutter/material.dart';
import '../services/database_service.dart';

void showFavouriteUndo(BuildContext context, FavouriteHadith favourite) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('تمت إزالة الحديث من المفضلة'),
      duration: const Duration(seconds: 4),
      persist: false,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'تراجع',
        textColor: Theme.of(context).colorScheme.surface,
        onPressed: () async {
          final restored = await DatabaseService().restoreFavourite(favourite);
          if (!restored && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تعذر استعادة الحديث')),
            );
          }
        },
      ),
    ),
  );
}
