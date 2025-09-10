import 'package:flutter/material.dart';

class TabNavigationService {
  static final TabNavigationService _instance = TabNavigationService._internal();
  factory TabNavigationService() => _instance;
  TabNavigationService._internal();

  static TabNavigationService get instance => _instance;

  GlobalKey<NavigatorState>? _mainNavigatorKey;
  ValueNotifier<int>? _currentTabNotifier;
  
  void initialize(GlobalKey<NavigatorState> navigatorKey, ValueNotifier<int> tabNotifier) {
    _mainNavigatorKey = navigatorKey;
    _currentTabNotifier = tabNotifier;
  }

  void switchToTab(int tabIndex) {
    if (_currentTabNotifier != null) {
      _currentTabNotifier!.value = tabIndex;
    }
  }

  void switchToHome() => switchToTab(0);
  void switchToSearch() => switchToTab(1);
  void switchToCart() => switchToTab(2);
  void switchToProfile() => switchToTab(3);

  int get currentTab => _currentTabNotifier?.value ?? 0;

  bool get isInitialized => _mainNavigatorKey != null && _currentTabNotifier != null;
}