import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../db/database.dart';
import '../widgets/hadith_container.dart';
import '../widgets/show_msg_dialog.dart';

class SimilarHadithView extends StatefulWidget {
  const SimilarHadithView({super.key, this.hadithId});
  final String? hadithId;

  @override
  State<SimilarHadithView> createState() => _SimilarHadithViewState();
}

class _SimilarHadithViewState extends State<SimilarHadithView> {
  DatabaseHelper sqlDb = DatabaseHelper();

  String hadithApiBaseUrl = dotenv.env['HADITH_API_BASE_URL']!;

  bool _isLoading = false;

  bool _showBackToTopButton = false;
  late ScrollController scrollController;

  List<bool> isFavButtonPressedList = List.generate(300, (_) => false);

  double previousOffset = 0;
  double upwardScrollDistance = 0;

  void scrollListener() async {
    setState(() {
      if (scrollController.offset >= 800) {
        if (scrollController.position.userScrollDirection ==
            ScrollDirection.reverse) {
          _showBackToTopButton = false; // Hide the back-to-top button
          upwardScrollDistance = 0;
        } else if (scrollController.position.userScrollDirection ==
            ScrollDirection.forward) {
          double scrollDelta = previousOffset - scrollController.offset;
          upwardScrollDistance += scrollDelta;

          if (upwardScrollDistance >= 100) {
            _showBackToTopButton = true; // Show the back-to-top button
          }
        }
      } else {
        _showBackToTopButton = false; // Hide the back-to-top button
        upwardScrollDistance = 0;
      }

      previousOffset = scrollController.offset;
    });
  }

  @override
  void initState() {
    getFontFamily();
    getFontWeight();
    getFontSize();
    getPadding();
    scrollController = ScrollController()..addListener(scrollListener);

    callFetchData();

    super.initState();
  }

  @override
  void dispose() {
    scrollController.removeListener(scrollListener);
    super.dispose();
  }

  void callFetchData() async {
    setState(() {
      _isLoading = true; // Display CircularProgressIndicator
      _showBackToTopButton = false;
    });
    await fetchData(widget.hadithId ?? 'No id passed');
    setState(() {
      _isLoading = false; // Hide CircularProgressIndicator
    });
  }

  List<Map> pairedValues = [];

  Future<void> fetchData(String hadithId) async {
    const CircularProgressIndicator();
    if (hadithId == '') {
      return await showMsgDialog(
        context,
        'أكتب شئ',
        'لا يمكنك ترك خانة البحث فارغة',
      );
    }
    try {
      var url = Uri.parse('$hadithApiBaseUrl/v1/site/hadith/similar/$hadithId');
      var response = await http.get(url).timeout(const Duration(seconds: 24));
      var decodedBody = utf8.decode(response.bodyBytes);
      var jsonResponse = json.decode(decodedBody);

      if (jsonResponse['metadata']['length'] == 0) {
        return await showMsgDialog(
          context,
          'لا توجد نتائج',
          'لا توجد أحاديث مشابهة لهذا الحديث',
        );
      } else {
        pairedValues = [];

        int current = -1;
        for (Map hadith in jsonResponse['data']) {
          current += 1;
          pairedValues.add(hadith);
          var favHadiths = await sqlDb.selectData("SELECT * FROM 'favourites'");
          for (var row in favHadiths) {
            if (row['hadithid'] == hadith['hadithId']) {
              setState(() {
                isFavButtonPressedList[current] = true;
              });
              break;
            }
          }
        }
      }
    } on http.ClientException {
      return await showMsgDialog(
        context,
        'خطأ بالإتصال بالإنترنت',
        'تأكد من إتصالك بالإنترنت وأعد المحاولة',
      );
    } on TimeoutException {
      return await showMsgDialog(
        context,
        'نفذ الوقت',
        'تأكد من إتصالك بإنترنت مستقر وأعد المحاولة',
      );
    }
    setState(() {}); // Refresh the UI after fetching data
  }

  String fontFamilySelectedValue = 'Roboto';
  FontWeight fontWeightSelectedValue = FontWeight.normal;
  double fontSizeSelectedValue = 20;
  EdgeInsets paddingSelectedValue = const EdgeInsets.all(10);

  List<Map> settingsPairedValues = [];

  getFontFamily() async {
    settingsPairedValues = [];
    List<Map<String, Object?>>? response =
        await sqlDb.selectData("SELECT * FROM settings");
    for (Map hadith in response!) {
      settingsPairedValues.add(hadith);
    }
    setState(() {
      fontFamilySelectedValue = settingsPairedValues[0]['fontfamily'];
    });
  }

  getFontWeight() async {
    settingsPairedValues = [];
    List<Map<String, Object?>>? response =
        await sqlDb.selectData("SELECT * FROM settings");
    for (Map hadith in response!) {
      settingsPairedValues.add(hadith);
    }

    if (settingsPairedValues[0]['fontweight'] == 'normal') {
      setState(() {
        fontWeightSelectedValue = FontWeight.normal;
      });
      return fontWeightSelectedValue = FontWeight.normal;
    } else if (settingsPairedValues[0]['fontweight'] == 'bold') {
      setState(() {
        fontWeightSelectedValue = FontWeight.bold;
      });
    }
  }

  getFontSize() async {
    settingsPairedValues = [];
    List<Map<String, Object?>>? response =
        await sqlDb.selectData("SELECT * FROM settings");
    for (Map hadith in response!) {
      settingsPairedValues.add(hadith);
    }

    int intValue = settingsPairedValues[0]['fontsize'];
    setState(() {
      fontSizeSelectedValue = intValue.toDouble();
    });
  }

  getPadding() async {
    settingsPairedValues = [];
    List<Map<String, Object?>>? response =
        await sqlDb.selectData("SELECT * FROM settings");
    for (Map hadith in response!) {
      settingsPairedValues.add(hadith);
    }

    int intValue = settingsPairedValues[0]['padding'];
    setState(() {
      paddingSelectedValue = EdgeInsets.all(intValue.toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'أحاديث مشابهة',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator() // Show CircularProgressIndicator when loading
            : Column(
                children: [
                  // Results ListView
                  Expanded(
                    child: ListView.builder(
                      primary: false,
                      controller: scrollController,
                      itemCount: pairedValues.length,
                      itemBuilder: (BuildContext context, int index) {
                        Map hadith = pairedValues[index];
                        String hadithText = hadith['hadith'];
                        String hadithInfo =
                            'الراوي: ${hadith['rawi']}\nالمحدث: ${hadith['mohdith']}\nالمصدر: ${hadith['book']}\nالصفحة أو الرقم: ${hadith['numberOrPage']}\nخلاصة حكم المحدث: ${hadith['grade']}';
                        String hadithId = hadith['hadithId'];
                        return HadithContainer(
                          paddingSelectedValue: paddingSelectedValue,
                          fontSizeSelectedValue: fontSizeSelectedValue,
                          fontWeightSelectedValue: fontWeightSelectedValue,
                          fontFamilySelectedValue: fontFamilySelectedValue,
                          hadith: hadith,
                          hadithInfo: hadithInfo,
                          hadithId: hadithId,
                          hadithText: hadithText,
                          isFavButtonPressedListIndex:
                              isFavButtonPressedList[index],
                          index: index,
                          isSimilarHadith: true,
                        );
                      },
                    ).animate().fade(duration: 200.ms),
                  ),
                ],
              ),
      ),
      floatingActionButton: _showBackToTopButton == false
          ? null
          : FloatingActionButton(
              onPressed: () {
                scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.linear,
                );
              },
              child: const Icon(Icons.arrow_upward),
            ),
    );
  }
}
