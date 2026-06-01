import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../app_theme.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.qrCode,
    ],
  );
  late final AnimationController _scanAnim;
  bool _handled = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes.firstWhere(
      (b) => b.rawValue != null && b.rawValue!.trim().isNotEmpty,
      orElse: () => Barcode(rawValue: null),
    );
    final value = code.rawValue?.trim();
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ສະແກນບາໂຄດ',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Dark scrim overlay to focus attention on scan area.
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.22, 0.78, 1.0],
                ),
              ),
            ),
          ),
          // Targeting frame with animated corner brackets + scan line.
          Center(
            child: SizedBox(
              width: 280,
              height: 200,
              child: Stack(
                children: [
                  // Animated scan line.
                  AnimatedBuilder(
                    animation: _scanAnim,
                    builder: (_, __) {
                      return Positioned(
                        top: 200 * _scanAnim.value - 1,
                        left: 12,
                        right: 12,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.85),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Corner brackets.
                  const Positioned(
                      top: 0, left: 0, child: _CornerBracket(rotation: 0)),
                  const Positioned(
                      top: 0,
                      right: 0,
                      child: _CornerBracket(rotation: 1)),
                  const Positioned(
                      bottom: 0,
                      right: 0,
                      child: _CornerBracket(rotation: 2)),
                  const Positioned(
                      bottom: 0,
                      left: 0,
                      child: _CornerBracket(rotation: 3)),
                ],
              ),
            ),
          ),
          // Bottom action dock.
          Positioned(
            left: kSpace5,
            right: kSpace5,
            bottom: kSpace8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hint card.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: kSpace4, vertical: kSpace3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(kRadiusPill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ຊີ້ກ້ອງໃສ່ບາໂຄດ ຫຼື QR code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: kSpace5),
                // Tool dock.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CircleTool(
                      icon: _torchOn
                          ? Icons.flashlight_on_rounded
                          : Icons.flashlight_off_rounded,
                      active: _torchOn,
                      onTap: () {
                        _controller.toggleTorch();
                        setState(() => _torchOn = !_torchOn);
                      },
                    ),
                    const SizedBox(width: kSpace4),
                    _CircleTool(
                      icon: Icons.cameraswitch_rounded,
                      onTap: () => _controller.switchCamera(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  // rotation: 0=tl, 1=tr, 2=br, 3=bl — drawn as ASCII corner.
  const _CornerBracket({required this.rotation});
  final int rotation;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: rotation,
      child: SizedBox(
        width: 28,
        height: 28,
        child: CustomPaint(
          painter: _CornerPainter(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final p1 = Offset(0, size.height);
    final p2 = const Offset(0, 0);
    final p3 = Offset(size.width, 0);
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircleTool extends StatelessWidget {
  const _CircleTool({
    required this.icon,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primary : Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
