import 'package:flutter/material.dart';

import '../theme/paperflow_theme.dart';

class PaperDiagram extends StatelessWidget {
  const PaperDiagram({super.key, this.accent = const Color(0xFF4A7FCA)});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaperFlowColors.line),
      ),
      child: CustomPaint(
        painter: _PaperDiagramPainter(accent),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PaperDiagramPainter extends CustomPainter {
  const _PaperDiagramPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = PaperFlowColors.ink.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = accent.withValues(alpha: 0.28);
    final nodeFill = Paint()..color = Colors.white;

    final left = Rect.fromLTWH(18, 22, 65, 44);
    final rightA = Rect.fromLTWH(size.width - 132, 30, 44, 28);
    final rightB = Rect.fromLTWH(size.width - 61, 30, 36, 28);
    canvas.drawRRect(
        RRect.fromRectAndRadius(left, const Radius.circular(7)), nodeFill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(left, const Radius.circular(7)), line);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rightA, const Radius.circular(7)), nodeFill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rightA, const Radius.circular(7)), line);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rightB, const Radius.circular(7)), nodeFill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rightB, const Radius.circular(7)), line);

    final centerX = size.width * 0.47;
    final top = Path()
      ..moveTo(centerX - 35, 16)
      ..lineTo(centerX + 35, 16)
      ..lineTo(centerX + 19, 40)
      ..lineTo(centerX - 19, 40)
      ..close();
    final bottom = Path()
      ..moveTo(centerX - 19, 47)
      ..lineTo(centerX + 19, 47)
      ..lineTo(centerX + 35, 72)
      ..lineTo(centerX - 35, 72)
      ..close();
    canvas.drawPath(top, fill);
    canvas.drawPath(top, line);
    canvas.drawPath(bottom, fill);
    canvas.drawPath(bottom, line);

    void arrow(double fromX, double toX) {
      final y = 44.0;
      canvas.drawLine(Offset(fromX, y), Offset(toX, y), line);
      canvas.drawLine(Offset(toX, y), Offset(toX - 5, y - 4), line);
      canvas.drawLine(Offset(toX, y), Offset(toX - 5, y + 4), line);
    }

    arrow(92, centerX - 44);
    arrow(centerX + 43, rightA.left - 8);
    arrow(rightA.right + 8, rightB.left - 8);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    void label(String text, Offset offset,
        {double size = 10, FontWeight weight = FontWeight.w600}) {
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
            color: PaperFlowColors.ink, fontSize: size, fontWeight: weight),
      );
      textPainter.layout();
      textPainter.paint(canvas, offset);
    }

    label('Pretrained', const Offset(25, 29), size: 9);
    label('W', const Offset(43, 47), size: 11, weight: FontWeight.w800);
    label('+', Offset(98, 34), size: 22, weight: FontWeight.w800);
    label('B = 0', Offset(centerX - 14, 22), size: 8);
    label('A ~ N(0, σ²)', Offset(centerX - 27, 55), size: 8);
    label('h', Offset(rightA.left + 17, 35), size: 12);
    label('y', Offset(rightB.left + 13, 35), size: 12);
  }

  @override
  bool shouldRepaint(covariant _PaperDiagramPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
