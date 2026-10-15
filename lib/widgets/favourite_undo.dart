import 'package:flutter/material.dart';
import 'app_snack_bar.dart';
import '../services/database_service.dart';

void _showFavouriteFeedback(BuildContext context, SnackBar snackBar) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  showAppSnackBar(context, snackBar);
}

void showFavouriteAdded(BuildContext context) {
  _showFavouriteFeedback(
    context,
    const SnackBar(
      content: Text('تمت إضافة الحديث إلى المفضلة'),
      duration: Duration(milliseconds: 1500),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showFavouriteUndo(BuildContext context, FavouriteHadith favourite) {
  _showFavouriteFeedback(
    context,
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
            showAppSnackBar(
              context,
              const SnackBar(content: Text('تعذر استعادة الحديث')),
            );
          }
        },
      ),
    ),
  );
}
