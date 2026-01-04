import 'package:flutter/material.dart';
import '../../presentation/widgets/roulette_wheel.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final List<RouletteItem> _items = [
    RouletteItem(text: "500 Coins", color: Colors.purpleAccent),
    RouletteItem(text: "Try Again", color: Colors.grey),
    RouletteItem(text: "Free VIP", color: Colors.blueAccent),
    RouletteItem(text: "Mystery Box", color: Colors.orangeAccent),
    RouletteItem(text: "1000 Coins", color: Colors.greenAccent),
    RouletteItem(text: "Jackpot", color: Colors.redAccent),
    RouletteItem(text: "No Luck", color: Colors.grey[800]!),
    RouletteItem(text: "20 Coins", color: Colors.tealAccent),
  ];

  void _onSpinEnd(int winnerIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Result", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: _items[winnerIndex].color, size: 50),
            const SizedBox(height: 20),
            Text(
              "You got: ${_items[winnerIndex].text}",
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background - Cyberpunk Grid
          Positioned.fill(child: CustomPaint(painter: GridPainter())),

          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "LUCKY WHEEL",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(color: Colors.purpleAccent, blurRadius: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),

                  // Wheel Container with Pointer (Now Internalized)
                  RouletteWheel(items: _items, onSpinEnd: _onSpinEnd),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.purpleAccent.withOpacity(0.1)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
