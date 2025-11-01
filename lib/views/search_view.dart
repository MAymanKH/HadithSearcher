import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:fluttertoast/fluttertoast.dart';
import 'package:hadithsearcher/db/database.dart';
import 'package:hadithsearcher/views/similar_hadith_view.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../widgets/show_msg_dialog.dart';
import '../widgets/show_navigation_drawer.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  DatabaseHelper sqlDb = DatabaseHelper();

  String hadithApiBaseUrl = dotenv.env['HADITH_API_BASE_URL']!;

  bool isLoadingForTheFirstTime = false;

  bool isLoading = false;

  bool dontLoad = false;

  bool _isEmpty = true;

  final textFieldController = TextEditingController();

  final searchExcludedWordsController = TextEditingController();

  bool _showBackToTopButton = false;
  late ScrollController scrollController;

  List<bool> isFavButtonPressedList = List.generate(3000, (_) => false);

  void checkForUpdate() async {
    // Get the latest update information.
    AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

    // If there is a new update available, show a dialog to the user.
    updateInfo.updateAvailability == UpdateAvailability.updateAvailable
        ? () {
            showForceUpdateDialog(updateInfo);
          }
        : print('no update available');
  }

  void showForceUpdateDialog(AppUpdateInfo updateInfo) {
    // Create a dialog to show the user.
    AlertDialog dialog = AlertDialog(
      title: const Text('تحديث جديد'),
      content: const Text('يوجد تحديث جديد في المتجر, الرجاء التحديث.'),
      actions: [
        // Force the user to update the app.
        TextButton(
          child: const Text('تحديث'),
          onPressed: () {
            InAppUpdate.performImmediateUpdate();
          },
        ),
      ],
    );

    // Show the dialog to the user.
    showDialog(context: context, builder: (context) => dialog);
  }

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
    if (scrollController.position.extentAfter < 500) {
      if (searchIsRunning == false) {
        await fetchData();
        await Future.delayed(const Duration(seconds: 4));
      }
    }
  }

  String searchWaySelectedValue = 'أي كلمة';
  var searchWayList = [
    'أي كلمة',
    'جميع الكلمات',
    'بحث مطابق',
  ];

  String searchRangeSelectedValue = 'جميع الأحاديث';
  var searchRangeList = [
    'جميع الأحاديث',
    'الأحاديث المرفوعة',
    'الأحاديث القدسية',
    'آثار الصحابة',
    'شروح الأحاديث',
  ];

  String searchGradeSelectedValue = 'جميع الدرجات';
  var searchGradeList = [
    'جميع الدرجات',
    'أحاديث صحيحة',
    'أحاديث أسانيدها صحيحة',
    'أحاديث ضعيفة',
    'أحاديث أسانيدها ضعيفة',
  ];

  String searchMohdithSelectedValue = 'جميع المحدثين';
  var searchMohdithList = [
    'جميع المحدثين',
    'الإمام المالك',
    'الإمام الشافعي',
    'البخاري',
    'مسلم',
  ];

  String searchBookSelectedValue = 'جميع الكتب';
  var searchBookList = [
    'جميع الكتب',
    'الأربعون النووية',
    'صحيح البخاري',
    'صحيح مسلم',
    'الصحيح المسند',
  ];

  String searchExcludedWords = '';

  bool advancedSaveCheckbox = true;

  getAdvancedPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? searchWayPref = prefs.getString('searchWay');
    String? searchRangePref = prefs.getString('searchRange');
    String? searchGradePref = prefs.getString('searchGrade');
    String? searchMohdithPref = prefs.getString('searchMohdith');
    String? searchBookPref = prefs.getString('searchBook');
    String? searchExcludedWordsPref = prefs.getString('searchExcludedWords');
    bool? advancedSaveCheckboxPref = prefs.getBool('advancedSaveCheckbox');

    setState(() {
      if (searchWayPref != null) {
        searchWaySelectedValue = searchWayPref;
      }
      if (searchRangePref != null) {
        searchRangeSelectedValue = searchRangePref;
      }
      if (searchGradePref != null) {
        searchGradeSelectedValue = searchGradePref;
      }
      if (searchMohdithPref != null) {
        searchMohdithSelectedValue = searchMohdithPref;
      }
      if (searchBookPref != null) {
        searchBookSelectedValue = searchBookPref;
      }
      if (searchExcludedWordsPref != null) {
        searchExcludedWords = searchExcludedWordsPref;
      }
      if (advancedSaveCheckboxPref != null) {
        advancedSaveCheckbox = advancedSaveCheckboxPref;
      }
    });
  }

  Future shareHadith(int index, Map hadith) async {
    String hadithText =
        '${hadith['hadith']}\n\nالراوي: ${hadith['rawi']}\nالمحدث: ${hadith['mohdith']}\nالمصدر: ${hadith['book']}\nالصفحة أو الرقم: ${hadith['numberOrPage']}\nخلاصة حكم المحدث: ${hadith['grade']}';

    await SharePlus.instance.share(ShareParams(text: hadithText));
  }

  @override
  void initState() {
    getAdvancedPrefs();
    checkForUpdate();
    scrollController = ScrollController()..addListener(scrollListener);
    super.initState();
  }

  @override
  void dispose() {
    textFieldController.dispose();
    searchExcludedWordsController.dispose();
    scrollController.removeListener(scrollListener);
    super.dispose();
  }

  List<Map> pairedValues = [];

  String searchKeyword = '';

  int searchPagaNumber = 0;

  bool searchIsRunning = false;

  Future<void> fetchData() async {
    if (searchKeyword == '') {
      return await showMsgDialog(
        context,
        'أكتب شئ',
        'لا يمكنك ترك خانة البحث فارغة',
      );
    }
    // if (dontLoad == true) {
    //   return;
    // }
    setState(() {
      searchIsRunning = true;
      if (isLoadingForTheFirstTime == false) {
        isLoading = true;
        dontLoad = false;
      } else {
        _showBackToTopButton = false;
      }
    });
    getFontFamily();
    getFontWeight();
    getFontSize();
    getPadding();
    try {
      String searchWay = '';
      String searchRange = '';
      String searchGrade = '';
      String searchMohdith = '';
      String searchBook = '';

      if (searchWaySelectedValue == 'أي كلمة') {
        searchWay = 'a';
      } else if (searchWaySelectedValue == 'جميع الكلمات') {
        searchWay = 'w';
      } else if (searchWaySelectedValue == 'بحث مطابق') {
        searchWay = 'p';
      }

      if (searchRangeSelectedValue == 'جميع الأحاديث') {
        searchRange = '*';
      } else if (searchRangeSelectedValue == 'الأحاديث المرفوعة') {
        searchRange = '0';
      } else if (searchRangeSelectedValue == 'الأحاديث القدسية') {
        searchRange = '1';
      } else if (searchRangeSelectedValue == 'آثار الصحابة') {
        searchRange = '2';
      } else if (searchRangeSelectedValue == 'شروح الأحاديث') {
        searchRange = '3';
      }

      if (searchGradeSelectedValue == 'جميع الدرجات') {
        searchGrade = '0';
      } else if (searchGradeSelectedValue == 'أحاديث صحيحة') {
        searchGrade = '1';
      } else if (searchGradeSelectedValue == 'أحاديث أسانيدها صحيحة') {
        searchGrade = '2';
      } else if (searchGradeSelectedValue == 'أحاديث صعيفة') {
        searchGrade = '3';
      } else if (searchGradeSelectedValue == 'أحاديث أسانيدها ضعيفة') {
        searchGrade = '4';
      }

      if (searchMohdithSelectedValue == 'جميع المحدثين') {
        searchMohdith = '0';
      } else if (searchMohdithSelectedValue == 'الإمام المالك') {
        searchMohdith = '179';
      } else if (searchMohdithSelectedValue == 'الإمام الشافعي') {
        searchMohdith = '204';
      } else if (searchMohdithSelectedValue == 'البخاري') {
        searchMohdith = '256';
      } else if (searchMohdithSelectedValue == 'مسلم') {
        searchMohdith = '261';
      }

      if (searchBookSelectedValue == 'جميع الكتب') {
        searchBook = '0';
      } else if (searchBookSelectedValue == 'الأربعون النووية') {
        searchBook = '13457';
      } else if (searchBookSelectedValue == 'صحيح البخاري') {
        searchBook = '6216';
      } else if (searchBookSelectedValue == 'صحيح مسلم') {
        searchBook = '3088';
      } else if (searchBookSelectedValue == 'الصحيح المسند') {
        searchBook = '96';
      }
      if (isAdvancedSearchEnabled == true) {
        setState(() {
          searchPagaNumber = 1;
        });
      }

      var url = Uri.parse(
          '$hadithApiBaseUrl/v1/site/hadith/search?value=$searchKeyword&page=$searchPagaNumber&st=$searchWay&t=$searchRange&d[]=$searchGrade&m[]=$searchMohdith&s[]=$searchBook$searchExcludedWords');
      var response = await http.get(url).timeout(const Duration(seconds: 24));
      var decodedBody = utf8.decode(response.bodyBytes);
      var jsonResponse = json.decode(decodedBody);

      if (jsonResponse['metadata']['length'] == 0) {
        searchIsRunning = false;
        if (searchPagaNumber > 1) {
          setState(() {
            dontLoad = true;
            // searchPagaNumber -= 1;
            isLoading = false;
          });
          return;
        } else {
          setState(() {
            searchIsRunning = false;
          });
          return await showMsgDialog(
            context,
            'لا توجد نتائج',
            'استخدم كلمات أو إعدادات أخرى',
          );
        }
      } else {
        if (isLoadingForTheFirstTime) {
          pairedValues = [];
        }

        int favCurrent = -1;

        if (searchPagaNumber > 1) {
          favCurrent += (searchPagaNumber - 1) * 30;
        }
        for (Map hadith in jsonResponse['data']) {
          favCurrent += 1;
          pairedValues.add(hadith);

          var favHadiths = await sqlDb.selectData("SELECT * FROM 'favourites'");
          for (var row in favHadiths) {
            if (row['hadithid'] == hadith['hadithId']) {
              setState(() {
                isFavButtonPressedList[favCurrent] = true;
              });
              break;
            }
          }
        }
      }
      // void main() {
      //   // Create a set to keep track of seen hadithId values
      //   Set<int> seenIds = {};

      //   // Iterate over the list in reverse to remove duplicates from the end
      //   for (int i = pairedValues.length - 1; i >= 0; i--) {
      //     int id = pairedValues[i]['hadithId'];
      //     if (seenIds.contains(id)) {
      //       pairedValues.removeAt(i);
      //     } else {
      //       seenIds.add(id);
      //     }
      //   }
      // }
    } on http.ClientException {
      setState(() {
        searchIsRunning = false;
      });
      return await showMsgDialog(
        context,
        'خطأ بالإتصال بالإنترنت',
        'تأكد من إتصالك بالإنترنت وأعد المحاولة',
      );
    } on TimeoutException {
      setState(() {
        searchIsRunning = false;
      });
      return await showMsgDialog(
        context,
        'نفذ الوقت',
        'تأكد من إتصالك بإنترنت مستقر وأعد المحاولة',
      );
    }
    setState(() {
      searchIsRunning = false;
      searchPagaNumber += 1;
      _isEmpty = false;
      if (isLoadingForTheFirstTime) {
        isLoadingForTheFirstTime = false;
      } else {
        isLoading = false;
      }
    });
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

  saveAdvanvedSettings() async {
    if (!listEquals(advancedData, [
      searchWaySelectedValue,
      searchRangeSelectedValue,
      searchGradeSelectedValue,
      searchMohdithSelectedValue,
      searchBookSelectedValue,
      searchExcludedWords
    ])) {
      if (advancedSaveCheckbox == true) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('searchWay', searchWaySelectedValue);
        await prefs.setString('searchRange', searchRangeSelectedValue);
        await prefs.setString('searchGrade', searchGradeSelectedValue);
        await prefs.setString('searchMohdith', searchMohdithSelectedValue);
        await prefs.setString('searchBook', searchBookSelectedValue);
        await prefs.setString('searchExcludedWords', searchExcludedWords);
        // Fluttertoast.showToast(
        //   msg: 'تم الحفظ',
        //   toastLength: Toast.LENGTH_SHORT,
        // );
      }
    }
  }

  var isFavButtonPressed = false;

  bool isAdvancedSearchEnabled = false;

  List advancedData = [];

  @override
  Widget build(BuildContext context) {
    // To adjust search's textfield based on screen's width
    double screenWidth = MediaQuery.of(context).size.width;
    double textFieldWidth = screenWidth * 0.6;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'البحث',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Advanced search button
          IconButton(
            onPressed: () async {
              if (isAdvancedSearchEnabled == false) {
                setState(() {
                  advancedData = [
                    searchWaySelectedValue,
                    searchRangeSelectedValue,
                    searchGradeSelectedValue,
                    searchMohdithSelectedValue,
                    searchBookSelectedValue,
                    searchExcludedWords
                  ];
                });
              } else {
                if (!listEquals(advancedData, [
                  searchWaySelectedValue,
                  searchRangeSelectedValue,
                  searchGradeSelectedValue,
                  searchMohdithSelectedValue,
                  searchBookSelectedValue,
                  searchExcludedWords
                ])) {
                  // Search and save adv data bc advanced has been edited
                  await saveAdvanvedSettings();
                  setState(() {
                    searchPagaNumber = 1;
                    // isAdvancedSearchEnabled = false;
                    searchKeyword = textFieldController.text;
                    isLoadingForTheFirstTime =
                        true; // Display CircularProgressIndicator
                    _showBackToTopButton = false;
                  });
                  await fetchData();
                  setState(() {
                    isLoadingForTheFirstTime =
                        false; // Hide CircularProgressIndicator
                  });
                } else {
                  log("advanced settings has NOT been edited");
                }
              }
              setState(() {
                _showBackToTopButton = false;
                isAdvancedSearchEnabled = !isAdvancedSearchEnabled;
              });
            },
            icon: const Icon(
              Icons.filter_alt,
              size: 30,
            ),
            tooltip: 'البحث المتقدم',
          ),
        ],
      ),
      body: Center(
        child: isLoadingForTheFirstTime
            ? const CircularProgressIndicator() // Show CircularProgressIndicator when loading
            : Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: textFieldWidth,
                        height: 60,
                        // Search TextField
                        child: TextField(
                          textInputAction: TextInputAction.search,
                          controller: textFieldController,
                          decoration: const InputDecoration(
                            hintText: 'تحقق من حديث...',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                          onSubmitted: (value) async {
                            await saveAdvanvedSettings();
                            setState(() {
                              searchPagaNumber = 1;
                              isAdvancedSearchEnabled = false;
                              searchKeyword = textFieldController.text;
                              isLoadingForTheFirstTime =
                                  true; // Display CircularProgressIndicator
                              _showBackToTopButton = false;
                            });
                            await fetchData();
                            setState(() {
                              isLoadingForTheFirstTime =
                                  false; // Hide CircularProgressIndicator
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        height: 60,
                        // Search button
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.search,
                            size: 30.0,
                          ),
                          label: const Text('بحث'),
                          onPressed: () async {
                            await saveAdvanvedSettings();
                            setState(() {
                              searchPagaNumber = 1;
                              isAdvancedSearchEnabled = false;
                              searchKeyword = textFieldController.text;
                              isLoadingForTheFirstTime =
                                  true; // Display CircularProgressIndicator
                              _showBackToTopButton = false;
                            });
                            await fetchData();
                            setState(() {
                              isLoadingForTheFirstTime =
                                  false; // Hide CircularProgressIndicator
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  isAdvancedSearchEnabled
                      ? Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                const SizedBox(
                                  height: 15,
                                ),
                                const Text(
                                  'البحث المتقدم',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(
                                  height: 15,
                                ),
                                // // Combobox
                                // Container(
                                //   padding: const EdgeInsets.all(10),
                                //   child: Row(
                                //     children: [
                                //       Container(
                                //         padding: const EdgeInsets.symmetric(
                                //             horizontal: 10, vertical: 5),
                                //         decoration: BoxDecoration(
                                //           color: Theme.of(context)
                                //               .colorScheme
                                //               .primaryContainer,
                                //           borderRadius:
                                //               BorderRadius.circular(10),
                                //         ),
                                //         child: Row(
                                //           children: [
                                //             const Text(
                                //               'طريقة البحث',
                                //               style: TextStyle(
                                //                 fontSize: 15,
                                //               ),
                                //             ),
                                //             const SizedBox(
                                //               width: 10,
                                //             ),
                                //             Container(
                                //               padding:
                                //                   const EdgeInsets.symmetric(
                                //                       horizontal: 10,
                                //                       vertical: 5),
                                //               decoration: BoxDecoration(
                                //                 color: Theme.of(context)
                                //                     .scaffoldBackgroundColor,
                                //                 borderRadius:
                                //                     BorderRadius.circular(10),
                                //               ),
                                //               // dropdown below..
                                //               child: DropdownButton<String>(
                                //                 value: searchWaySelectedValue,
                                //                 onChanged:
                                //                     (String? newValue) async {
                                //                   setState(
                                //                     () {
                                //                       searchWaySelectedValue =
                                //                           newValue!;
                                //                     },
                                //                   );
                                //                 },
                                //                 items: searchWayList
                                //                     .map<
                                //                         DropdownMenuItem<
                                //                             String>>(
                                //                       (String value) =>
                                //                           DropdownMenuItem<
                                //                               String>(
                                //                         value: value,
                                //                         child: Text(
                                //                           value,
                                //                           style:
                                //                               const TextStyle(
                                //                             fontSize: 15,
                                //                           ),
                                //                         ),
                                //                       ),
                                //                     )
                                //                     .toList(),
                                //                 // add extra sugar..
                                //                 icon: const Icon(
                                //                     Icons.arrow_drop_down),
                                //                 iconSize: 35,
                                //                 underline: const SizedBox(),
                                //               ),
                                //             ),
                                //           ],
                                //         ),
                                //       ),
                                //     ],
                                //   ),
                                // ),
                                // Combobox
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text(
                                              'نطاق البحث',
                                              style: TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 10,
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .scaffoldBackgroundColor,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              // dropdown below..
                                              child: DropdownButton<String>(
                                                value: searchRangeSelectedValue,
                                                onChanged:
                                                    (String? newValue) async {
                                                  setState(
                                                    () {
                                                      searchRangeSelectedValue =
                                                          newValue!;
                                                    },
                                                  );
                                                },
                                                items: searchRangeList
                                                    .map<
                                                        DropdownMenuItem<
                                                            String>>(
                                                      (String value) =>
                                                          DropdownMenuItem<
                                                              String>(
                                                        value: value,
                                                        child: Text(
                                                          value,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                // add extra sugar..
                                                icon: const Icon(
                                                    Icons.arrow_drop_down),
                                                iconSize: 35,
                                                underline: const SizedBox(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Combobox
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text(
                                              'درجة الحديث',
                                              style: TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 10,
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .scaffoldBackgroundColor,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              // dropdown below..
                                              child: DropdownButton<String>(
                                                value: searchGradeSelectedValue,
                                                onChanged:
                                                    (String? newValue) async {
                                                  setState(
                                                    () {
                                                      searchGradeSelectedValue =
                                                          newValue!;
                                                    },
                                                  );
                                                },
                                                items: searchGradeList
                                                    .map<
                                                        DropdownMenuItem<
                                                            String>>(
                                                      (String value) =>
                                                          DropdownMenuItem<
                                                              String>(
                                                        value: value,
                                                        child: Text(
                                                          value,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                // add extra sugar..
                                                icon: const Icon(
                                                    Icons.arrow_drop_down),
                                                iconSize: 35,
                                                underline: const SizedBox(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Combobox
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text(
                                              'المحدث',
                                              style: TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 10,
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .scaffoldBackgroundColor,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              // dropdown below..
                                              child: DropdownButton<String>(
                                                value:
                                                    searchMohdithSelectedValue,
                                                onChanged:
                                                    (String? newValue) async {
                                                  setState(
                                                    () {
                                                      searchMohdithSelectedValue =
                                                          newValue!;
                                                    },
                                                  );
                                                },
                                                items: searchMohdithList
                                                    .map<
                                                        DropdownMenuItem<
                                                            String>>(
                                                      (String value) =>
                                                          DropdownMenuItem<
                                                              String>(
                                                        value: value,
                                                        child: Text(
                                                          value,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                // add extra sugar..
                                                icon: const Icon(
                                                    Icons.arrow_drop_down),
                                                iconSize: 35,
                                                underline: const SizedBox(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Combobox
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text(
                                              'الكتاب',
                                              style: TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 10,
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .scaffoldBackgroundColor,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              // dropdown below..
                                              child: DropdownButton<String>(
                                                value: searchBookSelectedValue,
                                                onChanged:
                                                    (String? newValue) async {
                                                  setState(
                                                    () {
                                                      searchBookSelectedValue =
                                                          newValue!;
                                                    },
                                                  );
                                                },
                                                items: searchBookList
                                                    .map<
                                                        DropdownMenuItem<
                                                            String>>(
                                                      (String value) =>
                                                          DropdownMenuItem<
                                                              String>(
                                                        value: value,
                                                        child: Text(
                                                          value,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                // add extra sugar..
                                                icon: const Icon(
                                                    Icons.arrow_drop_down),
                                                iconSize: 35,
                                                underline: const SizedBox(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    SizedBox(
                                      width: 250,
                                      height: 60,
                                      child: TextField(
                                        controller:
                                            searchExcludedWordsController,
                                        decoration: const InputDecoration(
                                          hintText:
                                              'كلمة أو جملة تريد استبعادها من البحث',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            searchExcludedWords =
                                                '&xclude=$value';
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 5,
                                ),
                                CheckboxListTile(
                                  title: const Text(
                                      "حفظ التعديلات للاستخدامات القادمة"),
                                  value: advancedSaveCheckbox,
                                  checkColor: Colors.white,
                                  onChanged: (newValue) async {
                                    setState(() {
                                      advancedSaveCheckbox = newValue!;
                                    });
                                    final SharedPreferences prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setBool('advancedSaveCheckbox',
                                        advancedSaveCheckbox);
                                  },
                                  controlAffinity: ListTileControlAffinity
                                      .leading, //  <-- leading Checkbox
                                ),
                              ],
                            ).animate().fade(duration: 200.ms),
                          ),
                        )
                      : _isEmpty
                          ? Container(
                              margin: const EdgeInsets.all(20),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 100,
                                  ),
                                  Icon(
                                    Icons.search,
                                    size: 140,
                                  ),
                                  SizedBox(
                                    height: 15,
                                  ),
                                  Text(
                                    'تأكد من صحة الأحاديث',
                                    style: TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fade(duration: 200.ms)
                          : // Results ListView
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

                                  return Container(
                                    margin: const EdgeInsets.all(10),
                                    padding: paddingSelectedValue,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Column(
                                      children: [
                                        SelectableText(
                                          '${hadithText}\n\n${hadithInfo}',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondaryContainer,
                                            fontSize: fontSizeSelectedValue,
                                            fontWeight: fontWeightSelectedValue,
                                            fontFamily: fontFamilySelectedValue,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 15,
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              height: 45,
                                              child: ElevatedButton.icon(
                                                onPressed: () async {
                                                  try {
                                                    if (hadith[
                                                            'hasSharhMetadata'] ==
                                                        true) {
                                                      var url = Uri.parse(
                                                          "$hadithApiBaseUrl/v1/site/sharh/${hadith['sharhMetadata']['id']}");
                                                      var response = await http
                                                          .get(url)
                                                          .timeout(
                                                              const Duration(
                                                                  seconds: 8));
                                                      var decodedBody =
                                                          utf8.decode(response
                                                              .bodyBytes);
                                                      var jsonResponse = json
                                                          .decode(decodedBody);

                                                      return await showMsgDialog(
                                                        context,
                                                        'الشرح',
                                                        jsonResponse['data'][
                                                                'sharhMetadata']
                                                            ['sharh'],
                                                      );
                                                    } else {
                                                      // Fluttertoast.showToast(
                                                      //   msg: 'فشل البحث عن شرح',
                                                      //   toastLength:
                                                      //       Toast.LENGTH_SHORT,
                                                      // );
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
                                                },
                                                icon: const Icon(
                                                  Icons.manage_search,
                                                  size: 25,
                                                ),
                                                label: const Text(
                                                  'الشرح',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30.0),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 15,
                                            ),
                                            SizedBox(
                                              height: 45,
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            SimilarHadithView(
                                                              hadithId:
                                                                  hadithId,
                                                            )),
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.content_paste_go,
                                                  size: 25,
                                                ),
                                                label: const Text(
                                                  'أحاديث مشابهة',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30.0),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(
                                          height: 10,
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              height: 45,
                                              child: ElevatedButton.icon(
                                                onPressed: () async {
                                                  await shareHadith(
                                                      index, hadith);
                                                },
                                                icon: const Icon(
                                                  Icons.share_rounded,
                                                  size: 25,
                                                ),
                                                label: const Text(
                                                  'مشاركة',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30.0),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 15,
                                            ),
                                            SizedBox(
                                              height: 45,
                                              child: ElevatedButton.icon(
                                                onPressed: () async {
                                                  var dbHadithId =
                                                      await sqlDb.selectData(
                                                          "SELECT * FROM 'favourites'");
                                                  for (var row in dbHadithId) {
                                                    if (row['hadithid'] ==
                                                        hadithId) {
                                                      await sqlDb.deleteData(
                                                          "DELETE FROM 'favourites' WHERE id = ${row['id']}");
                                                      // Fluttertoast.showToast(
                                                      //   msg:
                                                      //       'تم إزالة الحديث من المفضلة',
                                                      //   toastLength:
                                                      //       Toast.LENGTH_SHORT,
                                                      // );
                                                      setState(() {
                                                        isFavButtonPressedList[
                                                            index] = false;
                                                      });
                                                      return;
                                                    }
                                                  }
                                                  await sqlDb.insertData(
                                                      "INSERT INTO 'favourites' ('hadithtext', 'hadithinfo', 'hadithid') VALUES ('${hadithText}', '${hadithInfo}', '${hadithId}')");
                                                  // Fluttertoast.showToast(
                                                  //   msg:
                                                  //       'تم إضافة الحديث إلى المفضلة',
                                                  //   toastLength:
                                                  //       Toast.LENGTH_SHORT,
                                                  // );
                                                  setState(() {
                                                    isFavButtonPressedList[
                                                        index] = true;
                                                  });
                                                },
                                                icon: Icon(
                                                  isFavButtonPressedList[index]
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  size: 25,
                                                ),
                                                label: Text(
                                                  isFavButtonPressedList[index]
                                                      ? 'أزل من المفضلة'
                                                      : 'أضف إلى المفضلة',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30.0),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ).animate().fade(duration: 200.ms),
                            ),
                  _isEmpty
                      ? const Text('')
                      : isAdvancedSearchEnabled
                          ? const Text('')
                          : const SizedBox(),
                  // Column(
                  //     children: [
                  //       const SizedBox(
                  //         height: 10,
                  //       ),
                  //       Row(
                  //         mainAxisAlignment:
                  //             MainAxisAlignment.spaceEvenly,
                  //         children: [
                  //           SizedBox(
                  //             height: 45,
                  //             child: ElevatedButton.icon(
                  //               onPressed: () async {
                  //                 setState(() {
                  //                   searchPagaNumber =
                  //                       searchPagaNumber + 1;
                  //                   isLoadingForTheFirstTime =
                  //                       true; // Display CircularProgressIndicator
                  //                   _showBackToTopButton = false;
                  //                 });
                  //                 await fetchData();
                  //                 setState(() {
                  //                   isLoadingForTheFirstTime =
                  //                       false; // Hide CircularProgressIndicator
                  //                 });
                  //               },
                  //               icon: const Icon(Icons.arrow_back),
                  //               label: const Text('الصفحة التالية'),
                  //               style: ElevatedButton.styleFrom(
                  //                 shape: RoundedRectangleBorder(
                  //                   borderRadius:
                  //                       BorderRadius.circular(30.0),
                  //                 ),
                  //               ),
                  //             ),
                  //           ),
                  //           Text(
                  //             '$searchPagaNumber',
                  //             style: const TextStyle(
                  //               fontSize: 20,
                  //               fontWeight: FontWeight.bold,
                  //             ),
                  //           ),
                  //           SizedBox(
                  //             height: 45,
                  //             child: ElevatedButton.icon(
                  //               onPressed: () async {
                  //                 if (searchPagaNumber > 1) {
                  //                   setState(() {
                  //                     searchPagaNumber =
                  //                         searchPagaNumber - 1;
                  //                     isLoadingForTheFirstTime =
                  //                         true; // Display CircularProgressIndicator
                  //                     _showBackToTopButton = false;
                  //                   });
                  //                   await fetchData();
                  //                   setState(() {
                  //                     isLoadingForTheFirstTime =
                  //                         false; // Hide CircularProgressIndicator
                  //                   });
                  //                 }
                  //               },
                  //               icon: const Icon(Icons.arrow_forward),
                  //               label: const Text('الصفحة السابقة'),
                  //               style: ElevatedButton.styleFrom(
                  //                 shape: RoundedRectangleBorder(
                  //                   borderRadius:
                  //                       BorderRadius.circular(30.0),
                  //                 ),
                  //               ),
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //       const SizedBox(
                  //         height: 10,
                  //       ),
                  //     ],
                  //   ),
                  isLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : const SizedBox()
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
      drawer: const MyNavigationDrawer(),
    );
  }
}
