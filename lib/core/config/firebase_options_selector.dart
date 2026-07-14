import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options_production.dart' as production_options;
import '../../firebase_options_sit.dart' as sit_options;
import '../../firebase_options_uat.dart' as uat_options;
import 'environment.dart';

FirebaseOptions firebaseOptionsFor(Environment environment) =>
    switch (environment) {
      Environment.sit => sit_options.DefaultFirebaseOptions.currentPlatform,
      Environment.uat => uat_options.DefaultFirebaseOptions.currentPlatform,
      Environment.production =>
        production_options.DefaultFirebaseOptions.currentPlatform,
    };
