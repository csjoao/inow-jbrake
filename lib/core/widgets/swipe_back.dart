import 'dart:math';

import 'package:flutter/material.dart';

/// Deslizar da esquerda para a direita em qualquer ponto da tela para voltar
/// (o gesto padrão do iOS só funciona a partir da borda).
///
/// Controles horizontais dentro da tela (ex.: Slider) continuam tendo
/// prioridade, porque ganham a disputa do gesto por estarem mais "dentro".
class SwipeBack extends StatefulWidget {
  const SwipeBack({super.key, required this.child});

  final Widget child;

  @override
  State<SwipeBack> createState() => _SwipeBackState();
}

class _SwipeBackState extends State<SwipeBack>
    with SingleTickerProviderStateMixin {
  /// Fração da largura arrastada (0 a 1).
  late final _drag = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  double get _width => max(MediaQuery.sizeOf(context).width, 1);

  void _onUpdate(DragUpdateDetails d) {
    _drag.value = (_drag.value + d.primaryDelta! / _width).clamp(0.0, 1.0);
  }

  Future<void> _onEnd(DragEndDetails d) async {
    final velocity = d.primaryVelocity ?? 0;
    if (_drag.value > 0.35 || velocity > 700) {
      await _drag.animateTo(1, curve: Curves.easeOut);
      if (!mounted) return;
      final popped = await Navigator.of(context).maybePop();
      if (!popped && mounted) _drag.value = 0;
    } else {
      await _drag.animateBack(0, curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!(ModalRoute.of(context)?.canPop ?? false)) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: () => _drag.animateBack(0),
      child: AnimatedBuilder(
        animation: _drag,
        builder: (_, child) => Transform.translate(
          offset: Offset(_drag.value * _width, 0),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
