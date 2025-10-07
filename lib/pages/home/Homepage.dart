import 'package:cambing_thesis/core/theme/colors.dart';
import 'package:cambing_thesis/core/theme/text_styles.dart';
import 'package:cambing_thesis/pages/camera/cameraScreen.dart';
import 'package:cambing_thesis/pages/history/historyScreen.dart';
import 'package:cambing_thesis/pages/weight/weightScreen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

class Home extends StatelessWidget {
  const Home({super.key, required this.camera});
  
  final CameraDescription camera;

  void onPressed() {

  }

  Future<void> weightOnPressed(BuildContext context) async {
    // Open gallery to pick an image
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      // Navigate to weight screen with the selected image
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Weightscreen(
              camera: camera,
              imagePath: image.path,
            ),
          ),
        );
      }
    }
  }

  void cameraOnPressed(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TakePictureScreen(camera: camera))
    );
  }

  void historyOnPressed(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen())
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: screenHeight * 0.15),
            Image.asset("assets/images/logo-name.png", width: screenWidth * 0.85,),
            const Text(
              "Know your goat's mass in a snap.",
              style: AppTextStyles.subheading),
            SizedBox(height: screenHeight * 0.3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.all(screenWidth * 0.05),
                  ),
                  onPressed: () => cameraOnPressed(context), 
                  child: Image.asset("assets/images/camera-icon.png", width: screenWidth * .08,)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary, width: screenWidth * .015),
                    shape: const CircleBorder(),
                    padding: EdgeInsets.all(screenWidth * 0.05),
                  ),
                  onPressed: () => weightOnPressed(context), 
                  child: Image.asset("assets/images/image-icon.png", width: screenWidth * .08,))
              ],),
              TextButton(
                onPressed: () => historyOnPressed(context),
                child: const Text('SEE HISTORY'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  padding: const EdgeInsets.all(5.0),
                  textStyle: AppTextStyles.subheading
                )
              )
          ],
        )
      )
    );
  }
}