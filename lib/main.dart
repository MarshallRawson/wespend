import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const APP_EXT = "apps/cospend/";

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: UrlInputScreen(),
    );
  }
}

class UrlInputScreen extends StatefulWidget {
  @override
  _UrlInputScreenState createState() => _UrlInputScreenState();
}


class _UrlInputScreenState extends State<UrlInputScreen> {
  TextEditingController _controller = TextEditingController();
  String? savedUrl;
  String? _errorMsg = null;
  void onError(String e) {
    setState(() {
      _errorMsg = e;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  void _loadSavedUrl() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      if (!kDebugMode)
        savedUrl = prefs.getString('saved_url');
    });

    if (savedUrl != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => WebViewScreen(url: savedUrl!, onError: onError)));
    }
  }

  void _saveUrl(String url) async {
    if (!url.startsWith("http")) url = "https://$url";
    if (!url.endsWith("/")) url = "$url/";
    url = "${url}${APP_EXT}";
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_url', url);
    Navigator.push(context, MaterialPageRoute(builder: (context) => WebViewScreen(url: url, onError: onError)));
  }

  @override
  Widget build(BuildContext context) {
    var widgets = <Widget>[
      TextField(
        controller: _controller,
        decoration: InputDecoration(labelText: "Server URL"),
      ),
      SizedBox(height: 10),
      ElevatedButton(
        onPressed: () {
          _saveUrl(_controller.text);
          setState(() {
            _errorMsg = null;
          });
        },
        child: Text("Go"),
      ),
    ];
    if (_errorMsg != null) {
      widgets += [Text(_errorMsg!)];
    }
    return Scaffold(
      appBar: AppBar(title: Text("Server URL")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: widgets,
        ),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final String url;
  final void Function(String) onError;
  WebViewScreen({required this.url, required this.onError});

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setUserAgent(
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36"
      )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'Print',
        onMessageReceived: (JavaScriptMessage message) {
          if (kDebugMode) print(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _controller.runJavaScript(
              "const editSidebar = setInterval(() => {"
              "  var sidebar = document.querySelector('.app-navigation');"
              "  if (sidebar) {"
              "    Print.postMessage('sidebar edited!');"
              "    clearInterval(editSidebar);"
              "    sidebar.style.backgroundColor = 'white';"
              "    sidebar.style.opacity = '1';"
              "  } else {"
              "    Print.postMessage('sidebar not yet loaded!');"
              "  }"
              "}, 500);"
              "const editMeta = setInterval(() => {"
              "  var meta = document.querySelector('meta[name=\"viewport\"]');"
              "  if (meta) {"
              "    Print.postMessage('meta edited!');"
              "    clearInterval(editMeta);"
              "    meta.setAttribute('content', meta.content + ' user-scalable=no');"
              "  } else {"
              "    Print.postMessage('meta not yet loaded!');"
              "  }"
              "}, 500);"
              "const editHeader = setInterval(() => {"
              "  var header = document.querySelector('header');"
              "  if (header) {"
              "    Print.postMessage('header edited!');"
              "    clearInterval(editHeader);"
              "    header.remove();"
              "  } else {"
              "    Print.postMessage('header not yet loaded!');"
              "  }"
              "}, 500);"
            );
          },
          onWebResourceError: (error) {
            final errorMsg = "Failed to load '${widget.url}':\n${error.description}";
            widget.onError(errorMsg);
            if (kDebugMode) print(errorMsg);
            Navigator.pop(context);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kDebugMode ? AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        )
      ) : null,
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          Align(
            alignment: Alignment.topRight,
            child: FloatingActionButton(
              onPressed: () {
                _controller.reload();
              },
              child: Icon(Icons.refresh),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              mini: true,
            ),
          ),
        ]
      )
    );
  }
}
