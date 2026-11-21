import 'package:flutter/material.dart';

import '../data/store/invoice_store.dart';

/// Tells the person a change didn't go through. Only a [StoreException]'s
/// message is written to be shown; anything else gets a generic one.
void showFailure(BuildContext context, Object error) {
  if (error is! StoreException) debugPrint('Change failed: $error');
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(
        error is StoreException
            ? error.message
            : "That didn't work. Please try again.",
      ),
    ),
  );
}
