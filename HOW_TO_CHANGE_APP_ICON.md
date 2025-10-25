# How to Change Your App Icon

## 🎯 Quick Method (Using flutter_launcher_icons)

I've already set up the configuration in `pubspec.yaml`. Just follow these steps:

### Step 1: Prepare Your Icon Image

You need a **square PNG image** (preferably 1024x1024 pixels) for your app icon.

**Requirements:**
- Format: PNG with transparency
- Size: 1024x1024 pixels (recommended)
- Minimum: 512x512 pixels
- Content: Should look good when scaled down to small sizes (48x48)

**Your options:**
1. Use your existing `logo-name.png` (check if it's square first)
2. Create a new icon image
3. Use your `bullet-icon-light.png` 

### Step 2: Add Your Icon to the Project

1. Save your icon image as: `assets/images/app_icon.png`
2. Make sure it's added to your `assets/images/` folder

**OR** if you want to use an existing image:
- Update the `image_path` in `pubspec.yaml` to point to your image
- Example: `image_path: "assets/images/logo-name.png"`

### Step 3: Install the Package

Open PowerShell and run:
```powershell
cd C:\Users\user\Documents\coding\cambing_thesis
flutter pub get
```

### Step 4: Generate the Icons

Run this command to automatically generate all icon sizes:
```powershell
flutter pub run flutter_launcher_icons
```

This will:
- Generate icons for all Android densities (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
- Generate iOS icons
- Update AndroidManifest.xml and iOS config automatically

### Step 5: Rebuild Your App

```powershell
flutter clean
flutter build apk --release
```

### Step 6: Install and Test

Install the new APK on your device and check the app icon in your launcher!

---

## 🎨 Creating a Good App Icon

### Design Tips:
1. **Simple is better** - Icons are displayed at small sizes (48x48 to 192x192)
2. **Avoid text** - Text becomes unreadable at small sizes
3. **Use bold shapes** - Thin lines don't work well
4. **Test different sizes** - View at 48x48, 72x72, 96x96, etc.
5. **Consider rounded corners** - Android automatically rounds icons

### Recommended Tools:
- **Figma** (free, web-based)
- **Canva** (easy to use)
- **GIMP** (free, desktop)
- **Photoshop** (professional)

### Using Your Bullet Icon:
Your `bullet-icon-light.png` might work great! Just:
1. Copy it to `assets/images/app_icon.png`
2. Or update pubspec.yaml: `image_path: "assets/images/bullet-icon-light.png"`

---

## 🤖 Adaptive Icons (Recommended for Modern Android)

For better Android 8+ support, you can use adaptive icons:

### Update pubspec.yaml:
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/app_icon.png"
  adaptive_icon_foreground: "assets/images/icon_foreground.png"
  adaptive_icon_background: "#5E9F6A"  # Your green color
```

**Adaptive icons consist of:**
- **Foreground**: Your logo/symbol (centered, transparent background)
- **Background**: Solid color or image

**Benefits:**
- Works with different launcher shapes (circle, square, rounded square, etc.)
- Supports animations and visual effects
- Modern Android look and feel

---

## 📱 Manual Method (Alternative)

If you prefer manual control:

### For Android:

1. Create these icon sizes:
   - `mipmap-mdpi/ic_launcher.png` - 48x48
   - `mipmap-hdpi/ic_launcher.png` - 72x72
   - `mipmap-xhdpi/ic_launcher.png` - 96x96
   - `mipmap-xxhdpi/ic_launcher.png` - 144x144
   - `mipmap-xxxhdpi/ic_launcher.png` - 192x192

2. Replace files in: `android/app/src/main/res/`

3. Keep the name: `ic_launcher.png`

### For iOS:

1. Replace icon in: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
2. You need multiple sizes (20x20 to 1024x1024)
3. Update `Contents.json` file

---

## ⚙️ Current Configuration

I've already configured `pubspec.yaml` with:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/app_icon.png"
```

**Next steps:**
1. Add your icon as `assets/images/app_icon.png`
2. Run `flutter pub get`
3. Run `flutter pub run flutter_launcher_icons`
4. Build and test!

---

## 🔧 Troubleshooting

### Icon doesn't update after installing APK:
- Completely uninstall the old app first
- Clear launcher cache (restart device)
- Try `flutter clean` before building

### Icon looks pixelated:
- Use a higher resolution source image (1024x1024)
- Make sure source image is PNG, not JPG

### Icon has white background:
- Make sure your PNG has transparency
- Use adaptive icons with a colored background

### Command not found:
- Make sure you ran `flutter pub get` first
- Check that flutter_launcher_icons is in dev_dependencies

---

## 📝 Quick Command Reference

```powershell
# Navigate to project
cd C:\Users\user\Documents\coding\cambing_thesis

# Install dependencies
flutter pub get

# Generate icons
flutter pub run flutter_launcher_icons

# Clean and build
flutter clean
flutter build apk --release

# Or build debug version
flutter build apk --debug
```

---

## ✅ Verification

After installation, your new icon should appear:
1. In the app drawer
2. On the home screen
3. In recent apps view
4. In app settings

**Current icon location:**
`android/app/src/main/res/mipmap-*/ic_launcher.png`
