import 'package:flutter/material.dart';
import 'package:hs_chat/webview_screen.dart';

class ProductPage extends StatefulWidget {
  final String? message;

  ProductPage({Key? key, required this.message}) : super(key: key);

  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  @override
  Widget build(BuildContext context) {
    final url = widget.message;

    return Scaffold(
      appBar: AppBar(
        title: const Text("HS Messenger"),
      ),
      body: url != null ? WebViewScreen(url: url) : Container(),
    );
  }
}
