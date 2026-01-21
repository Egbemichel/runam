import 'package:get/get.dart';

enum UserRole { BUYER, RUNNER }

class RoleController extends GetxController {
  // The user's current active role
  final Rx<UserRole> activeRole = UserRole.BUYER.obs;

  // The user can have both roles, but only one active at a time
  final RxList<UserRole> userRoles = <UserRole>[UserRole.BUYER].obs;

  void switchRole(UserRole role) {
    if (userRoles.contains(role)) {
      activeRole.value = role;
    }
  }

  void addRole(UserRole role) {
    if (!userRoles.contains(role)) {
      userRoles.add(role);
    }
  }

  bool get isRunnerActive => activeRole.value == UserRole.RUNNER;
  bool get isBuyerActive => activeRole.value == UserRole.BUYER;
}

