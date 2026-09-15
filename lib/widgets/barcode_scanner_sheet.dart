import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';

/// Full-screen camera scan view with a targeting frame + scan line, per the
/// approved New Sale interaction pattern. Pops with the scanned barcode
/// string, or null if the person backs out.
///
/// Explicitly requests camera permission before starting the camera â€”
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
  final TextEditingController _manualBarcodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      // autoStart: true (the default) is intentional here. mobile_scanner
      // starts the camera itself once the MobileScanner widget is actually
      // mounted and its native platform view/texture exists. Calling
      // controller.start() manually right after setState() races ahead of
      // that â€” setState() only *schedules* the rebuild, it doesn't run it
      // synchronously â€” so the native side tries to bind the camera to a
      // view that doesn't exist yet. That's what was producing the
      // "genericError / getClass() on a null object reference" crash.
      // Letting the controller auto-start avoids the race entirely.
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
    _manualBarcodeCtrl.dispose();
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
            MobileScanner(
              controller: _controller!,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) => _cameraErrorView(error),
            )
          else if (_permState == _PermState.checking)
            const Center(child: CircularProgressIndicator(color: KColors.greenBright))
          else
            _permissionDeniedView(),

          // Targeting frame â€” enlarged per feedback so it's easier to line
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

  Widget _cameraErrorView(MobileScannerException error) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 40),
            const SizedBox(height: 14),
            const Text(
              'Camera failed to start',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              error.errorCode.name,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700, fontSize: 13),
            ),
            if (error.errorDetails?.message != null) ...[
              const SizedBox(height: 6),
              Text(
                error.errorDetails!.message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: KColors.greenBright),
              onPressed: () {
                // Same reasoning as _requestPermission: swap in a fresh
                // controller with autoStart left on, and let the widget
                // (which will rebuild with this new controller) start the
                // camera itself once it's actually mounted. Do NOT call
                // start() manually here â€” that reintroduces the race.
                setState(() => _controller = MobileScannerController());
              },
              child: const Text('Retry', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),
            const Text(
              "If your camera keeps failing, you can type the number printed under the barcode instead:",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _manualBarcodeCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Barcode number',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38)),
                onPressed: () {
                  final v = _manualBarcodeCtrl.text.trim();
                  if (v.isNotEmpty) Navigator.pop(context, v);
                },
                child: const Text('Use this number', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Search instead', style: TextStyle(color: KColors.greenBright, fontWeight: FontWeight.w700)),
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