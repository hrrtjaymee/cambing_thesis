import 'package:flutter/material.dart';
import 'package:cambing_thesis/core/theme/text_styles.dart';
import 'package:cambing_thesis/data/trivia.dart';
import 'dart:math';
import 'dart:async';

class Loadingscreen extends StatefulWidget {
  const Loadingscreen({super.key});

  @override
  State<Loadingscreen> createState() {
    return _LoadingscreenState();
  }
}

class _LoadingscreenState extends State<Loadingscreen> {
  static final int totalLength = trivia.length;
  int triviaIndex = 0;
  late Timer _timer;


  Image logo =  Image.asset("assets/images/bullet-icon-light.png", width: 400);

  @override
  void initState() {
    super.initState();
    _setRandomTrivia();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _setRandomTrivia();
    });
    
  }

  void _setRandomTrivia() {
    setState(() {
      triviaIndex = Random().nextInt(totalLength);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 100,),
        logo,
        const Text("Did You Know?", style: AppTextStyles.trivia_heading, textAlign: TextAlign.center),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 5.0),
          child: Text(trivia[triviaIndex], style: AppTextStyles.body, textAlign: TextAlign.center),
        )
      ],
    );
  }
}