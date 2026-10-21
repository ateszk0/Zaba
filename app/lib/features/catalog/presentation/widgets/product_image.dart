import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/product.dart';
import '../category_icons.dart';

/// The picture of a product: its photo (a bundled asset), or a tinted tile
/// with the category icon for products that have no photo. The tile also shows
/// while the photo is decoding.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.product,
    this.width = 84,
    this.height = 84,
    this.iconSize = 34,
    this.borderRadius = 14,
  });

  final Product product;
  final double width;
  final double height;
  final double iconSize;
  final double borderRadius;

  static const assetFolder = 'assets/images/products';

  @override
  Widget build(BuildContext context) {
    final path = product.imagePath;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Tile(product: product, iconSize: iconSize),
              if (path != null)
                Image.asset(
                  '$assetFolder/$path',
                  fit: BoxFit.cover,
                  // Decode no larger than needed; the files are 800 px wide.
                  cacheWidth: width.isFinite
                      ? (width * pixelRatio).round()
                      : null,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) =>
                          wasSynchronouslyLoaded
                          ? child
                          : AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: const Duration(milliseconds: 200),
                              child: child,
                            ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.product, required this.iconSize});

  final Product product;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    // Alternates green and tomato tiles, stable per product.
    final tomato = product.id.codeUnits
        .fold(0, (sum, unit) => sum + unit)
        .isOdd;
    return ColoredBox(
      color: tomato ? AppColors.tomato100 : AppColors.green100,
      child: Center(
        child: Icon(
          iconForCategoryKey(product.categoryId),
          size: iconSize,
          color: tomato ? AppColors.tomato700 : AppColors.green700,
        ),
      ),
    );
  }
}
