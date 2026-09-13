import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';

/// Full-screen camera scan view with a targeting frame + scan line, per the
/// approved New Sale interaction pattern. Pops with the scanned barcode
/// string, or null if the person backs out.
///
/// Explicitly requests camera permission before starting the camera —
/// without this, mobile_scanner silently fails into its error state (the
/// "!" icon) on first launch, which is what "scanning doesn't work" usually
/// turns out to be.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

enum _PermState { checking, granted, denied, permanentlyDenied }

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? _controller;
  bool _handled = false;
  _PermState _permState = _PermState.checking;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() {
        _controller = MobileScannerController();
        _permState = _PermState.granted;
      });
    } else if (status.isPermanentlyDenied) {
      setState(() => _permState = _PermState.permanentlyDenied);
    } else {
      setState(() => _permState = _PermState.denied);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null) return;
    _handled = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_permState == _PermState.granted && _controller != null)
            MobileScanner(controller: _controller!, onDetect: _onDetect)
          else if (_permState == _PermState.checking)
            const Center(child: CircularProgressIndicator(color: KColors.greenBright))
          else
            _permissionDeniedView(),

          // Targeting frame — enlarged per feedback so it's easier to line
          // a barcode up inside it.
          if (_permState == _PermState.granted)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: KColors.greenBright, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context, null),
                  ),
                  const Spacer(),
                  if (_permState == _PermState.granted)
                    IconButton(
                      icon: const Icon(Icons.flash_on, color: Colors.white),
                      onPressed: () => _controller?.toggleTorch(),
                    ),
                ],
              ),
            ),
          ),

          if (_permState == _PermState.granted)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const Text(
                    'Point the camera at a barcode',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Search instead', style: TextStyle(color: KColors.greenBright, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _permissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              _permState == _PermState.permanentlyDenied
                  ? "Camera access is turned off for Kantemba. Open Settings to allow it."
                  : "Kantemba needs camera access to scan barcodes.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: KColors.greenBright),
              onPressed: _permState == _PermState.permanentlyDenied ? openAppSettings : _requestPermission,
              child: Text(
                _permState == _PermState.permanentlyDenied ? 'Open Settings' : 'Allow camera access',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Search instead', style: TextStyle(color: KColors.greenBright, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
