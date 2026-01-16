import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:runam/features/errand/controllers/errand_controllers.dart';
import 'package:runam/services/graphql_client.dart';
import 'controllers/auth_controller.dart';
import 'controllers/location_controller.dart';
import 'app/app.dart';
import 'features/errand/controllers/errand_draft_controller.dart';
import 'features/errand/services/errand_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await GetStorage.init();
  await GraphQLClientInstance.init(); // For unauthenticated requests


  // Initialize controllers as singletons
  Get.put(AuthController(), permanent: true);
  Get.put(LocationController(), permanent: true);
  Get.put(ErrandService(), permanent: true);
  Get.put(ErrandDraftController(), permanent: true);
  Get.put(ErrandController());

  runApp(const RunAmApp());
}
