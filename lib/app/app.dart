import 'package:flutter/material.dart';
import 'theme.dart';

class StudentAssistApp extends StatelessWidget {
  const StudentAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Student Assist',
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: Center(
          child: Text('Student Assist'),
        ),
      ),
    );
  }
}