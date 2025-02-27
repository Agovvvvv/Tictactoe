import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBqAYPCRQ99N3L5Yri34Fz8_Bn5_fwTD4U',
    appId: '1:65264182696:web:3cd399d1bc5e3fb1a2a99d',
    messagingSenderId: '65264182696',
    projectId: 'vanishing-tic-tac-toe',
    authDomain: 'vanishing-tic-tac-toe.firebaseapp.com',
    storageBucket: 'vanishing-tic-tac-toe.firebasestorage.app',
    measurementId: 'G-B0JPM0ZQLE',
  );

  // Android configuration
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBqAYPCRQ99N3L5Yri34Fz8_Bn5_fwTD4U',
    appId: '1:65264182696:android:3cd399d1bc5e3fb1a2a99d',
    messagingSenderId: '65264182696',
    projectId: 'vanishing-tic-tac-toe',
    storageBucket: 'vanishing-tic-tac-toe.firebasestorage.app',
  );

  // iOS configuration
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBqAYPCRQ99N3L5Yri34Fz8_Bn5_fwTD4U',
    appId: '1:65264182696:ios:3cd399d1bc5e3fb1a2a99d',
    messagingSenderId: '65264182696',
    projectId: 'vanishing-tic-tac-toe',
    storageBucket: 'vanishing-tic-tac-toe.firebasestorage.app',
    iosClientId: '65264182696-ios-client-id.apps.googleusercontent.com',
    iosBundleId: 'com.example.tictactoe',
  );
}
