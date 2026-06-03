import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../ble_connection/data/models/ble_device_state.dart';
import '../../../ble_connection/presentation/controllers/ble_connection_controller.dart';
import '../../../calibration/data/calibration_repository.dart';
import '../../../calibration/data/calibration_storage.dart';
import '../../../calibration/domain/models/calibration_result.dart';
import '../../../calibration/domain/services/astronomy_position_service.dart';
import '../../../calibration/domain/services/pointing_correction_service.dart';
import '../../../oe4_control/presentation/controllers/oe4_control_controller.dart';
import '../../../observation/application/ephemeris_service.dart';
import '../../../observation/domain/models/alt_az_result.dart';
import '../../../settings/application/settings_service.dart';
import '../../application/astronomical_goto_service.dart';
import '../../domain/models/celestial_object.dart';
import '../utils/coordinate_formatters.dart';

class CelestialDetailScreen extends StatefulWidget {
  final CelestialObject object;

  const CelestialDetailScreen({super.key, required this.object});

  @override
  State<CelestialDetailScreen> createState() => _CelestialDetailScreenState();
}

class _CelestialDetailScreenState extends State<CelestialDetailScreen> {
  late final EphemerisService _ephemerisService;
  late final AstronomicalGotoService _gotoService;

  CalibrationResult? _savedCalibration;
  AstronomicalGotoCommand? _lastGotoCommand;
  bool _loadingCalibration = true;
  bool _sendingGoto = false;
  String? _gotoError;

  bool get _isSun =>
      widget.object is SolarSystemBody &&
      (widget.object as SolarSystemBody).isSun;

  @override
  void initState() {
    super.initState();
    _ephemerisService = EphemerisService(
      observerDataProvider: context.read<SettingsService>(),
    );
    _gotoService = AstronomicalGotoService(
      observerDataProvider: context.read<SettingsService>(),
      calibrationRepository: CalibrationRepository(
        storage: CalibrationStorage(),
      ),
      astronomyPositionService: const AstronomyPositionService(),
      correctionService: const PointingCorrectionService(),
    );
    if (!_isSun) {
      _ephemerisService.startTracking(widget.object);
    }
    _loadSavedCalibration();
  }

  @override
  void dispose() {
    _ephemerisService.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCalibration() async {
    if (mounted && !_loadingCalibration) {
      setState(() {
        _loadingCalibration = true;
        _gotoError = null;
      });
    }

    try {
      final calibration = await _gotoService.loadSavedCalibration();
      if (!mounted) return;
      setState(() {
        _savedCalibration = calibration;
        _loadingCalibration = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _gotoError = 'No se pudo cargar correccion estimada: $error';
        _loadingCalibration = false;
      });
    }
  }

  Future<void> _sendAstronomicalGoto() async {
    if (_sendingGoto) return;

    final bleState = context.read<BleConnectionController>().state;
    final deviceId = bleState.connectedDevice?.id;
    final isConnected =
        bleState.connectionStatus == BleConnectionStatus.connected &&
        deviceId != null;

    if (!isConnected) {
      _showSnackBar('Conecta el ESP32 por BLE primero.');
      return;
    }

    setState(() {
      _sendingGoto = true;
      _gotoError = null;
    });

    try {
      final oe4Controller = context.read<Oe4ControlController>();
      final command = await _gotoService.sendGoto(
        object: widget.object,
        send: (altitude, azimuth) =>
            oe4Controller.sendGoto(deviceId, alt: altitude, az: azimuth),
      );
      if (!mounted) return;
      setState(() {
        _savedCalibration = command.calibration;
        _lastGotoCommand = command;
      });
      _showSnackBar(_sentMessage(command));
    } catch (error) {
      if (!mounted) return;
      final message = _errorText(error);
      setState(() {
        _gotoError = message;
      });
      _showSnackBar(message);
    } finally {
      if (mounted) {
        setState(() {
          _sendingGoto = false;
        });
      }
    }
  }

  String _sentMessage(AstronomicalGotoCommand command) {
    final rawAlt = _formatSigned(command.rawPosition.altitudeDeg);
    final rawAz = _formatUnsigned(command.rawPosition.azimuthDeg);
    if (!command.usedCorrection) {
      return 'GOTO enviado sin correccion estimada: Alt/Az $rawAlt / $rawAz';
    }

    final finalAlt = _formatSigned(command.finalAltitude);
    final finalAz = _formatUnsigned(command.finalAzimuth);
    return 'GOTO enviado con correccion estimada: Alt/Az original '
        '$rawAlt / $rawAz -> Alt/Az corregido $finalAlt / $finalAz';
  }

  String _errorText(Object error) {
    return error is StateError ? error.message : error.toString();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatSigned(double degrees) {
    return CoordinateFormatters.formatSignedDegrees(degrees);
  }

  String _formatUnsigned(double degrees) {
    return CoordinateFormatters.formatUnsignedDegrees(degrees);
  }

  @override
  Widget build(BuildContext context) {
    final object = widget.object;
    final solarMagnitude = object is SolarSystemBody
        ? object.getDynamicMagnitude(DateTime.now().toUtc())
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(object.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isSun) const _SolarSafetyCard(),
          _DataCard(
            title: 'Objeto',
            icon: Icons.auto_awesome_rounded,
            children: [
              _InfoRow(label: 'Nombre', value: object.name),
              _InfoRow(label: 'Tipo', value: _objectTypeLabel(object)),
              _InfoRow(
                label: 'Magnitud',
                value: solarMagnitude ?? object.magnitude ?? 'N/A',
              ),
              ..._buildObjectRows(object),
            ],
          ),
          const SizedBox(height: 14),
          _DataCard(
            title: 'Coordenadas J2000',
            icon: Icons.public_rounded,
            children: _buildJ2000Rows(object),
          ),
          const SizedBox(height: 14),
          _DataCard(
            title: 'Coordenadas Horizontales',
            icon: Icons.explore_rounded,
            accent: Theme.of(context).colorScheme.secondary,
            children: [
              if (_isSun)
                const _BlockedCoordinatesMessage()
              else
                StreamBuilder<AltAzResult>(
                  stream: _ephemerisService.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _StatusMessage(
                        icon: Icons.error_outline_rounded,
                        message:
                            'No se pudo calcular Alt/Az: ${snapshot.error}',
                      );
                    }
                    final result = snapshot.data;
                    if (result == null) {
                      return const _StatusMessage(
                        icon: Icons.sync_rounded,
                        message: 'Calculando efemerides...',
                      );
                    }
                    return _HorizontalCoordinatesPanel(result: result);
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          _buildAstronomicalGotoCard(),
        ],
      ),
    );
  }

  Widget _buildAstronomicalGotoCard() {
    if (_isSun) {
      return _AstronomicalGotoCard(
        isSun: true,
        currentPosition: null,
        previewCommand: null,
        savedCalibration: _savedCalibration,
        loadingCalibration: _loadingCalibration,
        sendingGoto: _sendingGoto,
        lastCommand: _lastGotoCommand,
        errorMessage:
            _gotoError ?? 'GoTo solar bloqueado por seguridad ocular.',
        onSend: _sendAstronomicalGoto,
        onRefreshCalibration: _loadSavedCalibration,
      );
    }

    return StreamBuilder<AltAzResult>(
      stream: _ephemerisService.stream,
      builder: (context, snapshot) {
        AstronomicalGotoCommand? preview;
        String? previewError = _gotoError;
        final result = snapshot.data;

        if (snapshot.hasError) {
          previewError = 'No se pudo calcular Alt/Az: ${snapshot.error}';
        } else if (result != null && !_loadingCalibration) {
          try {
            preview = _gotoService.buildCommand(
              object: widget.object,
              rawPosition: result,
              calibration: _savedCalibration,
            );
          } catch (error) {
            previewError = _errorText(error);
          }
        }

        return _AstronomicalGotoCard(
          isSun: false,
          currentPosition: result,
          previewCommand: preview,
          savedCalibration: _savedCalibration,
          loadingCalibration: _loadingCalibration,
          sendingGoto: _sendingGoto,
          lastCommand: _lastGotoCommand,
          errorMessage: previewError,
          onSend: _sendAstronomicalGoto,
          onRefreshCalibration: _loadSavedCalibration,
        );
      },
    );
  }

  List<Widget> _buildObjectRows(CelestialObject object) {
    if (object is DeepSkyObject) {
      return [
        _InfoRow(
          label: 'Constelacion',
          value: object.constellations.join(', '),
        ),
        _InfoRow(label: 'Catalogos', value: object.catalogs.join(', ')),
      ];
    }
    if (object is CalibrationStar) {
      return [
        _InfoRow(label: 'Constelacion', value: object.constellation),
        _InfoRow(label: 'Tipo espectral', value: object.spectralType),
        _InfoRow(label: 'Catalogos', value: object.catalogs.join(', ')),
      ];
    }
    return const [];
  }

  List<Widget> _buildJ2000Rows(CelestialObject object) {
    if (object is DeepSkyObject) {
      return [
        _CoordinateRow(
          label: 'RA',
          value: CoordinateFormatters.formatRightAscension(object.raJ2000Hours),
        ),
        _CoordinateRow(
          label: 'Dec',
          value: CoordinateFormatters.formatDeclination(object.decJ2000Degrees),
        ),
      ];
    }
    if (object is CalibrationStar) {
      return [
        _CoordinateRow(
          label: 'RA',
          value: CoordinateFormatters.formatRightAscension(object.raJ2000Hours),
        ),
        _CoordinateRow(
          label: 'Dec',
          value: CoordinateFormatters.formatDeclination(object.decJ2000Degrees),
        ),
      ];
    }
    return const [
      _StatusMessage(
        icon: Icons.info_outline_rounded,
        message: 'Los cuerpos del sistema solar se calculan dinamicamente.',
      ),
    ];
  }

  String _objectTypeLabel(CelestialObject object) {
    if (object is SolarSystemBody) return 'Sistema Solar';
    if (object is DeepSkyObject) return object.objectType;
    return 'Estrella de Calibracion';
  }
}

class _DataCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? accent;

  const _DataCard({
    required this.title,
    required this.icon,
    required this.children,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = accent ?? colorScheme.primary;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withValues(alpha: 0.10),
              colorScheme.surface.withValues(alpha: 0.02),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _HorizontalCoordinatesPanel extends StatelessWidget {
  final AltAzResult result;

  const _HorizontalCoordinatesPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final visible = result.altitudeDeg >= 0;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Altitud',
                value: CoordinateFormatters.formatSignedArc(result.altitudeDeg),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Azimut',
                value: CoordinateFormatters.formatUnsignedArc(
                  result.azimuthDeg,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: (visible ? colorScheme.secondary : colorScheme.error)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (visible ? colorScheme.secondary : colorScheme.error)
                  .withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Icon(
                visible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: visible ? colorScheme.secondary : colorScheme.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  visible
                      ? 'Objeto sobre el horizonte'
                      : 'Objeto bajo el horizonte',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'UTC ${result.computedAt.toIso8601String()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Raw: Alt ${CoordinateFormatters.formatSignedArc(result.altitudeRawDeg)} / Az ${CoordinateFormatters.formatUnsignedArc(result.azimuthRawDeg)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _CoordinateRow extends StatelessWidget {
  final String label;
  final String value;

  const _CoordinateRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _StatusMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _BlockedCoordinatesMessage extends StatelessWidget {
  const _BlockedCoordinatesMessage();

  @override
  Widget build(BuildContext context) {
    return _StatusMessage(
      icon: Icons.block_rounded,
      message:
          'Coordenadas solares bloqueadas por seguridad ocular. No se calcula ni se muestra Alt/Az del Sol.',
    );
  }
}

class _SolarSafetyCard extends StatelessWidget {
  const _SolarSafetyCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ADVERTENCIA DE SEGURIDAD: nunca apuntes el telescopio al Sol sin filtros certificados.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _AstronomicalGotoCard extends StatelessWidget {
  final bool isSun;
  final AltAzResult? currentPosition;
  final AstronomicalGotoCommand? previewCommand;
  final CalibrationResult? savedCalibration;
  final bool loadingCalibration;
  final bool sendingGoto;
  final AstronomicalGotoCommand? lastCommand;
  final String? errorMessage;
  final VoidCallback onSend;
  final VoidCallback onRefreshCalibration;

  const _AstronomicalGotoCard({
    required this.isSun,
    required this.currentPosition,
    required this.previewCommand,
    required this.savedCalibration,
    required this.loadingCalibration,
    required this.sendingGoto,
    required this.lastCommand,
    required this.errorMessage,
    required this.onSend,
    required this.onRefreshCalibration,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _DataCard(
      title: 'GoTo astronomico',
      icon: Icons.gps_fixed_rounded,
      accent: colorScheme.primary,
      children: [
        if (currentPosition == null)
          _StatusMessage(
            icon: isSun ? Icons.block_rounded : Icons.sync_rounded,
            message: isSun
                ? 'GoTo solar bloqueado por seguridad ocular.'
                : 'Calculando Alt/Az actual...',
          )
        else
          _GotoCoordinates(position: currentPosition!),
        const SizedBox(height: 12),
        _CalibrationPreview(
          calibration: savedCalibration,
          loading: loadingCalibration,
          onRefresh: onRefreshCalibration,
        ),
        const SizedBox(height: 12),
        if (previewCommand != null)
          _CommandPreview(command: previewCommand!)
        else if (errorMessage != null)
          _InlineGotoMessage(
            icon: Icons.block_rounded,
            message: errorMessage!,
            isError: true,
          )
        else
          const _InlineGotoMessage(
            icon: Icons.info_outline_rounded,
            message:
                'El comando final aparecera cuando existan coordenadas actuales.',
          ),
        if (currentPosition != null &&
            currentPosition!.altitudeDeg >= 0 &&
            currentPosition!.altitudeDeg < 5) ...[
          const SizedBox(height: 10),
          const _InlineGotoMessage(
            icon: Icons.warning_amber_rounded,
            message: 'Objeto visible, pero muy cerca del horizonte (0° a 5°).',
          ),
        ],
        if (lastCommand != null) ...[
          const SizedBox(height: 12),
          _LastGotoSummary(command: lastCommand!),
        ],
        const SizedBox(height: 14),
        Consumer2<BleConnectionController, Oe4ControlController>(
          builder: (context, bleController, oe4Controller, _) {
            final bleState = bleController.state;
            final connected =
                bleState.connectionStatus == BleConnectionStatus.connected &&
                bleState.connectedDevice != null;
            final canSend =
                !isSun &&
                previewCommand != null &&
                connected &&
                !sendingGoto &&
                !oe4Controller.isSending;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InlineGotoMessage(
                  icon: connected
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_disabled_rounded,
                  message: connected
                      ? 'ESP32 conectado. Se enviara GOTO astronomico.'
                      : 'ESP32 desconectado. Conecta BLE para enviar GOTO.',
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: canSend ? onSend : null,
                  icon: sendingGoto || oe4Controller.isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(isSun ? Icons.block : Icons.gps_fixed),
                  label: Text(isSun ? 'Apuntar (Bloqueado)' : 'Apuntar'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GotoCoordinates extends StatelessWidget {
  final AltAzResult position;

  const _GotoCoordinates({required this.position});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Alt/Az actual:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Altitud',
                value: CoordinateFormatters.formatSignedDegrees(
                  position.altitudeDeg,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Azimut',
                value: CoordinateFormatters.formatUnsignedDegrees(
                  position.azimuthDeg,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Recalculado para envio al presionar Apuntar.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CalibrationPreview extends StatelessWidget {
  final CalibrationResult? calibration;
  final bool loading;
  final VoidCallback onRefresh;

  const _CalibrationPreview({
    required this.calibration,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final saved = calibration;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Correccion estimada:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Actualizar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (loading)
          const _InlineGotoMessage(
            icon: Icons.sync_rounded,
            message: 'Cargando correccion estimada...',
          )
        else if (saved == null)
          const _InlineGotoMessage(
            icon: Icons.info_outline_rounded,
            message: 'No disponible. El GOTO se enviara sin correccion.',
          )
        else ...[
          const _InlineGotoMessage(
            icon: Icons.check_circle_outline_rounded,
            message: 'Disponible. El GOTO astronomico aplicara offsets.',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Offset altitud',
                  value: CoordinateFormatters.formatSignedDegrees(
                    saved.altitudeOffset,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Offset azimut',
                  value: CoordinateFormatters.formatSignedDegrees(
                    saved.azimuthOffset,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CommandPreview extends StatelessWidget {
  final AstronomicalGotoCommand command;

  const _CommandPreview({required this.command});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comando final:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Altitud enviada',
                value: CoordinateFormatters.formatSignedDegrees(
                  command.finalAltitude,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Azimut enviado',
                value: CoordinateFormatters.formatUnsignedDegrees(
                  command.finalAzimuth,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _InlineGotoMessage(
          icon: command.usedCorrection
              ? Icons.tune_rounded
              : Icons.info_outline_rounded,
          message: command.usedCorrection
              ? 'Se enviara con correccion estimada.'
              : 'Se enviara sin correccion estimada.',
        ),
      ],
    );
  }
}

class _LastGotoSummary extends StatelessWidget {
  final AstronomicalGotoCommand command;

  const _LastGotoSummary({required this.command});

  @override
  Widget build(BuildContext context) {
    final raw =
        '${CoordinateFormatters.formatSignedDegrees(command.rawPosition.altitudeDeg)} / '
        '${CoordinateFormatters.formatUnsignedDegrees(command.rawPosition.azimuthDeg)}';
    final corrected =
        '${CoordinateFormatters.formatSignedDegrees(command.finalAltitude)} / '
        '${CoordinateFormatters.formatUnsignedDegrees(command.finalAzimuth)}';

    return _InlineGotoMessage(
      icon: Icons.send_rounded,
      message: command.usedCorrection
          ? 'GOTO enviado con correccion estimada: $raw -> $corrected'
          : 'GOTO enviado sin correccion estimada: $raw',
    );
  }
}

class _InlineGotoMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isError;

  const _InlineGotoMessage({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isError ? colorScheme.error : colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
