import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/network/dio_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Singleton Dio with Interceptors
  DioClient.init();

  runApp(
    const ProviderScope(
      child: SalesIncentiveApp(),
    ),
  );
}
