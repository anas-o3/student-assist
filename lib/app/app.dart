import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme.dart';

class StudentAssistApp extends StatelessWidget {
  const StudentAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مساعد الطالب',
      theme: AppTheme.lightTheme,

      locale: const Locale('ar'),

      supportedLocales: const [
        Locale('ar'),
      ],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const Scaffold(
        body: Center(
          child: Text('مساعد الطالب'),
        ),
      ),
    );
  }
}