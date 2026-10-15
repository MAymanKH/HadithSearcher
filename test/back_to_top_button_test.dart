import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/widgets/back_to_top_button.dart';

const _listKey = Key('scroll-list');

Widget _list(ScrollController controller) => ListView.builder(
  key: _listKey,
  controller: controller,
  itemCount: 100,
  itemExtent: 100,
  itemBuilder: (_, index) => Text('Item $index'),
);

class _MixinPage extends StatefulWidget {
  const _MixinPage();

  @override
  State<_MixinPage> createState() => _MixinPageState();
}

class _MixinPageState extends State<_MixinPage> with ScrollToTopMixin {
  @override
  void initState() {
    super.initState();
    initScrollController();
  }

  @override
  void dispose() {
    disposeScrollController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _list(scrollController),
    floatingActionButton: buildBackToTopButton(),
  );
}

void main() {
  for (final useMixin in [false, true]) {
    testWidgets(
      'button uses matching direction thresholds with mixin=$useMixin',
      (tester) async {
        final standaloneController = ScrollController();
        await tester.pumpWidget(
          MaterialApp(
            home: useMixin
                ? const _MixinPage()
                : BackToTopButton(
                    scrollController: standaloneController,
                    child: _list(standaloneController),
                  ),
          ),
        );
        final controller = useMixin
            ? tester
                  .state<_MixinPageState>(find.byType(_MixinPage))
                  .scrollController
            : standaloneController;
        controller.jumpTo(2000);
        await tester.pumpAndSettle();
        final button = find.byType(FloatingActionButton);

        Future<void> scroll(double distance) async {
          await tester.drag(
            find.byKey(_listKey),
            Offset(0, distance),
            touchSlopY: 0,
          );
          await tester.pumpAndSettle();
        }

        expect(button, findsNothing);
        await scroll(90);
        expect(button, findsNothing);
        await scroll(20);
        expect(button, findsOneWidget);
        await scroll(-90);
        expect(
          button,
          findsOneWidget,
          reason: 'small downward scroll must keep the button visible',
        );
        await scroll(-20);
        expect(button, findsNothing);

        // Changing direction starts a new distance count.
        await scroll(60);
        await scroll(-10);
        await scroll(60);
        expect(button, findsNothing);
        await scroll(50);
        expect(button, findsOneWidget);
        await scroll(-60);
        await scroll(10);
        await scroll(-60);
        expect(button, findsOneWidget);
        await scroll(-50);
        expect(button, findsNothing);

        await scroll(110);
        expect(button, findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(controller.offset, 0);
        expect(button, findsNothing);
        await tester.pumpWidget(const SizedBox());
        standaloneController.dispose();
      },
    );
  }
}
