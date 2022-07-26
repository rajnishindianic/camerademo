import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camerademo/preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_native_image/flutter_native_image.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print(e.description);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CameraScreen(),
    );
  }
}

List<CameraDescription> cameras = <CameraDescription>[];

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  CameraController? controller;
  File? imageFile;
  late AnimationController _flashModeControlRowAnimationController;
  late Animation<double> _flashModeControlRowAnimation;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  bool _isRearCameraSelected = true;
  double? overlayWidth, overlayHeight, topMargin;

  // Counting pointers (number of user fingers on screen)
  int _pointers = 0;
  FlashMode? _currentFlashMode;

  @override
  void initState() {
    super.initState();
    onNewCameraSelected(cameras[0]);
    _ambiguate(WidgetsBinding.instance)?.addObserver(this);

    _flashModeControlRowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flashModeControlRowAnimation = CurvedAnimation(
      parent: _flashModeControlRowAnimationController,
      curve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _ambiguate(WidgetsBinding.instance)?.removeObserver(this);
    controller?.dispose();
    _flashModeControlRowAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 26,
      ),
      key: _scaffoldKey,
      body: _cameraPreviewWidget(),
      bottomNavigationBar: Container(
        height: size.height * 0.2,
        color: const Color(0xff0D0D0D),
        alignment: Alignment.center,
        child: Column(
          children: [
              Padding(
                padding: const EdgeInsets.only(
                    left: 49, right: 49, bottom: 33, top: 33),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        flashClick();
                      },
                      child: Container(
                        height: 48,
                        width: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(48),
                            color: const Color.fromRGBO(241, 243, 247, 0.05)),
                        child: Icon(
                          _currentFlashMode?.index == 0
                              ? Icons.flash_auto
                              : _currentFlashMode?.index == 1
                                  ? Icons.flash_on
                                  : Icons.flash_off,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        onTakePictureButtonPressed();
                      },
                      child: Container(
                        height: 44,
                        width: 44,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 2,
                            color: Colors.white,
                          ),
                        ),
                        child: Container(
                          height: 38.13,
                          width: 38.13,
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        onNewCameraSelected(
                            cameras[_isRearCameraSelected ? 1 : 0]);
                        setState(() {
                          _isRearCameraSelected = !_isRearCameraSelected;
                        });
                      },
                      child: Container(
                        height: 48,
                        width: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(48),
                            color: const Color.fromRGBO(241, 243, 247, 0.05)),
                        child: const Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Center(
        child: Text(
          'Loading...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.0,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    } else {
      return Listener(
        onPointerDown: (_) => _pointers++,
        onPointerUp: (_) => _pointers--,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(
              controller!,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
              ),
            ),
            cameraOverlay(
              padding: 0,
              aspectRatio: 4 / 5, // set aspect ratio
              color: Colors.black,
            ),
          ],
        ),
      );
    }
  }

  // function for cropping image
  Future<File> _resizePhoto(String filePath) async {
    ImageProperties properties =
        await FlutterNativeImage.getImageProperties(filePath);

    final int? width = properties.width;
    final int? height = properties.height;
    final double hp = ((height?.toDouble() ?? 0) * topMargin!) / overlayHeight!;

    final File croppedFile = await FlutterNativeImage.cropImage(filePath, 0,
        hp.toInt(), width ?? 0, ((height ?? 0) - (hp * 2)).toInt());
    List<int> imageBytes = await croppedFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);
    File file = File(filePath);
    File fixedFile = await file.writeAsBytes(
      img.encodeJpg(originalImage!),
      flush: true,
    );
    return fixedFile;
  }

  Widget cameraOverlay(
      {required double padding,
      required double aspectRatio,
      required Color color}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        overlayHeight = constraints.maxHeight;
        overlayWidth = constraints.maxWidth;
        double parentAspectRatio = constraints.maxWidth / constraints.maxHeight;
        double horizontalPadding;
        double verticalPadding;

        if (parentAspectRatio < aspectRatio) {
          horizontalPadding = padding;
          verticalPadding = (constraints.maxHeight -
                  ((constraints.maxWidth - 2 * padding) / aspectRatio)) /
              2;
          topMargin = verticalPadding;
        } else {
          verticalPadding = padding;
          horizontalPadding = (constraints.maxWidth -
                  ((constraints.maxHeight - 2 * padding) * aspectRatio)) /
              2;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: horizontalPadding,
                color: color,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: horizontalPadding,
                color: color,
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: EdgeInsets.only(
                  left: horizontalPadding,
                  right: horizontalPadding,
                ),
                height: verticalPadding,
                color: color,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: EdgeInsets.only(
                  left: horizontalPadding,
                  right: horizontalPadding,
                ),
                height: verticalPadding,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly two fingers on screen don't scale
    if (controller == null || _pointers != 2) {
      return;
    }

    _currentScale = (_baseScale * details.scale)
        .clamp(_minAvailableZoom, _maxAvailableZoom);

    await controller!.setZoomLevel(_currentScale);
  }

  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.max,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    controller = cameraController;

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
      if (cameraController.value.hasError) {
        print('Camera error ${cameraController.value.errorDescription}');
      }
    });

    try {
      await cameraController.initialize();
      await cameraController
          .lockCaptureOrientation(DeviceOrientation.portraitUp);
      await Future.wait(<Future<Object?>>[
        cameraController
            .getMaxZoomLevel()
            .then((double value) => _maxAvailableZoom = value),
        cameraController
            .getMinZoomLevel()
            .then((double value) => _minAvailableZoom = value),
      ]);
      await setFlashMode(FlashMode.off);
      _currentFlashMode = controller!.value.flashMode;
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void onTakePictureButtonPressed() {
    takePicture().then((File? file) async {
      if (mounted) {
        File imgFile = await _resizePhoto(file?.path ?? '');
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PreviewScreen(
              imageFile: imgFile,
            ),
          ),
        );
      }
    });
  }

  void flashClick() {
    //auto - 1, 0- off, 2- always 3- torch
    if (_currentFlashMode?.index == 0) {
      setFlashMode(FlashMode.auto);
    } else if (_currentFlashMode?.index == 1) {
      setFlashMode(FlashMode.always);
    } else {
      setFlashMode(FlashMode.off);
    }
    setState(() {});
  }

  void onFlashModeButtonPressed() {
    if (_flashModeControlRowAnimationController.value == 1) {
      _flashModeControlRowAnimationController.reverse();
    } else {
      _flashModeControlRowAnimationController.forward();
    }
  }

  Future<void> setFlashMode(FlashMode mode) async {
    if (controller == null) {
      return;
    }

    try {
      await controller!.setFlashMode(mode);
      _currentFlashMode = mode;
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<File?> takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      print('Error: select a camera first.');
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      final XFile xfile = await cameraController.takePicture();
      ImageProperties properties =
      await FlutterNativeImage.getImageProperties(xfile.path);
      if ((properties.width ?? 0) > (properties.height ?? 0)) {
        List<int> imageBytes = await xfile.readAsBytes();
        img.Image? originalImage = img.decodeImage(imageBytes);
        if (!_isRearCameraSelected) {
          img.flipHorizontal(originalImage!);
        }
        File file = File(xfile.path);
        File fixedFile = await file.writeAsBytes(
          img.encodeJpg(originalImage!),
          flush: true,
        );
        return fixedFile;
      } else {
        return File(xfile.path);
      }
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  void _showCameraException(CameraException e) {
    print(e.description);
  }
}

T? _ambiguate<T>(T? value) => value;
