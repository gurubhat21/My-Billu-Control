import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyApUwLMqrRzltnYFcVInJjr2Jeyws0ZOKo',
    appId: '1:348057118012:web:cac50e0ab8dd30c6276a39',
    messagingSenderId: '348057118012',
    projectId: 'my-billu',
    storageBucket: 'my-billu.firebasestorage.app',
  );
}
