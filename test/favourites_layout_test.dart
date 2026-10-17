import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/l10n/localization.dart';
import 'package:hadithsearcher/viewmodels/favourites_viewmodel.dart';
import 'package:hadithsearcher/views/favourites/favourites_view.dart';
import 'package:provider/provider.dart';

class _Favourites extends FavouritesViewModel {
  bool loading = true;
  @override
  bool get isLoading => loading;
  @override
  bool get isEmpty => !loading;
  @override
  Future<void> loadFavourites() async {}

  void finishLoading() {
    loading = false;
    notifyListeners();
  }
}

void main() {
  testWidgets('empty favourites stay centered throughout the loading fade', (
    tester,
  ) async {
    final vm = _Favourites();
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<FavouritesViewModel>.value(
        value: vm,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FavouritesView(),
        ),
      ),
    );
    await tester.pump();
    vm.finishLoading();
    await tester.pump();
    final initial = tester.getCenter(find.byIcon(Icons.star_border));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getCenter(find.byIcon(Icons.star_border)), initial);
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.byIcon(Icons.star_border)), initial);
    expect(initial.dy, greaterThan(200));
    expect(tester.takeException(), isNull);
  });
}
