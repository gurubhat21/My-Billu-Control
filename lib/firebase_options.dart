import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-YWmr8E_D-s1khuNGzs9IXl4Ie6jey-c',
    appId: '1:348057118012:android:52e97e426d961418276a39',
    messagingSenderId: '348057118012',
    projectId: 'my-billu',
    storageBucket: 'my-billu.firebasestorage.app',
  );
}
