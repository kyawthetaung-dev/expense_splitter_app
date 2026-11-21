import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Build-time Firebase switches, set with `--dart-define`.
class FirebaseConfig {
  /// Off until a Firebase project is configured; the app then runs as before,
  /// on local storage with no sign-in.
  static const enabled = bool.fromEnvironment('FIREBASE_ENABLED');

  /// Keeps groups and expenses in Firestore instead of on the device. Needs
  /// [enabled]. Off until the cutover that imports existing local data.
  static const firestoreData = bool.fromEnvironment('USE_FIRESTORE_DATA');

  /// Points the app at local emulators and needs no `google-services.json`.
  static const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

  /// 10.0.2.2 is how an Android emulator reaches the machine running it.
  static const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );

  /// The web OAuth client id, for Google Sign-In to request an ID token with.
  /// Optional on Android, where it's read from `google-services.json`.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static Future<void> initialize() async {
    if (!enabled) return;

    if (!useEmulators) {
      await Firebase.initializeApp();
      return;
    }
    // Not real credentials: the Android SDK only checks these look right, and
    // the emulators ignore them.
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaDemoKeyForEmulatorsOnlyNotReal00000',
        appId: '1:1:android:0000000000000000',
        messagingSenderId: '1',
        projectId: 'demo-expense-splitter',
      ),
    );
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
  }
}
