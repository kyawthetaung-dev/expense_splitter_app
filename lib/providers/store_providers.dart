import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/firebase_config.dart';
import '../data/store/firestore_invoice_store.dart';
import '../data/store/hive_invoice_store.dart';
import '../data/store/invoice_store.dart';
import '../models/auth_session.dart';
import '../models/participant.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// Whether groups and expenses live in Firestore. See
/// [FirebaseConfig.firestoreData].
final firestoreDataEnabledProvider = Provider<bool>(
  (ref) => FirebaseConfig.enabled && FirebaseConfig.firestoreData,
);

final invoiceStoreProvider = Provider<InvoiceStore>((ref) {
  if (!ref.watch(firestoreDataEnabledProvider)) {
    final store = HiveInvoiceStore(
      expenses: ref.watch(expenseRepositoryProvider),
      groups: ref.watch(groupRepositoryProvider),
      participants: ref.watch(participantRepositoryProvider),
    );
    ref.onDispose(store.dispose);
    return store;
  }

  // Only who is signed in matters here. Watching the whole session would
  // restart every listener on each hourly token refresh.
  final identity = ref.watch(
    authSessionProvider.select((session) {
      final value = session.valueOrNull;
      if (value == null) return null;
      return (uid: value.uid, isAdmin: value.role == AppRole.admin);
    }),
  );
  if (identity == null) {
    throw StateError('Firestore data needs a signed-in session.');
  }
  return FirestoreInvoiceStore(uid: identity.uid, isAdmin: identity.isAdmin);
});

// The streams screens wait on before reading anything; see `gateOn`. They
// stop listening once no screen needs them.

final groupListProvider = StreamProvider.autoDispose<List<GroupListItem>>(
  (ref) => ref.watch(invoiceStoreProvider).watchGroups(),
);

final invoiceProvider = StreamProvider.autoDispose
    .family<InvoiceSnapshot?, String>(
      (ref, groupId) => ref.watch(invoiceStoreProvider).watchInvoice(groupId),
    );

final contactsProvider = StreamProvider.autoDispose<List<Participant>>(
  (ref) => ref.watch(invoiceStoreProvider).watchContacts(),
);

final overallProvider = StreamProvider.autoDispose<OverallSnapshot>(
  (ref) => ref.watch(invoiceStoreProvider).watchOverall(),
);
