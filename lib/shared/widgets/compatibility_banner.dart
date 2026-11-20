import 'package:flutter/material.dart';

class CompatibilityBanner extends StatelessWidget {
  const CompatibilityBanner({required this.message, this.onDetails, super.key});
  final String message;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFB020).withValues(alpha: .09),
      child: InkWell(
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFFFB020),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
              if (onDetails != null)
                const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
