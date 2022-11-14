import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/m_allbook/user_bookshelf.dart';
import '../pages/detailpage.dart';
import '../constants/colors.dart';
import '../widgets/leftmenu.dart';
import '../pages/search/search.dart';
import '../pages/pdfviewer/pdf_viewer.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_android/path_provider_android.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:isolate';
import 'dart:ui';
// import '../widgets/openPdf.dart';
import 'dart:async';
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../pages/mainpage.dart';
import '../models/m_detail/m_rateingStar.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../database/database_helper.dart';
import 'package:flutter/foundation.dart';
import '../pages/pdfviewer/api/pdf_api.dart';

class bookshelf extends StatefulWidget {
  static late DownloadCallback download;

  const bookshelf({Key? key}) : super(key: key);

  @override
  State<bookshelf> createState() => _bookshelfState();
}

class _bookshelfState extends State<bookshelf> {
  final ReceivePort _port = ReceivePort();
  final controller = ScrollController();
  int page = 1;
  List<InsertKey?> userBookShelflist = [];
  List<String> databook = [];
  List<Map<String, dynamic>> myData = [];
  bool hasmore = true;
  String _localPath = '';
  var bookIdType;
  var pathSite;
  var imageUrl;
  var imageLocalFile;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    fetch();

    controller.addListener(() {
      if (controller.position.maxScrollExtent == controller.offset) {
        fetch();
      }
    });

    IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];
      setState(() {});
    });

    FlutterDownloader.registerCallback(downloadCallback);
  }

  void returnBook({required bookshelfId, required DB_id}) async {
    final prefs = await SharedPreferences.getInstance();
    final String? uniId = prefs.getString('uniId');
    final String? userLoginname = prefs.getString('userLoginname');
    final String? uniLink = prefs.getString('uniLink');

    var getCheckFav =
        "${uniLink}/checkin.php?bookshelf_id=${bookshelfId}&user=${userLoginname}&uni_id=${uniId}";
    final uri = Uri.parse(getCheckFav);
    http.get(uri).then((response) async {
      // print(
      //     "https://www.2ebook.com/new/2ebook_mobile/checkin.php?bookshelf_id=${bookshelfId}&user=${userLoginname}&uni_id=${uniId}");
      if (response.statusCode == 200) {
        final responseBody = response.body;
        final decodedData = jsonDecode(responseBody);
        AlertDialogReturnBook(context);
        getIdByBookId(DB_id);
      }
    });
    // getIdByBookId(DB_id);
    //  /storage/emulated/0/Download/02008232.pdf
  }

  void deleteItem(int id) async {
    await DatabaseHelper.deleteItem(id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Successfully deleted!'), backgroundColor: Colors.green));
    _refreshData();
  }

  void _refreshData() async {
    final data = await DatabaseHelper.getItems();
    setState(() {
      myData = data;
    });
  }

  void getIdByBookId(DB_id) async {
    List<Map> data = await DatabaseHelper.getIDWithBookId(DB_id);
    final existingData =
        data.firstWhere((element) => element['book_id'] == DB_id);
    if (existingData['id']) {
      await DatabaseHelper.deleteItem(existingData['id']);
      final file = File("/storage/emulated/0/Download/$DB_id.pdf");
      await file.delete();
      print('Alread delete');
    }

    // final file = localFile(DB_id);
    // final file = await _localFile;

    // print(file);

    // final file = File(
    //     "storage/emulated/0/Android/data/com.example.anime_app/files/02008232.pdf");
    // await file.delete();
    // final decodedData = jsonDecode(data);
    // setState(() {
    //   myData = data;
    // });

    // deleteItem(existingData['id']);
    // print('${existingData['id']}');
  }

  AlertDialogReturnBook(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('SUCCESS'),
        content: const Text('คืนหนังสือ สำเร็จแล้ว!'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => MainPage(selectedPage: 1)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future fetch() async {
    final prefs = await SharedPreferences.getInstance();
    final String? uniId = prefs.getString('uniId');
    final String? userLoginname = prefs.getString('userLoginname');
    final String? uniLink = prefs.getString('uniLink');
    final String? pathWebSite = prefs.getString('pathWebSite');
    const noBook = 0;
    const limited = 10;
    // _localPath = (await _findLocalPath())!;
    var getNewBook =
        "${uniLink}/server_update.php?user=${userLoginname}&uni_id=${uniId}";
    print(getNewBook);
    final uri = Uri.parse(getNewBook);
    http.get(uri).then((response) {
      if (response.statusCode == 200) {
        final responseBody = response.body;
        final decodedData = jsonDecode(responseBody);
        if (decodedData["insert_key"] != Null) {
          userBookShelflist = [
            ...userBookShelflist,
            ...userBookshelf.fromJson(decodedData).insertKey as List<InsertKey?>
          ];
        }

        setState(() {
          page++;

          if (userBookShelflist.length < limited ||
              userBookShelflist.length == noBook) {
            hasmore = false;
          }
          // if (userBookShelflist.length == noBook) {
          //   hasmore = true;
          // }
          pathSite = pathWebSite;
          // _localPath;
        });
      } else {}
    }).catchError((err) {
      debugPrint('=========== $err =============');
    });
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    super.dispose();
  }

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port')!;
    send.send([id, status, progress]);
  }

  void download({required pdfLink}) async {
    try {
      await [
        Permission.storage,
      ].request();

      var _localPath = (await _findLocalPath())!;
      final taskId = await FlutterDownloader.enqueue(
        url: pdfLink,
        savedDir: _localPath,
        saveInPublicStorage: true,
        showNotification:
            true, // show download progress in status bar (for Android)
        openFileFromNotification:
            true, // click on notification to open downloaded file (for Android)
      );
      setState(() {
        _localPath;
      });
    } catch (e) {
      print('sssss${e}');
    }
  }

  Future<String?> _findLocalPath() async {
    var externalStorageDirPath;
    if (Platform.isAndroid) {
      try {
        externalStorageDirPath = await PathProviderAndroid()
            .getDownloadsPath(); //AndroidPathProvider.downloadsPath;
      } catch (e) {
        final directory = await getApplicationDocumentsDirectory();
        externalStorageDirPath = directory.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath =
          (await getApplicationDocumentsDirectory()).absolute.path;
    }
    return externalStorageDirPath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "ชั้นหนังสือ",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AnimeUI.cyan,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.0,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => searchPage()),
              );
              // showSearch(
              //   context: context,
              //   delegate: MySearchDelegate(),
              // );
            },
          ),
        ],
      ),
      drawer: PublicDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
            controller: controller,
            itemCount: userBookShelflist.length + 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 20,
              crossAxisSpacing: 8,
              mainAxisExtent: 200,
            ),

            // itemCount: popularBooklist.length,
            itemBuilder: (BuildContext ctx, index) {
              if (index < userBookShelflist.length) {
                bookIdType =
                    userBookShelflist[index]!.bookId.toString().substring(1, 2);
                if (bookIdType == '9') {
                  imageUrl = userBookShelflist[index]!.imgLink.toString();
                  userBookShelflist[index]!.imgLink = imageUrl.replaceAll(
                      "http://www.2ebook.com/new", pathSite);
                }
                return Container(
                  //borderRadius: BorderRadius.circular(20),
                  child: (userBookShelflist[index]!.bookDesc != null &&
                          userBookShelflist[index]!.bookId != '0')
                      ? InkWell(
                          onTap: () => showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  scrollable: true,
                                  content: Column(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          download(
                                              pdfLink: userBookShelflist[index]!
                                                  .pdfLink);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          primary:
                                              AnimeUI.cyan, // Background color
                                        ),
                                        icon: Icon(
                                          Icons.download,
                                          size: 24.0,
                                        ),
                                        label: Text(
                                          'โหลดหนังสือ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder:
                                                      (context) => ebookReader(
                                                            bookTitle: userBookShelflist[
                                                                        index]!
                                                                    .bookTitle ??
                                                                '',
                                                            fileBook:
                                                                userBookShelflist[
                                                                            index]!
                                                                        .bookId ??
                                                                    '',
                                                          )));
                                        },
                                        // onPressed: () async {
                                        //   final url =
                                        //       '${userBookShelflist[index]!.bookId}.pdf';
                                        //   final file =
                                        //       await PDFApi.loadFileStorage(url);

                                        //   if (file == null) return;
                                        //   openPDF(context, file);
                                        // },
                                        style: ElevatedButton.styleFrom(
                                          primary:
                                              AnimeUI.cyan, // Background color
                                        ),
                                        icon: Icon(
                                          Icons.menu_book,
                                          size: 24.0,
                                        ),
                                        label: Text(
                                          'อ่านหนังสือ  ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => detailPage(
                                                bookId:
                                                    userBookShelflist[index]!
                                                            .bookId ??
                                                        '',
                                                bookDesc:
                                                    userBookShelflist[index]!
                                                            .bookDesc ??
                                                        '',
                                                bookshelfId:
                                                    userBookShelflist[index]!
                                                            .bookshelfId ??
                                                        '',
                                                bookPrice:
                                                    userBookShelflist[index]!
                                                            .bookPrice ??
                                                        '',
                                                bookTitle:
                                                    userBookShelflist[index]!
                                                            .bookTitle ??
                                                        '',
                                                bookAuthor:
                                                    userBookShelflist[index]!
                                                            .bookAuthor ??
                                                        '',
                                                bookNoOfPage:
                                                    userBookShelflist[index]!
                                                            .bookNoOfPage ??
                                                        '',
                                                booktypeName:
                                                    userBookShelflist[index]!
                                                            .booktypeName ??
                                                        '',
                                                publisherName:
                                                    userBookShelflist[index]!
                                                            .publisherName ??
                                                        '',
                                                bookIsbn:
                                                    userBookShelflist[index]!
                                                            .bookIsbn ??
                                                        '',
                                                bookcateId: '', // No data
                                                bookcateName:
                                                    userBookShelflist[index]!
                                                            .bookcateName ??
                                                        '',
                                                onlinetype: '', // No data
                                                t2Id: '', // No data
                                                imgLink:
                                                    userBookShelflist[index]!
                                                            .imgLink ??
                                                        '',
                                              ),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          primary:
                                              AnimeUI.cyan, // Background color
                                        ),
                                        icon: Icon(
                                          Icons.feed_rounded,
                                          size: 24.0,
                                        ),
                                        label: Text(
                                          'รายละเอียด ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          returnBook(
                                              bookshelfId:
                                                  userBookShelflist[index]!
                                                          .bookshelfId ??
                                                      '',
                                              DB_id: userBookShelflist[index]!
                                                      .bookId ??
                                                  '');
                                        },
                                        style: ElevatedButton.styleFrom(
                                          primary:
                                              AnimeUI.cyan, // Background color
                                        ),
                                        icon: Icon(
                                          Icons.keyboard_return_outlined,
                                          size: 24.0,
                                        ),
                                        label: Text(
                                          'คืนหนังสือ    ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          child: Container(
                            child: Column(
                              children: [
                                Card(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(20.0))),
                                  elevation: 10.0,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(20.0),
                                    ),
                                    child: Stack(
                                      children: <Widget>[
                                        Image.network(
                                          userBookShelflist[index]!
                                              .imgLink
                                              .toString(),
                                          height: 150,
                                          width: 200,
                                          fit: BoxFit.fitWidth,
                                        ),
                                        Container(
                                          margin: EdgeInsets.only(
                                              top: 160, left: 20),
                                          height: 30,
                                          width: 90,
                                          child: Stack(
                                            children: <Widget>[
                                              Center(
                                                  child: Text(
                                                userBookShelflist[index]!
                                                    .bookDesc
                                                    .toString(),
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: Colors.black),
                                              ))
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      : Image.asset('assets/images/logo_2ebook.png'),
                );
              } else {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  // child: Center(
                  //     child: hasmore
                  //         ? const CircularProgressIndicator()
                  //         : const Text('No data')),
                );
              }
            }),
      ),
    );
  }
}

showDataAlert(context) {
  // set up the button
  Widget okButton = TextButton(
    child: Text("OK"),
    onPressed: () {},
  );
  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    title: Text("My title"),
    content: Text("This is my message."),
    actions: [
      okButton,
    ],
  );
  // show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}

// void openPDF(BuildContext context, File file) => Navigator.of(context).push(
//       MaterialPageRoute(builder: (context) => PDFViewerPage(file: file)),
//     );
