import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class RivePlantController extends StatefulWidget {
  final double hydration;
  final int growthStage;
  final String riveAssetPath;

  const RivePlantController({
    super.key,
    required this.hydration,
    required this.growthStage,
    this.riveAssetPath = 'assets/rive/plant_system.riv',
  });

  @override
  State<RivePlantController> createState() => _RivePlantControllerState();
}

class _RivePlantControllerState extends State<RivePlantController> {
  late final FileLoader _fileLoader;
  RiveWidgetController? _riveController;

  @override
  void initState() {
    super.initState();
    _fileLoader = FileLoader.fromAsset(
      widget.riveAssetPath,
      riveFactory: Factory.flutter,
    );
  }

  // ignore: deprecated_member_use
  void _syncInputs() {
    final sm = _riveController?.stateMachine;
    if (sm == null) return;
    // ignore: deprecated_member_use
    sm.number('hydration')?.value = widget.hydration;
    // ignore: deprecated_member_use
    sm.number('growthStage')?.value = widget.growthStage.toDouble();
  }

  @override
  void didUpdateWidget(covariant RivePlantController oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hydration != widget.hydration ||
        oldWidget.growthStage != widget.growthStage) {
      _syncInputs();
    }
  }

  RiveWidgetController _buildController(File file) {
    final ctrl = RiveWidgetController(
      file,
      stateMachineSelector: const StateMachineNamed('PlantState'),
    );
    _riveController = ctrl;
    _syncInputs();
    return ctrl;
  }

  @override
  Widget build(BuildContext context) {
    return RiveWidgetBuilder(
      fileLoader: _fileLoader,
      controller: _buildController,
      builder: (context, state) {
        if (state is RiveLoaded) {
          return GestureDetector(
            onPanDown: (_) {
              // ignore: deprecated_member_use
              _riveController?.stateMachine.boolean('isTouching')?.value = true;
            },
            onPanEnd: (_) {
              // ignore: deprecated_member_use
              _riveController?.stateMachine.boolean('isTouching')?.value =
                  false;
            },
            onPanCancel: () {
              // ignore: deprecated_member_use
              _riveController?.stateMachine.boolean('isTouching')?.value =
                  false;
            },
            child: RiveWidget(
              controller: state.controller,
              fit: Fit.contain,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
