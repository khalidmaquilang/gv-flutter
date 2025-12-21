import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/draggable_text_widget.dart'; // For OverlayText model

class TextEditorScreen extends StatefulWidget {
  final OverlayText? initialText;

  const TextEditorScreen({super.key, this.initialText});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late TextEditingController _textController;
  late OverlayText _currentSettings;
  bool _showColorPicker = false;

  // Selected Tab for Bottom Menu: 0=Font, 1=Color, 2=Style(hidden/integrated)
  // Actually, let's follow the request:
  // Top: Color, Align, Border
  // Right: Zoom/Size
  // Bottom: Fonts

  final List<Color> _colors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  final List<String> _fonts = [
    'Roboto',
    'Open Sans',
    'Lato',
    'Montserrat',
    'Oswald',
    'Raleway',
    'Poppins',
    'Merriweather',
    'Pacifico',
    'Lobster',
    'Dancing Script',
    'Caveat',
    'Shadows Into Light',
    'Indie Flower',
  ];

  @override
  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _currentSettings = OverlayText(
        text: widget.initialText!.text,
        position: widget.initialText!.position,
        color: widget.initialText!.color,
        fontSize: widget.initialText!.fontSize,
        textAlign: widget.initialText!.textAlign,
        fontFamily: widget.initialText!.fontFamily,
        hasBackground: widget.initialText!.hasBackground,
        backgroundColor: widget.initialText!.backgroundColor,
      );
    } else {
      // Placeholder, will position in didChangeDependencies
      _currentSettings = OverlayText(
        text: "",
        position: const Offset(0, 0), // Temp
        color: Colors.white,
        fontSize: 24,
        textAlign: TextAlign.center,
        fontFamily: 'Roboto',
        hasBackground: false,
        backgroundColor: Colors.black45,
      );
    }

    _textController = TextEditingController(text: _currentSettings.text);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set center position for new text
    if (widget.initialText == null &&
        _currentSettings.position == const Offset(0, 0)) {
      final size = MediaQuery.of(context).size;
      _currentSettings.position = Offset(
        size.width / 2 - 50,
        size.height / 2 - 20,
      ); // Approx center
    }
  }

  void _cycleAlignment() {
    setState(() {
      if (_currentSettings.textAlign == TextAlign.left) {
        _currentSettings.textAlign = TextAlign.center;
      } else if (_currentSettings.textAlign == TextAlign.center) {
        _currentSettings.textAlign = TextAlign.right;
      } else {
        _currentSettings.textAlign = TextAlign.left;
      }
    });
  }

  void _cycleBackground() {
    setState(() {
      if (!_currentSettings.hasBackground) {
        // Mode 1: Background On (Standard)
        _currentSettings.hasBackground = true;
        _currentSettings.backgroundColor =
            _currentSettings.color == Colors.white
            ? Colors.black.withOpacity(0.5)
            : Colors.white.withOpacity(0.8);
        // If text is black, bg white. If text white, bg black.
        // Simplification: Invert color for bg logic or just semi-transparent
        if (_currentSettings.color == Colors.black) {
          _currentSettings.backgroundColor = Colors.white.withOpacity(0.8);
        } else {
          _currentSettings.backgroundColor = Colors.black.withOpacity(0.5);
        }
      } else {
        // Toggle off
        _currentSettings.hasBackground = false;
      }
    });
  }

  TextStyle _getGoogleFont(
    String family,
    double size,
    Color color, {
    bool withShadow = true,
  }) {
    TextStyle style;
    try {
      style = GoogleFonts.getFont(family);
    } catch (e) {
      style = GoogleFonts.roboto();
    }
    return style.copyWith(
      fontSize: size,
      color: color,
      fontWeight: FontWeight.bold,
      shadows: withShadow && !_currentSettings.hasBackground
          ? const [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 3.0,
                color: Colors.black,
              ),
            ]
          : [],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(
        0.6,
      ), // Dimmed but visible video
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Top Menu (Cancel, Align, Background, Color, Done)
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      Row(
                        children: [
                          // Alignment
                          IconButton(
                            onPressed: _cycleAlignment,
                            icon: Icon(_getAlignIcon(), color: Colors.white),
                          ),
                          // Background Style
                          IconButton(
                            onPressed: _cycleBackground,
                            icon: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                color: _currentSettings.hasBackground
                                    ? Colors.white
                                    : Colors.transparent,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                "T",
                                style: TextStyle(
                                  color: _currentSettings.hasBackground
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // Color Picker Toggle
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showColorPicker = !_showColorPicker;
                              });
                            },
                            icon: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.red,
                                    Colors.green,
                                    Colors.blue,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          if (_textController.text.isNotEmpty) {
                            _currentSettings.text = _textController.text;
                            Navigator.pop(context, _currentSettings);
                          } else {
                            Navigator.pop(context); // Empty = Cancel
                          }
                        },
                        child: const Text(
                          "Done",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Color List (Collapsible)
                  if (_showColorPicker)
                    Container(
                      height: 40,
                      margin: const EdgeInsets.only(top: 10),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _colors.length,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemBuilder: (context, index) {
                          final color = _colors[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentSettings.color = color;
                                // Auto-adjust background contrast if needed
                                if (_currentSettings.hasBackground) {
                                  if (color == Colors.white) {
                                    _currentSettings.backgroundColor = Colors
                                        .black
                                        .withOpacity(0.8);
                                  } else if (color == Colors.black) {
                                    _currentSettings.backgroundColor = Colors
                                        .white
                                        .withOpacity(0.8);
                                  }
                                }
                              });
                            },
                            child: Container(
                              width: 30,
                              height: 30,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // 2. Center Text Input
            Positioned.fill(
              top: 100, // Below top menu
              bottom: 150, // Above bottom menu
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: IntrinsicWidth(
                    child: Container(
                      decoration: _currentSettings.hasBackground
                          ? BoxDecoration(
                              color: _currentSettings.backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                            )
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: _textController,
                        autofocus: true,
                        textAlign: _currentSettings.textAlign,
                        maxLines: null,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: _getGoogleFont(
                          _currentSettings.fontFamily,
                          _currentSettings.fontSize,
                          _currentSettings.color,
                        ),
                        cursorColor: _currentSettings.color == Colors.white
                            ? Colors.blue
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Right Menu (Zoom Slider)
            Positioned(
              right: 10,
              top: 150,
              bottom: 150,
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: _currentSettings.fontSize,
                  min: 12,
                  max: 80,
                  activeColor: Colors.white,
                  inactiveColor: Colors.grey,
                  onChanged: (val) {
                    setState(() {
                      _currentSettings.fontSize = val;
                    });
                  },
                ),
              ),
            ),

            // 4. Bottom Menu (Fonts) - Reduced height
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 60, // Reduced from 100
                color: Colors.black.withOpacity(0.3),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(10),
                  itemCount: _fonts.length,
                  itemBuilder: (context, index) {
                    final font = _fonts[index];
                    final isSelected = _currentSettings.fontFamily == font;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentSettings.fontFamily = font;
                        });
                      },
                      child: Container(
                        alignment: Alignment.center,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : Border.all(color: Colors.grey.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(20),
                          color: isSelected
                              ? Colors.black45
                              : Colors.transparent,
                        ),
                        child: Text(
                          font,
                          style: _getGoogleFont(
                            font,
                            16,
                            Colors.white,
                            withShadow: false,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAlignIcon() {
    switch (_currentSettings.textAlign) {
      case TextAlign.left:
        return Icons.format_align_left;
      case TextAlign.right:
        return Icons.format_align_right;
      case TextAlign.center:
      default:
        return Icons.format_align_center;
    }
  }
}
