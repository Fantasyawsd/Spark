import 'package:flutter/material.dart';

import '../theme/paperflow_theme.dart';

Future<T?> showPaperFlowSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  Color barrierColor = const Color(0x660B1020),
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor,
    builder: builder,
  );
}

class PaperFlowSheetHandle extends StatelessWidget {
  const PaperFlowSheetHandle({super.key, this.height = 14});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          width: 34,
          height: 4,
          decoration: BoxDecoration(
            color: PaperFlowColors.line,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}
