import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ap_widgets.dart';
import '../../../catalog/data/repository/celestial_catalog_repository.dart';
import '../../../catalog/domain/models/celestial_object.dart';
import 'object_display.dart';

/// Miniatura cuadrada del objeto para las listas. Sin imagen muestra su
/// ícono, con el mismo tamaño.
class ObjectThumbnail extends StatelessWidget {
  final CelestialObject object;
  final double size;

  const ObjectThumbnail(this.object, {super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final fallback = ApListIcon(ObjectDisplay.icon(object), size: size);
    final image = CelestialCatalogRepository().imageFor(object);
    if (image == null) return fallback;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        image.asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // The list decodes a thumbnail, not the full picture.
        cacheWidth: pixels * 4 ~/ 3,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

/// Foto del objeto para su ficha, con el crédito debajo. Todas las imágenes
/// del catálogo son 4:3, así que ocupan el mismo espacio. No muestra nada si
/// el objeto no tiene imagen.
class ObjectPhoto extends StatelessWidget {
  final CelestialObject object;

  const ObjectPhoto(this.object, {super.key});

  @override
  Widget build(BuildContext context) {
    final image = CelestialCatalogRepository().imageFor(object);
    if (image == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.asset(
              image.asset,
              fit: BoxFit.cover,
              semanticLabel: 'Imagen de ${object.name}',
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: ApColors.surface2,
                child: Center(
                  child: Icon(Icons.image_not_supported, color: ApColors.muted),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Imagen: ${image.credit}',
          style: ApText.small.copyWith(fontSize: 11.5),
        ),
      ],
    );
  }
}
