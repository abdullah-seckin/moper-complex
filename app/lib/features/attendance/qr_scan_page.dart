import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api_client.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key, required this.api, required this.token});

  final ApiClient api;
  final String token;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _processing = false;
  String? _message;

  bool get _isDemoSession => widget.api.isDemoToken(widget.token);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final rawValue = capture.barcodes
        .where((barcode) => barcode.rawValue?.isNotEmpty == true)
        .firstOrNull
        ?.rawValue;
    if (rawValue == null) return;

    setState(() {
      _processing = true;
      _message = 'Konum doğrulanıyor...';
    });
    await _controller.stop();

    try {
      final position = await _currentPosition();
      final result = await widget.api.scanAttendance(
        token: widget.token,
        qrPayload: rawValue,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
      if (!mounted) return;
      final status = result['currentStatus'] == 'working'
          ? 'Giriş kaydedildi'
          : 'Çıkış kaydedildi';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(status)));
      Navigator.of(context).pop(true);
    } on ApiFailure catch (error) {
      await _fail(error.message);
    } catch (error) {
      await _fail('İşlem tamamlanamadı: $error');
    }
  }

  Future<void> _createDemoScan() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _message = 'Demo işlemi oluşturuluyor...';
    });
    await _controller.stop();
    try {
      final result = await widget.api.scanAttendance(
        token: widget.token,
        qrPayload: 'MOPER_DEMO_QR',
        latitude: 40.9862,
        longitude: 29.1244,
        accuracy: 8,
      );
      if (!mounted) return;
      final status = result['currentStatus'] == 'working'
          ? 'Demo giriş kaydedildi'
          : 'Demo çıkış kaydedildi';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(status)));
      Navigator.of(context).pop(true);
    } on ApiFailure catch (error) {
      await _fail(error.message);
    } catch (error) {
      await _fail('Demo işlem tamamlanamadı: $error');
    }
  }

  Future<void> _fail(String message) async {
    if (!mounted) return;
    setState(() {
      _processing = false;
      _message = message;
    });
    await _controller.start();
  }

  Future<Position> _currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw ApiFailure('Konum servisleri kapalı.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw ApiFailure('Konum izni reddedildi.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw ApiFailure('Konum izni kalıcı olarak reddedildi.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Doğrulama')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _handleDetect),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_processing)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.qr_code_scanner,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _message ?? 'QR kodu çerçevenin içine hizalayın.',
                          ),
                          if (_isDemoSession) ...[
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              onPressed: _processing ? null : _createDemoScan,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Demo işlemi oluştur'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
