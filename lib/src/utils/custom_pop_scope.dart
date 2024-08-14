import 'package:flutter/material.dart';

typedef CanGoBackCallback = Future<bool> Function();

class CustomPopScope extends StatelessWidget {
  CustomPopScope({
    required this.child,
    this.onPopInvoked,
    this.canGoBack,
    super.key,
  }) : assert(onPopInvoked != null || canGoBack != null);

  final Widget child;
  final PopInvokedCallback? onPopInvoked;
  final CanGoBackCallback? canGoBack;
  static bool popped = false;

  @override
  Widget build(BuildContext context) {
    popped = false;
    return PopScope(
      canPop: false,
      onPopInvoked: onPopInvoked ??
          (didPop) {
            if (didPop) return;
            canGoBack?.call().then((canPop) {
              if (canPop && !popped) {
                popped = true;
                Navigator.of(context).pop();
              }
            });
          },
      child: child,
    );
  }
}
