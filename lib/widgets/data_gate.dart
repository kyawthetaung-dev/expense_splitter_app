import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store/invoice_store.dart';
import 'empty_state.dart';

/// Waits for a screen's data. Returns a placeholder screen while any of
/// [sources] is still loading or has failed, and null once all of them have a
/// value, after which the screen can read its data synchronously.
///
/// Call it first in `build`, before reading anything derived from [sources]:
///
/// ```dart
/// final gate = gateOn(ref, [invoiceProvider(groupId)], title: 'History');
/// if (gate != null) return gate;
/// ```
///
/// Once loaded, a later failure keeps showing the last good data.
Widget? gateOn(
  WidgetRef ref,
  List<ProviderBase<AsyncValue<Object?>>> sources, {
  String title = '',
}) {
  Object? error;
  var loading = false;
  for (final source in sources) {
    final value = ref.watch(source);
    if (value.hasValue) continue;
    // A retry keeps the old error while it reloads, so check loading first.
    if (value.isLoading) {
      loading = true;
    } else {
      error ??= value.error;
    }
  }
  if (error == null && !loading) return null;

  if (error != null) debugPrint('Loading failed: $error');
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: error == null
        ? const Center(child: CircularProgressIndicator())
        : LoadFailed(
            error: error,
            onRetry: () {
              for (final source in sources) {
                ref.invalidate(source);
              }
            },
          ),
  );
}

/// Shown in place of data that couldn't be loaded.
class LoadFailed extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const LoadFailed({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: "Couldn't load this",
            subtitle: error is StoreException
                ? error.message
                : 'Check your connection and try again.',
          ),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
