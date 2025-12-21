import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OverlayText {
  String text;
  Offset position;
  Color color;
  double fontSize;
  TextAlign textAlign;
  String fontFamily;
  bool hasBackground;
  Color backgroundColor;

  OverlayText({
    required this.text,
    this.position = const Offset(100, 100),
    this.color = Colors.white,
    this.fontSize = 24,
    this.textAlign = TextAlign.center,
    this.fontFamily = 'Open Sans',
    this.hasBackground = false,
    this.backgroundColor = Colors.black45,
  });
}

class DraggableTextWidget extends StatefulWidget {
  final OverlayText overlayText;
  final VoidCallback onTap;
  final VoidCallback? onDragStart;
  final Function(Offset)? onDragUpdate;
  final Function(Offset) onDragEnd;
  final bool isEditable;

  const DraggableTextWidget({
    super.key,
    required this.overlayText,
    required this.onTap,
    required this.onDragEnd,
    this.onDragStart,
    this.onDragUpdate,
    this.isEditable = true,
  });

  @override
  State<DraggableTextWidget> createState() => _DraggableTextWidgetState();
}

class _DraggableTextWidgetState extends State<DraggableTextWidget> {
  late Offset _position;
  double _baseFontSize = 24.0;
  double _scaleFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _position = widget.overlayText.position;
    _baseFontSize = widget.overlayText.fontSize;
  }

  @override
  void didUpdateWidget(DraggableTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.overlayText.position != _position) {
      // Only sync if external change is significant?
      // Actually, we are the source of truth for dragging.
      // But if we just edited the text and the editor returned a modified object (same ref or different?),
      // PreviewScreen seems to update properties of existing object.
      // So position stays same.
      // But if we delete others, this widget handles a different overlay? No, ObjectKey prevents that.
      // So this might not be strictly needed but good practice.
      // Let's rely on initState for now unless we see issues.
    }
    // Update font size if edited
    if (widget.overlayText.fontSize != _baseFontSize) {
      _baseFontSize = widget.overlayText.fontSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.isEditable ? widget.onTap : null,
        onScaleStart: (details) {
          if (!widget.isEditable) return;
          _baseFontSize = widget.overlayText.fontSize;
          _scaleFactor = 1.0;
          widget.onDragStart?.call();
        },
        onScaleUpdate: (details) {
          if (!widget.isEditable) return;

          setState(() {
            // Handle Dragging (Focal Point)
            _position += details.focalPointDelta;

            // Handle Scaling
            _scaleFactor = details.scale;
            double newSize = _baseFontSize * _scaleFactor;
            // Clamp font size to reasonable limits
            widget.overlayText.fontSize = newSize.clamp(12.0, 100.0);
          });

          widget.onDragUpdate?.call(details.focalPoint);
        },
        onScaleEnd: (details) {
          if (!widget.isEditable) return;
          _baseFontSize = widget.overlayText.fontSize;
          widget.onDragEnd(_position);
        },
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.overlayText.hasBackground
                  ? widget.overlayText.backgroundColor
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: widget.isEditable
                  ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                  : null,
            ),
            child: Text(
              widget.overlayText.text,
              textAlign: widget.overlayText.textAlign,
              style: GoogleFonts.getFont(
                widget.overlayText.fontFamily,
                textStyle: TextStyle(
                  color: widget.overlayText.color,
                  fontSize: widget.overlayText.fontSize,
                  fontWeight: FontWeight.bold,
                  shadows: !widget.overlayText.hasBackground
                      ? const [
                          Shadow(
                            offset: Offset(1.0, 1.0),
                            blurRadius: 3.0,
                            color: Colors.black,
                          ),
                        ]
                      : [],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
