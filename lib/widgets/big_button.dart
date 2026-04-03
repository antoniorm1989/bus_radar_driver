import 'package:flutter/material.dart';

class BigButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final bool enabled;

  const BigButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = Colors.blue,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.42),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: enabled ? onPressed : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              color == Colors.red
                  ? Icons.stop_circle_outlined
                  : Icons.play_arrow_rounded,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(text),
          ],
        ),
      ),
    );
  }
}
