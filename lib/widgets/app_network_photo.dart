import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';

/// 인터넷 사진 (식단 사진 등). 한 번 받은 사진은 기기에 저장해 두고(`cached_network_image`)
/// 다음부터는 바로 보인다. 그릴 칸 크기 × 화면 배율로 줄여 풀어서 메모리와 그리는 시간을 아낀다.
///
/// 받는 동안은 [placeholderColor] 바탕, 실패하면 사진 아이콘.
class AppNetworkPhoto extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Color? placeholderColor;
  final double iconSize;

  const AppNetworkPhoto({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderColor,
    this.iconSize = AppSize.icon,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 칸 크기를 모르면(무한) 화면 폭으로 줄인다.
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final decodeWidth = (width * dpr).round().clamp(64, 2048);
        final background = placeholderColor ?? AppColors.canvasCard;
        return CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
          height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
          memCacheWidth: decodeWidth,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, _) => ColoredBox(color: background),
          errorWidget: (_, _, _) => ColoredBox(
            color: background,
            child: Center(
              child: Icon(
                AppIcons.image,
                size: iconSize,
                color: AppColors.mute,
              ),
            ),
          ),
        );
      },
    );
  }
}
