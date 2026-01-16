import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/routes.dart';
import '../widgets/show_navigation_drawer.dart';

class AboutView extends StatefulWidget {
  const AboutView({super.key});

  @override
  State<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<AboutView> {
  Future<bool> _onBackPressed() async {
    Navigator.of(context).pushNamedAndRemoveUntil(
      searchRoute,
      (route) => false,
    );
    return true;
  }

  Future<void> _launchUrl(url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حول'),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                const Text(
                  'Hadith Searcher',
                  style: TextStyle(
                    fontSize: 37,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                const Text(
                  'version 1.1.4',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(
                  height: 20,
                ),
                Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'تطبيق Hadith Searcher يهدف إلى تسهيل البحث عن الأحاديث والتحقق منها.',
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'جميع الأحاديث والمعلومات مأخوذة من موقع dorar.net باستخدام API AhmedElTabarani.',
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                      GestureDetector(
                        child: const Text(
                          'dorar.net',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.blue,
                            color: Colors.blue,
                            fontSize: 18,
                          ),
                        ),
                        onTap: () {
                          _launchUrl(Uri.parse('https://dorar.net/'));
                        },
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      GestureDetector(
                        child: const Text(
                          'AhmedElTabarani API',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.blue,
                            color: Colors.blue,
                            fontSize: 18,
                          ),
                        ),
                        onTap: () {
                          _launchUrl(Uri.parse(
                              'https://github.com/AhmedElTabarani/dorar-hadith-api'));
                        },
                      )
                    ],
                  ),
                ),
                const SizedBox(
                  height: 15,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              await SharePlus.instance.share(ShareParams(
                                  text:
                                      "https://play.google.com/store/apps/details?id=com.moaymandev.hadithsearcher"));
                            },
                            icon: const Icon(Icons.share_rounded),
                            tooltip: 'مشاركة',
                            iconSize: 33,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        const Text('مشاركة'),
                      ],
                    ),
                    const SizedBox(
                      width: 40,
                    ),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: IconButton(
                            onPressed: () {
                              _launchUrl(Uri.parse(
                                  'https://github.com/MAymanKH/HadithSearcher'));
                            },
                            icon: const Icon(Icons.code_rounded),
                            tooltip: 'الكود',
                            iconSize: 33,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        const Text('الكود'),
                      ],
                    ),
                    const SizedBox(
                      width: 40,
                    ),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: IconButton(
                            onPressed: () {
                              _launchUrl(
                                  Uri.parse('https://ko-fi.com/MAymanKH'));
                            },
                            icon: const Icon(Icons.attach_money_rounded),
                            tooltip: 'دعم',
                            iconSize: 33,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        const Text('دعم'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(
                  height: 15,
                ),
                Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text(
                            'المطور: ',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'محمد أيمن',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              fontSize: 20,
                            ),
                          )
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            child: const Text(
                              'Github',
                              style: TextStyle(
                                fontSize: 20,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.blue,
                                color: Colors.blue,
                              ),
                            ),
                            onTap: () {
                              _launchUrl(
                                  Uri.parse('https://github.com/MAymanKH'));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      GestureDetector(
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SelectableText(
                              'mohamedayman011324@gmail.com',
                              style: TextStyle(
                                fontSize: 18,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.blue,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          _launchUrl(Uri.parse('mohamedayman011324@gmail.com'));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                GestureDetector(
                  child: const Text(
                    'سياسة الخصوصية',
                    style: TextStyle(
                      fontSize: 18,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.blue,
                      color: Colors.blue,
                    ),
                  ),
                  onTap: () {
                    _launchUrl(Uri.parse(
                        'https://hadith-searcher-privacy-policy.pages.dev/'));
                  },
                ),
                const SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
        ),
        drawer: const MyNavigationDrawer(),
      ),
    );
  }
}
