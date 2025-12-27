import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:runam/services/graphql_client.dart';
import 'controllers/auth_controller.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await GetStorage.init();
  await GraphQLClientInstance.init(); // For unauthenticated requests

  // Initialize AuthController as singleton
  Get.put(AuthController(), permanent: true);

  runApp(const RunAmApp());
}
