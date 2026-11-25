import 'package:get/get.dart';

class NavigationController extends GetxController {
  final RxInt index = 0.obs;

  void goTo(int value) => index.value = value;
}
