import 'package:flutter/material.dart';

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
    return ApThumbnail(
      asset: CelestialCatalogRepository().imageFor(object)?.asset,
      size: size,
      fallback: ApListIcon(ObjectDisplay.icon(object), size: size),
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
    return ApPhoto(
      asset: image.asset,
      credit: image.credit,
      semanticLabel: 'Imagen de ${object.name}',
    );
  }
}
