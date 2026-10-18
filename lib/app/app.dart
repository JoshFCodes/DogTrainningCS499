import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/chat/data/gemini_chat_service.dart';
import '../core/firebase/app_check_setup.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/Welcome/welcome_screen.dart';

import 'package:firebase_core/firebase_core.dart';

import '../features/auth/presentation/auth_gate.dart';
import '../firebase_options.dart';
import '../features/home/presentation/home_screen.dart';

class LearningWithLenbo extends StatelessWidget {
  const LearningWithLenbo({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Learning with Lenny',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: WelcomeScreen(
      initialize: () async {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }

        await initializeAppCheck();
      },
      nextPageBuilder: (context) => AuthGate(
        signedInBuilder: (context) => HomeScreen(
          chatPageBuilder: (context) =>
              ChatScreen(service: GeminiChatService()),
        ),
      ),
    ),
  );
}
