import 'package:flutter/material.dart';
import 'package:cambing_thesis/core/theme/colors.dart';
import 'package:cambing_thesis/core/theme/text_styles.dart'; 

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() {
    return _HistoryScreenState();
  }
}

class _HistoryScreenState extends State<HistoryScreen> {
  void onPressed() {

  }

  void backOnPressed(BuildContext context) {
    Navigator.pop(context);
  }

    @override 
    Widget build(BuildContext context) {
      final screenHeight = MediaQuery.of(context).size.height;
      final screenWidth = MediaQuery.of(context).size.width;

      
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.background
        ),
        child: SafeArea(
          minimum: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () => backOnPressed(context),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Icon(
                            Icons.arrow_back,
                            size: 28.0,
                          ),
                          Text('BACK'),
                        ]
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      padding: EdgeInsets.all(screenWidth * 0.05),
                      textStyle: AppTextStyles.body,
                    )
                    ),
                ],
              ),
              SizedBox(height: screenHeight * .01,),
          ],
          ),
        )
    )
    );
  }
}