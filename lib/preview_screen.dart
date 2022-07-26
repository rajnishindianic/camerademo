import 'dart:io';

import 'package:flutter/material.dart';

class PreviewScreen extends StatelessWidget {
  const PreviewScreen({Key? key, required this.imageFile}) : super(key: key);

  final File imageFile;

  @override
  Widget build(BuildContext context) {
    double ratio = MediaQuery.of(context).size.height / MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: AspectRatio(
          aspectRatio: 4 / 5, // change ratio according to requirement
          child: Image(
            image: FileImage(
              imageFile,
            ),
            fit: ratio > 1.8 ? BoxFit.fill : BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
