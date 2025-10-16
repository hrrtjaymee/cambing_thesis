import 'package:flutter/material.dart';
import 'colors.dart';

class AppTextStyles {
  static const subheading = TextStyle(
    fontFamily: 'League',
    fontSize: 20,
    fontWeight: FontWeight.normal,
    color: AppColors.foreground
  );

  static const trivia_heading = TextStyle(
    fontFamily: 'League Spartan',
    fontSize: 30,
    fontWeight: FontWeight.bold,
    color: AppColors.foreground
  );

  static const body = TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 22,
    fontWeight: FontWeight.normal,
    color: AppColors.foreground
  );

  static const appbar = TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.foreground
  );

  static const weight_heading = TextStyle(
    fontFamily: 'League Spartan',
    fontSize: 39,
    fontWeight: FontWeight.w900,
    color: AppColors.foreground
  );

  static const weight_value = TextStyle(
    fontFamily: 'League Spartan',
    fontSize: 100,
    fontWeight: FontWeight.w900,
    color: AppColors.primary,
    height: 0.8
  );
}