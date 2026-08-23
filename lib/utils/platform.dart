import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

double adaptiveTopBarHeight() => kToolbarHeight;

bool isAndroid() => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
