// lib/create/upload/upload_progress_bar.dart
// Бари progress дар боли Home — мисли Instagram (thumbnail + ҳолат + хати кабуд→сабз).
import 'package:flutter/material.dart';
import 'post_upload_service.dart';
import '../../core/ui/app_icons.dart';

class UploadProgressBar extends StatelessWidget {
  const UploadProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UploadState?>(
      valueListenable: PostUploadService.instance.state,
      builder: (_, s, __) {
        if (s == null) return const SizedBox.shrink();
        final String label = s.error
            ? 'Нашр нашуд'
            : s.done
                ? 'Нашр шуд'
                : 'Бор мешавад...';
        return Container(
          color: const Color(0xFF0A0A0A),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(s.thumb,
                    width: 36, height: 36, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 36, height: 36, color: const Color(0xFF222222))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: s.error ? const Color(0xFFFF3040) : Colors.white,
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              if (s.done)
                const Icon(AppIcons.check_circle, color: Color(0xFF00E87A), size: 20),
              if (s.error)
                const Icon(AppIcons.error_outline, color: Color(0xFFFF3040), size: 20),
            ]),
            if (!s.done && !s.error) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Color(0xFF00C6FF), Color(0xFF00E87A)],
                  ).createShader(rect),
                  child: LinearProgressIndicator(
                    value: s.progress > 0 ? s.progress : null,
                    minHeight: 3,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            ],
          ]),
        );
      },
    );
  }
}
