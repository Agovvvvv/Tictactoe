import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/profile/account_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/friends/add_friend_screen.dart';
import 'providers/user_provider.dart';
import 'providers/hell_mode_provider.dart';
import 'providers/mission_provider.dart';
import 'services/user/presence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize presence service
  PresenceService().initialize();
  
  runApp(const VanishingTicTacToeApp());
}

class VanishingTicTacToeApp extends StatelessWidget {
  const VanishingTicTacToeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => HellModeProvider()),
        ChangeNotifierProvider(create: (_) => MissionProvider()),
      ],
      child: MaterialApp(
        title: 'Vanishing Tic Tac Toe',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
          ),
        ),
        home: const HomeScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/friends': (context) => const FriendsScreen(),
          '/add-friend': (context) => const AddFriendScreen(),
          '/register': (context) => const RegisterScreen(),
          '/account': (context) => const AccountScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
        },
      ),
    );
  }
}
