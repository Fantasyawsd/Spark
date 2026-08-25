import 'package:flutter/material.dart';

import '../theme/spark_theme.dart';

Future<T?> showSparkSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor ?? SparkColors.of(context).barrier,
    builder: builder,
  );
}

class SparkSheetHandle extends StatelessWidget {
  const SparkSheetHandle({super.key, this.height = 14});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: SparkColors.of(context).subtle,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}
