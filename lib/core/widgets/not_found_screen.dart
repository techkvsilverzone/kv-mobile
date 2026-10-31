import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/kv_ui.dart';

/// kv-ui pages/NotFound.tsx — the router's error page.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          child: EmptyState(
            icon: Icons.explore_off_outlined,
            title: 'Page not found',
            message: "This page doesn't exist or may have moved.",
            actionLabel: 'Go to Home',
            onAction: () => context.go('/home'),
          ),
        ),
      ),
    );
  }
}
