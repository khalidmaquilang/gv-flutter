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

  // Mock data - replace with actual state management
  bool _usesCoupon = false; // Toggle between Coins and Coupons
  int _couponBalance = 5; // Mock coupon count
  int _coinBalance = 1200; // Mock coin count

  void _onSpinEnd(int winnerIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.grey[900]!, Colors.black],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _items[winnerIndex].color, width: 2),
            boxShadow: [
              BoxShadow(
                color: _items[winnerIndex].color.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Animated Star Icon
              Center(
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Icon(
                        Icons.stars_rounded,
                        color: _items[winnerIndex].color,
                        size: 80,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Congratulations Text
              const Text(
                "🎉 CONGRATULATIONS! 🎉",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),

              // Prize Display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _items[winnerIndex].color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _items[winnerIndex].color.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  _items[winnerIndex].text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _items[winnerIndex].color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _items[winnerIndex].color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "CLAIM PRIZE",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Top Bar with Balance and Info
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Coupon Balance
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00FFC2), Color(0xFF00B8FF)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FFC2).withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.confirmation_number,
                              color: Colors.black,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "$_couponBalance Coupons",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Info Button
                      IconButton(
                        icon: const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          // Show coupon info dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.grey[900],
                              title: const Text(
                                "How to get Coupons?",
                                style: TextStyle(color: Colors.white),
                              ),
                              content: const Text(
                                "• Purchase ₱150 in gifts to start earning\n"
                                "• Get 1 coupon for every ₱10 spent\n"
                                "• Use coupons for free spins!\n"
                                "• Win amazing prizes!",
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("GOT IT"),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Main content
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 10),

                      // Title
                      const Text(
                        "LUCKY WHEEL",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(color: Colors.purpleAccent, blurRadius: 20),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Spin Mode Toggle
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.grey[800]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _usesCoupon = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: !_usesCoupon
                                        ? const LinearGradient(
                                            colors: [
                                              Colors.amber,
                                              Colors.orange,
                                            ],
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.monetization_on,
                                        color: !_usesCoupon
                                            ? Colors.black
                                            : Colors.grey,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Coins",
                                        style: TextStyle(
                                          color: !_usesCoupon
                                              ? Colors.black
                                              : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _usesCoupon = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: _usesCoupon
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFF00FFC2),
                                              Color(0xFF00B8FF),
                                            ],
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.confirmation_number,
                                        color: _usesCoupon
                                            ? Colors.black
                                            : Colors.grey,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Coupon",
                                        style: TextStyle(
                                          color: _usesCoupon
                                              ? Colors.black
                                              : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Balance Display
                      Text(
                        _usesCoupon
                            ? "Balance: $_couponBalance Coupons"
                            : "Balance: $_coinBalance Coins",
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),

                      const SizedBox(height: 15),

                      // Wheel Container
                      Flexible(
                        child: Center(
                          child: RouletteWheel(
                            items: _items,
                            onSpinEnd: _onSpinEnd,
                          ),
                        ),
                      ),

                      const SizedBox(height: 70), // Space for navigation bar
                    ],
                  ),
                ),
              ],
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
