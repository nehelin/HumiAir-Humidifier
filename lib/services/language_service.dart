import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static final LanguageService instance = LanguageService._internal();
  LanguageService._internal();

  static const String _prefKey = 'selected_language';

  /// 'en' for English, 'bn' for Bengali. Defaults to English.
  final ValueNotifier<String> currentLanguage = ValueNotifier<String>('en');

  bool get isBengali => currentLanguage.value == 'bn';
  bool get isEnglish => currentLanguage.value == 'en';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && (saved == 'en' || saved == 'bn')) {
        currentLanguage.value = saved;
      }
    } catch (_) {}
  }

  Future<void> setLanguage(String lang) async {
    if (lang != 'en' && lang != 'bn') return;
    currentLanguage.value = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, lang);
    } catch (_) {}
  }

  Future<void> toggleLanguage() async {
    final next = isBengali ? 'en' : 'bn';
    await setLanguage(next);
  }
}

/// Centralized bilingual dictionary for HumiAir
class Tr {
  static bool get _isBn => LanguageService.instance.isBengali;

  // App & Common
  static String get appName => 'HumiAir';
  static String get smartHumidityControl =>
      _isBn ? 'স্মার্ট আর্দ্রতা নিয়ন্ত্রণ' : 'Smart Humidity Control';
  static String get cancel => _isBn ? 'বাতিল' : 'Cancel';
  static String get save => _isBn ? 'সেভ' : 'Save';
  static String get delete => _isBn ? 'মুছুন' : 'Delete';
  static String get remove => _isBn ? 'সরাও' : 'Remove';
  static String get ok => _isBn ? 'ঠিক আছে' : 'OK';
  static String get online => _isBn ? 'অনলাইন' : 'Online';
  static String get offline => _isBn ? 'অফলাইন' : 'Offline';
  static String get waiting => _isBn ? 'অপেক্ষা...' : 'Waiting...';
  static String get retry => _isBn ? 'পুনরায় চেষ্টা' : 'Retry';
  static String get success => _isBn ? 'সফল' : 'Success';
  static String get error => _isBn ? 'সমস্যা' : 'Error';
  static String get copied => _isBn ? 'কপি হয়েছে!' : 'Copied to clipboard!';

  // Home Screen
  static String get liveStatus => _isBn ? 'লাইভ স্ট্যাটাস' : 'Live Status';
  static String get humidity => _isBn ? 'আর্দ্রতা' : 'Humidity';
  static String get temperature => _isBn ? 'তাপমাত্রা' : 'Temperature';
  static String get mistOn => _isBn ? 'মিস্ট চালু (ON)' : 'Mist is ON';
  static String get mistOff => _isBn ? 'মিস্ট বন্ধ (OFF)' : 'Mist is OFF';
  static String get mistStatus => _isBn ? 'মিস্ট অবস্থা' : 'Mist Status';
  static String get waterTankLow =>
      _isBn ? 'পানি শেষ! রিফিল করুন' : 'Water tank low! Refill';
  static String get waterTankLowNotice => _isBn
      ? 'পানির ট্যাঙ্ক খালি! অনুগ্রহ করে পানি পূরণ করুন।'
      : 'Water tank is empty! Please refill.';
  static String get deviceOfflineNotice => _isBn
      ? 'ডিভাইসটি বর্তমানে বন্ধ বা অফলাইনে আছে'
      : 'Device is currently powered off or offline';
  static String get humidityThresholds =>
      _isBn ? 'আর্দ্রতা থ্রেশহোল্ড' : 'Humidity Thresholds';
  static String get thresholdRangeSubtitle =>
      _isBn ? 'মিস্ট কন্ট্রোলারের সীমা' : 'Mist controller target range';
  static String get lowerThreshold =>
      _isBn ? 'সর্বনিম্ন সীমা (Lower %)' : 'Lower Threshold (%)';
  static String get upperThreshold =>
      _isBn ? 'সর্বোচ্চ সীমা (Upper %)' : 'Upper Threshold (%)';
  static String get saveThresholds =>
      _isBn ? 'থ্রেশহোল্ড সেভ করুন' : 'Save Thresholds';
  static String get thresholdsSaved =>
      _isBn ? 'থ্রেশহোল্ড সফলভাবে সেভ হয়েছে!' : 'Thresholds saved successfully!';
  static String get invalidNumber =>
      _isBn ? 'সঠিক সংখ্যা প্রদান করুন।' : 'Please enter valid numbers.';
  static String get lowerMustBeLessThanUpper => _isBn
      ? 'Lower threshold অবশ্যই Upper threshold এর চেয়ে কম হতে হবে।'
      : 'Lower threshold must be less than Upper threshold.';
  static String get noDeviceTitle =>
      _isBn ? 'কোনো ডিভাইস নেই' : 'No Device Added';
  static String get noDeviceDesc => _isBn
      ? 'আপনার HumiAir ডিভাইস সংযুক্ত করুন এবং যেকোনো স্থান থেকে নিয়ন্ত্রণ করুন।'
      : 'Connect your HumiAir device to monitor and control it from anywhere.';
  static String get addDeviceBtn =>
      _isBn ? 'ডিভাইস যোগ করুন' : 'Add New Device';
  static String get waitingForDeviceData => _isBn
      ? 'ডিভাইস ডেটার জন্য অপেক্ষা করা হচ্ছে...'
      : 'Waiting for device data...';

  // Devices Screen
  static String get myDevices => _isBn ? 'আমার ডিভাইসসমূহ' : 'My Devices';
  static String get noDevicesYet =>
      _isBn ? 'এখনো কোনো ডিভাইস নেই' : 'No devices yet';
  static String get tapPlusToAdd => _isBn
      ? 'নিচের + বাটনে চাপ দিয়ে ডিভাইস যুক্ত করুন।'
      : 'Tap the + button below to add your first device.';
  static String get deleteDeviceTitle =>
      _isBn ? 'ডিভাইস সরাবেন?' : 'Delete Device?';
  static String deleteDeviceDesc(String name) => _isBn
      ? '"$name" আপনার তালিকা থেকে সরানো হবে।\n(ডিভাইসের ক্লাউড ডেটা সুরক্ষিত থাকবে)'
      : 'Remove "$name" from your device list?\n(Device history will remain intact)';
  static String get copyDeviceId =>
      _isBn ? 'ডিভাইস আইডি কপি করুন' : 'Copy Device ID';

  // Add Device Screen
  static String get addNewDevice =>
      _isBn ? 'নতুন ডিভাইস যুক্ত করুন' : 'Add New Device';
  static String get howToFindIdTitle =>
      _isBn ? 'ডিভাইস আইডি (ID) কীভাবে পাবেন?' : 'How to find your Device ID?';
  static String get step1 => _isBn
      ? 'ESP8266 ডিভাইসে পাওয়ার (Power) সংযোগ দিন।'
      : 'Power on your ESP8266 device.';
  static String get step2 => _isBn
      ? 'ফোনের Wi-Fi সেটিংসে গিয়ে "HumiAir-Setup" নেটওয়ার্কে কানেক্ট করুন।'
      : 'Go to phone Wi-Fi settings and connect to "HumiAir-Setup".';
  static String get step3 => _isBn
      ? 'ব্রাউজারে যান এবং 192.168.4.1 লিঙ্কে প্রবেশ করুন।'
      : 'Open your browser and navigate to 192.168.4.1';
  static String get step4 => _isBn
      ? 'সেটআপ পোর্টালে আপনার ইউনিক Device ID দেখতে পাবেন (উদাঃ humiair_a1b2c3d4e5f6)।'
      : 'The setup portal will display your unique Device ID (e.g. humiair_a1b2c3d4e5f6).';
  static String get step5 => _isBn
      ? 'আইডিটি কপি করে নিচের বক্সে পেস্ট করুন।'
      : 'Copy the ID and paste it into the field below.';
  static String get deviceIdHintNote => _isBn
      ? 'ডিভাইস আইডি হার্ডওয়্যার MAC অ্যাড্রেসের উপর ভিত্তি করে তৈরি, এটি কখনো পরিবর্তন হয় না।'
      : 'Device ID is permanent based on hardware MAC address and never changes.';
  static String get deviceDetails =>
      _isBn ? 'ডিভাইসের বিবরণ' : 'Device Details';
  static String get deviceIdLabel => _isBn ? 'ডিভাইস আইডি' : 'Device ID';
  static String get testConnection => _isBn ? 'যাচাই' : 'Test';
  static String get testing => _isBn ? 'পরীক্ষা...' : 'Testing...';
  static String get deviceFound => _isBn
      ? '✓ ডিভাইস সক্রিয় পাওয়া গেছে!'
      : '✓ Device is active and communicating!';
  static String get deviceNotFound => _isBn
      ? 'ডিভাইস এখনো ডেটা পাঠায়নি। পাওয়ার ও ওয়াইফাই যাচাই করুন।'
      : 'Device has not sent data yet. Check device power and Wi-Fi.';
  static String get deviceNameLabel =>
      _isBn ? 'ডিভাইসের নাম' : 'Device Name';
  static String get deviceNameHint =>
      _isBn ? 'যেমনঃ বেডরুম হিউমিডিফায়ার' : 'e.g. Bedroom Humidifier';
  static String get roomLabel =>
      _isBn ? 'রুম / অবস্থান (ঐচ্ছিক)' : 'Room / Location (Optional)';
  static String get roomHint =>
      _isBn ? 'যেমনঃ বেডরুম, ড্রয়িং রুম' : 'e.g. Bedroom, Living Room';
  static String get adding => _isBn ? 'যোগ হচ্ছে...' : 'Adding...';
  static String get enterNameAndIdPrompt => _isBn
      ? 'অনুগ্রহ করে ডিভাইসের নাম ও আইডি লিখুন।'
      : 'Please enter device name and device ID.';

  // Charts Screen
  static String get sensorHistory =>
      _isBn ? 'সেন্সর হিস্টোরি' : 'Sensor History';
  static String get mistUsage => _isBn ? 'মিস্ট ব্যবহার' : 'Mist Usage';
  static String get noChartData => _isBn ? 'কোনো ডেটা নেই' : 'No Data Yet';
  static String get noChartDataDesc => _isBn
      ? 'ডিভাইস অনলাইনে আসলে এখানে রিয়েল-টাইম গ্রাফ দেখা যাবে।'
      : 'Real-time sensor graphs will appear here once the device transmits data.';
  static String get min => _isBn ? 'সর্বনিম্ন' : 'Min';
  static String get avg => _isBn ? 'গড়' : 'Avg';
  static String get max => _isBn ? 'সর্বোচ্চ' : 'Max';
  static String readingsCount(int count, String range) => _isBn
      ? '$count টি রিডিং · বিগত $range'
      : '$count readings · last $range';
  static String get totalMistRuntime =>
      _isBn ? 'মোট চলার সময়' : 'Total Active Time';
  static String formatRuntime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (_isBn) {
      if (h > 0) {
        return '$h ঘণ্টা $m মি.';
      }
      return '$m মিনিট';
    } else {
      if (h > 0) {
        return '${h}h ${m}m';
      }
      return '${m}m';
    }
  }

  // Profile & Settings Screen
  static String get profileAndSettings =>
      _isBn ? 'প্রোফাইল ও সেটিংস' : 'Profile & Settings';
  static String get accountInfo =>
      _isBn ? 'অ্যাকাউন্ট তথ্য' : 'Account Information';
  static String get email => _isBn ? 'ইমেইল' : 'Email';
  static String get userId => _isBn ? 'ইউজার আইডি' : 'User ID';
  static String get appSettings =>
      _isBn ? 'অ্যাপ সেটিংস' : 'App Settings';
  static String get language => _isBn ? 'ভাষা (Language)' : 'Language';
  static String get currentLangName => _isBn ? 'বাংলা' : 'English';
  static String get notifications => _isBn ? 'বিজ্ঞপ্তি' : 'Notifications';
  static String get notificationsDesc => _isBn
      ? 'পানি শেষ হলে বা সতর্কবার্তা আসলে নোটিফিকেশন পান'
      : 'Receive alerts when water tank is low';
  static String get linkedDevices =>
      _isBn ? 'সংযুক্ত ডিভাইস' : 'Linked Devices';
  static String get manageDevices =>
      _isBn ? 'ডিভাইস ব্যবস্থাপনা' : 'Manage Devices';
  static String get appVersion => _isBn ? 'অ্যাপ সংস্করণ' : 'App Version';
  static String get firmwareSupport =>
      _isBn ? 'ফার্মওয়্যার সাপোর্ট' : 'Firmware Support';
  static String get signOut => _isBn ? 'সাইন আউট' : 'Sign Out';
  static String get signOutConfirmTitle =>
      _isBn ? 'সাইন আউট করবেন?' : 'Sign Out?';
  static String get signOutConfirmDesc => _isBn
      ? 'আপনি কি নিশ্চিত যে অ্যাকাউন্ট থেকে সাইন আউট করতে চান?'
      : 'Are you sure you want to sign out of your account?';
}

