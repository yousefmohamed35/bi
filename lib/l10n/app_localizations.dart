import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'Anmka Educational Platform'**
  String get appName;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// General settings section title
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettings;

  /// Language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Notifications setting
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Dark mode setting
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Privacy and security setting
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacyAndSecurity;

  /// Help & Contact Us setting
  ///
  /// In en, this message translates to:
  /// **'Help & Contact Us'**
  String get helpAndContactUs;

  /// Change password
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// Arabic language name
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// English language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Language selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Language change success message
  ///
  /// In en, this message translates to:
  /// **'Language changed to {name}'**
  String languageChanged(String name);

  /// Preferences update success message
  ///
  /// In en, this message translates to:
  /// **'Preferences updated successfully'**
  String get preferencesUpdated;

  /// Generic OK button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Title for the first-launch warning dialog
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warningTitle;

  /// First-launch legal warning text
  ///
  /// In en, this message translates to:
  /// **'Warning: all contents are prohibited to resell or used in any commercial uses by the Egyptian law.'**
  String get warningResellText;

  /// First-launch welcome message
  ///
  /// In en, this message translates to:
  /// **'And you are welcome to be one of the bimaristanian and a member in our small family.'**
  String get warningWelcomeText;

  /// Chat menu label
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// Conversations label
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get conversations;

  /// Instructor earnings label
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// Subtitle shown for chat entry (students)
  ///
  /// In en, this message translates to:
  /// **'Message teachers'**
  String get messageTeachers;

  /// Shown when lesson is missing
  ///
  /// In en, this message translates to:
  /// **'No lesson'**
  String get noLesson;

  /// Shown in lesson viewer when lesson type is file/material
  ///
  /// In en, this message translates to:
  /// **'This lesson is a file'**
  String get lessonIsFile;

  /// Generic loading message for file viewer
  ///
  /// In en, this message translates to:
  /// **'Loading file...'**
  String get loadingFile;

  /// Shown when a file cannot be displayed
  ///
  /// In en, this message translates to:
  /// **'Cannot display file'**
  String get cannotDisplayFile;

  /// Fallback title for file/PDF preview screen
  ///
  /// In en, this message translates to:
  /// **'File preview'**
  String get filePreviewTitle;

  /// PDF page indicator
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageIndicator(int current, int total);

  /// Shown when PDF/file download fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load file. Please check your internet connection or that the file exists.'**
  String get failedToLoadFile;

  /// Error loading PDF/file with details
  ///
  /// In en, this message translates to:
  /// **'Error loading file: {error}'**
  String errorLoadingFileWithDetails(String error);

  /// Error displaying PDF/file with details
  ///
  /// In en, this message translates to:
  /// **'Error displaying file: {error}'**
  String errorDisplayingFileWithDetails(String error);

  /// Preferences update error message
  ///
  /// In en, this message translates to:
  /// **'Error updating preferences'**
  String get errorUpdatingPreferences;

  /// Default user name
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// Login screen title
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Email field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Email or phone number field
  ///
  /// In en, this message translates to:
  /// **'Email or Phone Number'**
  String get emailOrPhone;

  /// Enter email or phone placeholder text
  ///
  /// In en, this message translates to:
  /// **'Enter your email or phone number'**
  String get enterEmailOrPhone;

  /// Invalid email or phone error message
  ///
  /// In en, this message translates to:
  /// **'Invalid email or phone number'**
  String get invalidEmailOrPhone;

  /// Password field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No account text
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// Register link
  ///
  /// In en, this message translates to:
  /// **'Register Now'**
  String get registerNow;

  /// Invalid email error message
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get invalidEmail;

  /// Enter email message
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// Enter password message
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// Welcome message in login
  ///
  /// In en, this message translates to:
  /// **'Welcome back! 👋'**
  String get welcomeBack;

  /// Email placeholder text
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterEmail;

  /// Password placeholder text
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// Field required message
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// OR
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// Google
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get google;

  /// Apple
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get apple;

  /// Register screen title
  ///
  /// In en, this message translates to:
  /// **'Create New Account'**
  String get register;

  /// Welcome message in register
  ///
  /// In en, this message translates to:
  /// **'Join us and start your learning journey 🎓'**
  String get joinUsMessage;

  /// Full name field
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// Enter name message
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get pleaseEnterName;

  /// Phone number field
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phone;

  /// Phone number placeholder
  ///
  /// In en, this message translates to:
  /// **'01xxxxxxxxx'**
  String get phonePlaceholder;

  /// Student type label
  ///
  /// In en, this message translates to:
  /// **'Student type'**
  String get studentType;

  /// On-campus student option
  ///
  /// In en, this message translates to:
  /// **'In-class student'**
  String get inPersonStudent;

  /// Online student option
  ///
  /// In en, this message translates to:
  /// **'Online student'**
  String get onlineStudent;

  /// Both option
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get bothStudentTypes;

  /// Validation message for student type
  ///
  /// In en, this message translates to:
  /// **'Please choose your student type'**
  String get selectStudentType;

  /// Invalid phone number error message
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number'**
  String get invalidPhone;

  /// Enter password again
  ///
  /// In en, this message translates to:
  /// **'Enter password again'**
  String get enterPasswordAgain;

  /// I agree to
  ///
  /// In en, this message translates to:
  /// **'I agree to'**
  String get iAgreeTo;

  /// Please accept the terms and conditions
  ///
  /// In en, this message translates to:
  /// **'Please accept the terms and conditions'**
  String get pleaseAcceptTerms;

  /// Create Account
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Already have an account?
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// Terms and conditions
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// Home page
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Courses
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get courses;

  /// Progress
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// Profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Featured courses
  ///
  /// In en, this message translates to:
  /// **'Featured Courses'**
  String get featuredCourses;

  /// Categories
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// Category
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// Fallback label for a topic/chapter
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get topic;

  /// Start learning journey
  ///
  /// In en, this message translates to:
  /// **'Start your learning journey and enroll in your first course'**
  String get startLearningJourney;

  /// Discount text
  ///
  /// In en, this message translates to:
  /// **'50% off on all courses'**
  String get discount50;

  /// Subscribe button
  ///
  /// In en, this message translates to:
  /// **'Subscribe Now'**
  String get subscribeNow;

  /// All
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Newest
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// Highest rated
  ///
  /// In en, this message translates to:
  /// **'Highest Rated'**
  String get highestRated;

  /// Best selling
  ///
  /// In en, this message translates to:
  /// **'Best Selling'**
  String get bestSelling;

  /// Price low to high
  ///
  /// In en, this message translates to:
  /// **'Price: Low to High'**
  String get priceLowToHigh;

  /// Price high to low
  ///
  /// In en, this message translates to:
  /// **'Price: High to Low'**
  String get priceHighToLow;

  /// Courses loading error message
  ///
  /// In en, this message translates to:
  /// **'Error loading courses'**
  String get errorLoadingCourses;

  /// Instructor
  ///
  /// In en, this message translates to:
  /// **'Instructor'**
  String get instructor;

  /// Lessons
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get lessons;

  /// Lesson
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get lesson;

  /// Course
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get course;

  /// Course description
  ///
  /// In en, this message translates to:
  /// **'This course is suitable for both beginners and professionals.'**
  String get courseSuitable;

  /// Enrollment success message
  ///
  /// In en, this message translates to:
  /// **'Enrolled in course successfully'**
  String get enrolledSuccessfully;

  /// Enrollment error message
  ///
  /// In en, this message translates to:
  /// **'Error enrolling in course'**
  String get errorEnrolling;

  /// Added to wishlist message
  ///
  /// In en, this message translates to:
  /// **'Added to wishlist'**
  String get addedToWishlist;

  /// Removed from wishlist message
  ///
  /// In en, this message translates to:
  /// **'Removed from wishlist'**
  String get removedFromWishlist;

  /// Wishlist error message
  ///
  /// In en, this message translates to:
  /// **'Error {action} wishlist'**
  String errorWishlist(String action);

  /// Adding to
  ///
  /// In en, this message translates to:
  /// **'adding to'**
  String get addingTo;

  /// Removing from
  ///
  /// In en, this message translates to:
  /// **'removing from'**
  String get removingFrom;

  /// Start exam
  ///
  /// In en, this message translates to:
  /// **'Start Exam'**
  String get startExam;

  /// Start exam error message
  ///
  /// In en, this message translates to:
  /// **'Error starting exam'**
  String get errorStartingExam;

  /// Submit exam
  ///
  /// In en, this message translates to:
  /// **'Submit Exam'**
  String get submitExam;

  /// Submit exam error message
  ///
  /// In en, this message translates to:
  /// **'Error submitting exam'**
  String get errorSubmittingExam;

  /// Practice exam
  ///
  /// In en, this message translates to:
  /// **'Practice Exam'**
  String get practiceExam;

  /// Question
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// Question number
  ///
  /// In en, this message translates to:
  /// **'Question {number}'**
  String questionNumber(int number);

  /// Next
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Previous
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// Time taken
  ///
  /// In en, this message translates to:
  /// **'Time taken: {minutes} minutes'**
  String timeTaken(int minutes);

  /// Downloads
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// Download link message
  ///
  /// In en, this message translates to:
  /// **'Download link received. Download will start soon...'**
  String get downloadLinkReceived;

  /// Download error message
  ///
  /// In en, this message translates to:
  /// **'Error downloading: {error}'**
  String errorDownloading(String error);

  /// Delete success message
  ///
  /// In en, this message translates to:
  /// **'File deleted successfully'**
  String get fileDeleted;

  /// Delete error message
  ///
  /// In en, this message translates to:
  /// **'Error deleting: {error}'**
  String errorDeleting(String error);

  /// Certificates
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get certificates;

  /// Download success message
  ///
  /// In en, this message translates to:
  /// **'Downloaded successfully: {path}'**
  String downloadSuccessful(String path);

  /// File download error message
  ///
  /// In en, this message translates to:
  /// **'Error downloading file: {error}'**
  String errorDownloadingFile(String error);

  /// Share error message
  ///
  /// In en, this message translates to:
  /// **'Error sharing'**
  String get errorSharing;

  /// Student
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get student;

  /// Live courses
  ///
  /// In en, this message translates to:
  /// **'Live Courses'**
  String get liveCourses;

  /// Registration success message
  ///
  /// In en, this message translates to:
  /// **'Registered for session successfully'**
  String get registeredSuccessfully;

  /// Registration error message
  ///
  /// In en, this message translates to:
  /// **'Error registering for session'**
  String get errorRegistering;

  /// Sunday
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// Monday
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// Tuesday
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// Wednesday
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// Thursday
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// Friday
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// Saturday
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// Enrolled lessons
  ///
  /// In en, this message translates to:
  /// **'Enrolled Lessons'**
  String get enrolledLessons;

  /// Saved files
  ///
  /// In en, this message translates to:
  /// **'Saved Files'**
  String get savedFiles;

  /// Main menu
  ///
  /// In en, this message translates to:
  /// **'Main Menu'**
  String get mainMenu;

  /// Logout
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Logout error message
  ///
  /// In en, this message translates to:
  /// **'Error logging out: {error}'**
  String errorLoggingOut(String error);

  /// Now
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// Lesson number
  ///
  /// In en, this message translates to:
  /// **'Lesson {current} of {total}'**
  String lessonNumber(int current, int total);

  /// All lessons completed
  ///
  /// In en, this message translates to:
  /// **'All lessons completed'**
  String get allLessonsCompleted;

  /// Previous lesson
  ///
  /// In en, this message translates to:
  /// **'Previous Lesson'**
  String get previousLesson;

  /// Next lesson
  ///
  /// In en, this message translates to:
  /// **'Next Lesson'**
  String get nextLesson;

  /// Lesson duration
  ///
  /// In en, this message translates to:
  /// **'Duration: {duration}'**
  String duration(String duration);

  /// Not specified
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get notSpecified;

  /// Design
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get design;

  /// Programming
  ///
  /// In en, this message translates to:
  /// **'Programming'**
  String get programming;

  /// Marketing
  ///
  /// In en, this message translates to:
  /// **'Marketing'**
  String get marketing;

  /// Data
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// Checkout
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// Discount application success message
  ///
  /// In en, this message translates to:
  /// **'Discount applied successfully'**
  String get discountApplied;

  /// Discount check error message
  ///
  /// In en, this message translates to:
  /// **'Error checking discount code'**
  String get errorCheckingDiscount;

  /// Purchase success message
  ///
  /// In en, this message translates to:
  /// **'Purchase completed successfully'**
  String get purchaseSuccessful;

  /// Payment completion error message
  ///
  /// In en, this message translates to:
  /// **'Error completing payment'**
  String get errorCompletingPayment;

  /// Payment processing error message
  ///
  /// In en, this message translates to:
  /// **'Error processing payment'**
  String get errorProcessingPayment;

  /// 20% discount message
  ///
  /// In en, this message translates to:
  /// **'20% discount applied'**
  String get discount20;

  /// Discount
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// Total
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// Edit profile
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// Profile loading error message
  ///
  /// In en, this message translates to:
  /// **'Error loading profile'**
  String get errorLoadingProfile;

  /// Profile update success message
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdated;

  /// Profile update error message
  ///
  /// In en, this message translates to:
  /// **'Error updating profile: {error}'**
  String errorUpdatingProfile(String error);

  /// Country
  ///
  /// In en, this message translates to:
  /// **'Country (Optional)'**
  String get country;

  /// Timezone
  ///
  /// In en, this message translates to:
  /// **'Timezone (Optional)'**
  String get timezone;

  /// Name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// About You
  ///
  /// In en, this message translates to:
  /// **'About You'**
  String get bio;

  /// Save Changes
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// Select Image Source
  ///
  /// In en, this message translates to:
  /// **'Select Image Source'**
  String get selectImageSource;

  /// Camera
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// Gallery
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// Camera permission denied message
  ///
  /// In en, this message translates to:
  /// **'Camera permission denied. Please allow camera access from settings'**
  String get cameraPermissionDenied;

  /// Gallery permission denied message
  ///
  /// In en, this message translates to:
  /// **'Gallery permission denied. Please allow photo access from settings'**
  String get galleryPermissionDenied;

  /// Error picking image message
  ///
  /// In en, this message translates to:
  /// **'Error picking image'**
  String get errorPickingImage;

  /// Avatar uploaded success message
  ///
  /// In en, this message translates to:
  /// **'Avatar uploaded successfully'**
  String get avatarUploaded;

  /// Error uploading avatar message
  ///
  /// In en, this message translates to:
  /// **'Error uploading avatar: {error}'**
  String errorUploadingAvatar(String error);

  /// Password change success message
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChanged;

  /// Password change error message
  ///
  /// In en, this message translates to:
  /// **'Error changing password: {error}'**
  String errorChangingPassword(String error);

  /// Current password
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// New password
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// Confirm password
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// Enter current password message
  ///
  /// In en, this message translates to:
  /// **'Please enter current password'**
  String get pleaseEnterCurrentPassword;

  /// Enter new password message
  ///
  /// In en, this message translates to:
  /// **'Please enter new password'**
  String get pleaseEnterNewPassword;

  /// Confirm password message
  ///
  /// In en, this message translates to:
  /// **'Please confirm password'**
  String get pleaseConfirmPassword;

  /// Forgot password title
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordTitle;

  /// Back to login
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// Send success message
  ///
  /// In en, this message translates to:
  /// **'Sent successfully!'**
  String get sentSuccessfully;

  /// Password reset link sent message
  ///
  /// In en, this message translates to:
  /// **'Password reset link has been sent to your email'**
  String get resetPasswordSent;

  /// Reset password title
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordTitle;

  /// Reset password description
  ///
  /// In en, this message translates to:
  /// **'Enter your email to send a reset link'**
  String get resetPasswordDescription;

  /// Send reset link button
  ///
  /// In en, this message translates to:
  /// **'Send Link'**
  String get sendResetLink;

  /// Send to another email
  ///
  /// In en, this message translates to:
  /// **'Send to another email'**
  String get sendToAnotherEmail;

  /// Exam
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get exams;

  /// Question of
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String questionOf(int current, int total);

  /// Finish exam
  ///
  /// In en, this message translates to:
  /// **'Finish Exam'**
  String get finishExam;

  /// Final result
  ///
  /// In en, this message translates to:
  /// **'Final Result'**
  String get finalResult;

  /// Correct answers
  ///
  /// In en, this message translates to:
  /// **'Correct Answers'**
  String get correctAnswers;

  /// Wrong answers
  ///
  /// In en, this message translates to:
  /// **'Wrong Answers'**
  String get wrongAnswers;

  /// Notifications screen title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Splash screen text
  ///
  /// In en, this message translates to:
  /// **'Explore a Whole new Educational methods and Programms'**
  String get science;

  /// Splash screen text
  ///
  /// In en, this message translates to:
  /// **'Success starts with a step'**
  String get success;

  /// Next
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextStep;

  /// Start now
  ///
  /// In en, this message translates to:
  /// **'Start Now'**
  String get startNow;

  /// My Courses
  ///
  /// In en, this message translates to:
  /// **'My Courses'**
  String get myCourses;

  /// Subject
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subjects;

  /// Number of lessons
  ///
  /// In en, this message translates to:
  /// **'{count} lessons'**
  String lessonsCount(int count);

  /// Courses count label
  ///
  /// In en, this message translates to:
  /// **'{count} courses'**
  String coursesCount(int count);

  /// Free
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// Paid
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// All Courses
  ///
  /// In en, this message translates to:
  /// **'All Courses'**
  String get allCourses;

  /// Number of courses available
  ///
  /// In en, this message translates to:
  /// **'{count} courses available'**
  String coursesAvailable(int count);

  /// Search for a course
  ///
  /// In en, this message translates to:
  /// **'Search for a course...'**
  String get searchCourse;

  /// No results
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// Try searching with different words
  ///
  /// In en, this message translates to:
  /// **'Try searching with different words or change filters'**
  String get tryDifferentSearch;

  /// Egyptian Pound
  ///
  /// In en, this message translates to:
  /// **'{amount} EGP'**
  String egyptianPound(int amount);

  /// No course data available
  ///
  /// In en, this message translates to:
  /// **'No course data available'**
  String get noCourseData;

  /// Course details screen title
  ///
  /// In en, this message translates to:
  /// **'Course Details'**
  String get courseDetailsTitle;

  /// About tab label
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Lessons tab label (chapters + lessons)
  ///
  /// In en, this message translates to:
  /// **'Lessons & Chapters'**
  String get lessonsAndChapters;

  /// Exams and materials tab label
  ///
  /// In en, this message translates to:
  /// **'Exams & Materials'**
  String get examsAndMaterials;

  /// Validation message when review title/comment are missing
  ///
  /// In en, this message translates to:
  /// **'Please enter a title and a comment'**
  String get pleaseEnterReviewTitleAndComment;

  /// Shown when a course review is submitted
  ///
  /// In en, this message translates to:
  /// **'Review submitted successfully'**
  String get reviewSubmittedSuccessfully;

  /// Shown when course reviews fail to load
  ///
  /// In en, this message translates to:
  /// **'Error loading reviews'**
  String get errorLoadingReviews;

  /// Shown when submitting a course review fails
  ///
  /// In en, this message translates to:
  /// **'Error submitting review'**
  String get errorSubmittingReview;

  /// Course feature label
  ///
  /// In en, this message translates to:
  /// **'Lifetime access to content'**
  String get lifetimeAccess;

  /// Course feature label
  ///
  /// In en, this message translates to:
  /// **'Available on all devices'**
  String get availableOnAllDevices;

  /// Course feature label
  ///
  /// In en, this message translates to:
  /// **'Files for download'**
  String get filesForDownload;

  /// Section title in course about tab
  ///
  /// In en, this message translates to:
  /// **'Course Description'**
  String get courseDescriptionTitle;

  /// Section title in course about tab
  ///
  /// In en, this message translates to:
  /// **'What you will get'**
  String get whatYouWillGet;

  /// Section title for reviews
  ///
  /// In en, this message translates to:
  /// **'Reviews & Comments'**
  String get reviewsCommentsTitle;

  /// Review form title
  ///
  /// In en, this message translates to:
  /// **'Add your review'**
  String get addYourReview;

  /// Review title input hint
  ///
  /// In en, this message translates to:
  /// **'Review title'**
  String get reviewTitleHint;

  /// Review comment input hint
  ///
  /// In en, this message translates to:
  /// **'Write your comment...'**
  String get reviewCommentHint;

  /// Send button label
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Title above reviews list
  ///
  /// In en, this message translates to:
  /// **'Student Reviews'**
  String get studentReviewsTitle;

  /// Empty reviews list label
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviewsYet;

  /// Materials card title
  ///
  /// In en, this message translates to:
  /// **'Lesson materials'**
  String get lessonMaterialsTitle;

  /// Materials card subtitle fallback
  ///
  /// In en, this message translates to:
  /// **'Select a lesson to view its materials'**
  String get selectLessonForMaterials;

  /// No PDF message
  ///
  /// In en, this message translates to:
  /// **'No PDF available for this lesson currently'**
  String get noPdfForCurrentLesson;

  /// Generic PDF title
  ///
  /// In en, this message translates to:
  /// **'PDF file'**
  String get pdfFileTitle;

  /// PDF row title
  ///
  /// In en, this message translates to:
  /// **'PDF file - lesson summary'**
  String get pdfLessonSummary;

  /// Passing score suffix
  ///
  /// In en, this message translates to:
  /// **'to pass'**
  String get passingLabel;

  /// Attempts used label
  ///
  /// In en, this message translates to:
  /// **'{used}/{max} attempts'**
  String attemptsUsedLabel(int used, int max);

  /// Points unit label
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get pointsLabel;

  /// Total points label
  ///
  /// In en, this message translates to:
  /// **'Total points'**
  String get totalPointsLabel;

  /// Best score label
  ///
  /// In en, this message translates to:
  /// **'Best score: {score}%'**
  String bestScore(String score);

  /// Best score label when passed
  ///
  /// In en, this message translates to:
  /// **'Best score: {score}% ✓'**
  String bestScorePassed(String score);

  /// Cannot start exam because attempts exhausted
  ///
  /// In en, this message translates to:
  /// **'Attempts exhausted'**
  String get attemptsExhausted;

  /// Bottom bar label for instructor viewing own course
  ///
  /// In en, this message translates to:
  /// **'You are the instructor of this course'**
  String get youAreCourseInstructor;

  /// Retry encouragement message
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Exam result score label
  ///
  /// In en, this message translates to:
  /// **'Your score: {score}%'**
  String yourScore(int score);

  /// Exam result correct answers summary
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct answers'**
  String correctAnswersSummary(int correct, int total);

  /// Course Title
  ///
  /// In en, this message translates to:
  /// **'Course Title'**
  String get courseTitle;

  /// Fallback title shown for course content summary card
  ///
  /// In en, this message translates to:
  /// **'Course Content'**
  String get courseContentTitle;

  /// Trial Exam
  ///
  /// In en, this message translates to:
  /// **'Trial Exam'**
  String get trialExam;

  /// No lessons available
  ///
  /// In en, this message translates to:
  /// **'No lessons available'**
  String get noLessonsAvailable;

  /// Certified certificate
  ///
  /// In en, this message translates to:
  /// **'Certified certificate upon completion'**
  String get certifiedCertificate;

  /// Loading exam
  ///
  /// In en, this message translates to:
  /// **'Loading exam...'**
  String get loadingExam;

  /// No trial exam available
  ///
  /// In en, this message translates to:
  /// **'No trial exam available'**
  String get noTrialExamAvailable;

  /// Start Exam
  ///
  /// In en, this message translates to:
  /// **'Start Exam'**
  String get startExamButton;

  /// Not Available
  ///
  /// In en, this message translates to:
  /// **'Not Available'**
  String get notAvailable;

  /// Enrolling
  ///
  /// In en, this message translates to:
  /// **'Enrolling...'**
  String get enrolling;

  /// Start Learning Now
  ///
  /// In en, this message translates to:
  /// **'Start Learning Now'**
  String get startLearningNow;

  /// Enroll Free
  ///
  /// In en, this message translates to:
  /// **'Enroll Free'**
  String get enrollFree;

  /// Enroll in Course
  ///
  /// In en, this message translates to:
  /// **'Enroll in Course'**
  String get enrollInCourse;

  /// Login required
  ///
  /// In en, this message translates to:
  /// **'Login required'**
  String get loginRequired;

  /// No questions available
  ///
  /// In en, this message translates to:
  /// **'No questions available in exam'**
  String get noQuestionsAvailable;

  /// Error when exam attempt identifier is not available
  ///
  /// In en, this message translates to:
  /// **'Attempt ID is missing'**
  String get attemptIdMissing;

  /// Finish Exam
  ///
  /// In en, this message translates to:
  /// **'Finish Exam'**
  String get finishExamButton;

  /// Loading questions
  ///
  /// In en, this message translates to:
  /// **'Loading questions...'**
  String get loadingQuestions;

  /// Finish
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// Download link unavailable
  ///
  /// In en, this message translates to:
  /// **'Download link unavailable'**
  String get downloadLinkUnavailable;

  /// Downloading
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// Cannot access downloads folder
  ///
  /// In en, this message translates to:
  /// **'Cannot access downloads folder'**
  String get cannotAccessDownloads;

  /// Certificate of Completion
  ///
  /// In en, this message translates to:
  /// **'Certificate of Completion: {course}'**
  String certificateCompletion(String course);

  /// Certificate Number
  ///
  /// In en, this message translates to:
  /// **'Certificate Number: {number}'**
  String certificateNumber(String number);

  /// Verification Link
  ///
  /// In en, this message translates to:
  /// **'Verification Link: {url}'**
  String verificationLink(String url);

  /// Download
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// Share
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No certificates yet
  ///
  /// In en, this message translates to:
  /// **'No certificates yet'**
  String get noCertificatesYet;

  /// Complete courses to get certificates
  ///
  /// In en, this message translates to:
  /// **'Complete courses to get certified certificates'**
  String get completeCoursesForCertificates;

  /// Getting download link
  ///
  /// In en, this message translates to:
  /// **'Getting download link...'**
  String get gettingDownloadLink;

  /// Delete File
  ///
  /// In en, this message translates to:
  /// **'Delete File'**
  String get deleteFile;

  /// Confirm delete file
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this file?'**
  String get confirmDeleteFile;

  /// Cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No downloads
  ///
  /// In en, this message translates to:
  /// **'No downloads'**
  String get noDownloads;

  /// Course will open in offline mode
  ///
  /// In en, this message translates to:
  /// **'Course will open in offline mode'**
  String get willOpenOffline;

  /// No live sessions available
  ///
  /// In en, this message translates to:
  /// **'No live sessions available'**
  String get noLiveSessions;

  /// Sessions will be added soon
  ///
  /// In en, this message translates to:
  /// **'Upcoming sessions will be added soon'**
  String get sessionsComingSoon;

  /// Session link will open
  ///
  /// In en, this message translates to:
  /// **'Session link will open'**
  String get willOpenSessionLink;

  /// Session link unavailable
  ///
  /// In en, this message translates to:
  /// **'Session link unavailable'**
  String get sessionLinkUnavailable;

  /// Coming Soon
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// Starts in
  ///
  /// In en, this message translates to:
  /// **'Starts in'**
  String get startsIn;

  /// hour
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get hour;

  /// minute
  ///
  /// In en, this message translates to:
  /// **'minute'**
  String get minute;

  /// Confirm logout
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get confirmLogout;

  /// Logging out
  ///
  /// In en, this message translates to:
  /// **'Logging out...'**
  String get loggingOut;

  /// My Exams
  ///
  /// In en, this message translates to:
  /// **'My Exams'**
  String get myExams;

  /// View all completed exams
  ///
  /// In en, this message translates to:
  /// **'View all completed exams'**
  String get viewAllExams;

  /// Exam
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get exam;

  /// No completed exams
  ///
  /// In en, this message translates to:
  /// **'No completed exams'**
  String get noCompletedExams;

  /// Start completing exams
  ///
  /// In en, this message translates to:
  /// **'Start completing exams to see your results here'**
  String get startCompletingExams;

  /// A while ago
  ///
  /// In en, this message translates to:
  /// **'A while ago'**
  String get ago;

  /// Days ago
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 day ago} other {{count} days ago}}'**
  String daysAgo(int count);

  /// Hours ago
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 hour ago} other {{count} hours ago}}'**
  String hoursAgo(int count);

  /// Minutes ago
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 minute ago} other {{count} minutes ago}}'**
  String minutesAgo(int count);

  /// Active courses
  ///
  /// In en, this message translates to:
  /// **'{count} active courses'**
  String activeCourse(int count);

  /// Delete Account
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// My Account
  ///
  /// In en, this message translates to:
  /// **'My Account'**
  String get myAccount;

  /// Customize App
  ///
  /// In en, this message translates to:
  /// **'Customize App'**
  String get customizeApp;

  /// All Subjects
  ///
  /// In en, this message translates to:
  /// **'All Subjects'**
  String get allSubjects;

  /// Weekly
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// Monthly
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// Student Rating
  ///
  /// In en, this message translates to:
  /// **'Student Rating'**
  String get studentRating;

  /// Top 10 Students
  ///
  /// In en, this message translates to:
  /// **'Top 10 Students'**
  String get top10Students;

  /// My Exams
  ///
  /// In en, this message translates to:
  /// **'My Exams'**
  String get myExamsButton;

  /// View all completed exams
  ///
  /// In en, this message translates to:
  /// **'View all completed exams'**
  String get viewAllCompletedExams;

  /// Welcome
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name} 👋'**
  String welcome(String name);

  /// Visitor
  ///
  /// In en, this message translates to:
  /// **'Visitor'**
  String get visitor;

  /// Excellent Student
  ///
  /// In en, this message translates to:
  /// **'Excellent Student'**
  String get excellentStudent;

  /// Special Offer
  ///
  /// In en, this message translates to:
  /// **'Special Offer'**
  String get specialOffer;

  /// Subscribe Now
  ///
  /// In en, this message translates to:
  /// **'Subscribe Now'**
  String get subscribeNowButton;

  /// Course
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get enrolledCourse;

  /// Hours
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get learningHours;

  /// Continue Learning
  ///
  /// In en, this message translates to:
  /// **'Continue Learning'**
  String get continueLearning;

  /// Recommended Courses
  ///
  /// In en, this message translates to:
  /// **'Recommended Courses'**
  String get recommendedCourses;

  /// View More
  ///
  /// In en, this message translates to:
  /// **'View More'**
  String get viewMore;

  /// Search for a course, instructor, or topic
  ///
  /// In en, this message translates to:
  /// **'Search for a course, instructor, or topic...'**
  String get searchPlaceholder;

  /// No results found
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// Select the subject you want to learn
  ///
  /// In en, this message translates to:
  /// **'Select the subject you want to learn'**
  String get selectSubject;

  /// No categories
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get noCategories;

  /// Categories will be added soon
  ///
  /// In en, this message translates to:
  /// **'Categories will be added soon'**
  String get categoriesComingSoon;

  /// Passwords do not match
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// Password must be at least 6 characters
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// Confirm New Password
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// Invalid coupon code
  ///
  /// In en, this message translates to:
  /// **'Invalid coupon code'**
  String get invalidCouponCode;

  /// Complete Purchase
  ///
  /// In en, this message translates to:
  /// **'Complete Purchase'**
  String get completePurchase;

  /// Enter coupon code
  ///
  /// In en, this message translates to:
  /// **'Enter coupon code'**
  String get enterCouponCode;

  /// Apply
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Payment Method
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// Fawry
  ///
  /// In en, this message translates to:
  /// **'Fawry'**
  String get fawry;

  /// Pay at any Fawry branch
  ///
  /// In en, this message translates to:
  /// **'Pay at any Fawry branch'**
  String get payAtFawryBranch;

  /// E-Wallet
  ///
  /// In en, this message translates to:
  /// **'E-Wallet'**
  String get eWallet;

  /// E-Wallet description
  ///
  /// In en, this message translates to:
  /// **'Vodafone Cash - Etisalat Cash - Orange Cash'**
  String get walletDescription;

  /// Visa / Mastercard
  ///
  /// In en, this message translates to:
  /// **'Visa / Mastercard'**
  String get visaMastercard;

  /// Credit or Debit Card
  ///
  /// In en, this message translates to:
  /// **'Credit or Debit Card'**
  String get creditDebitCard;

  /// Order Summary
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummary;

  /// Course Price
  ///
  /// In en, this message translates to:
  /// **'Course Price'**
  String get coursePrice;

  /// Egyptian Pound
  ///
  /// In en, this message translates to:
  /// **'{amount} EGP'**
  String egyptianPoundAmount(String amount);

  /// Confirm Payment
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get confirmPayment;

  /// Processing
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No course
  ///
  /// In en, this message translates to:
  /// **'No course'**
  String get noCourse;

  /// Date not specified
  ///
  /// In en, this message translates to:
  /// **'Date not specified'**
  String get dateNotSpecified;

  /// Certifies that
  ///
  /// In en, this message translates to:
  /// **'Certifies that'**
  String get certifiesThat;

  /// has completed this course with grade
  ///
  /// In en, this message translates to:
  /// **'has completed this course with grade'**
  String get hasCompletedWithGrade;

  /// Excellent
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get excellent;

  /// Mathematics
  ///
  /// In en, this message translates to:
  /// **'Mathematics'**
  String get math;

  /// Literature
  ///
  /// In en, this message translates to:
  /// **'Literature'**
  String get literature;

  /// Biology
  ///
  /// In en, this message translates to:
  /// **'Biology'**
  String get biology;

  /// Physics
  ///
  /// In en, this message translates to:
  /// **'Physics'**
  String get physics;

  /// Chemistry
  ///
  /// In en, this message translates to:
  /// **'Chemistry'**
  String get chemistry;

  /// Practical Engineering
  ///
  /// In en, this message translates to:
  /// **'Practical Engineering'**
  String get practicalEngineering;

  /// Creative Approaches to Plane Shapes
  ///
  /// In en, this message translates to:
  /// **'Creative Approaches to Plane Shapes'**
  String get creativePlaneShapes;

  /// Discoveries in Cellular Biology
  ///
  /// In en, this message translates to:
  /// **'Discoveries in Cellular Biology'**
  String get cellularBiologyDiscoveries;

  /// Introduction
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get introduction;

  /// What is Design?
  ///
  /// In en, this message translates to:
  /// **'What is Design?'**
  String get whatIsDesign;

  /// How to Create Wireframe
  ///
  /// In en, this message translates to:
  /// **'How to Create Wireframe'**
  String get howToCreateWireframe;

  /// Your First Design
  ///
  /// In en, this message translates to:
  /// **'Your First Design'**
  String get yourFirstDesign;

  /// Progress
  ///
  /// In en, this message translates to:
  /// **'Progress: {percent}%'**
  String progressPercent(int percent);

  /// Hello, Jacob
  ///
  /// In en, this message translates to:
  /// **'Hello, Jacob 👋'**
  String get helloJacob;

  /// Start your learning journey and enroll in your first course
  ///
  /// In en, this message translates to:
  /// **'Start your learning journey and enroll in your first course'**
  String get startLearningJourneyMessage;

  /// Learn Easily
  ///
  /// In en, this message translates to:
  /// **'Learn Easily'**
  String get learnEasily;

  /// Continuous Progress
  ///
  /// In en, this message translates to:
  /// **'Continuous Progress'**
  String get continuousProgress;

  /// Discover the best educational courses
  ///
  /// In en, this message translates to:
  /// **'Discover the best educational courses with professional teachers from around the world'**
  String get discoverBestCourses;

  /// Track your progress and get certificates
  ///
  /// In en, this message translates to:
  /// **'Track your progress and get certified certificates upon course completion'**
  String get trackProgressAndGetCertificates;

  /// Smart Learning Platform
  ///
  /// In en, this message translates to:
  /// **'Smart Learning Platform'**
  String get smartLearningPlatform;

  /// Certified and Secure Platform
  ///
  /// In en, this message translates to:
  /// **'Certified and Secure Platform'**
  String get certifiedAndSecure;

  /// Every day is a new opportunity to learn
  ///
  /// In en, this message translates to:
  /// **'Ready to start a new journey and be a member of our family'**
  String get everyDayNewOpportunity;

  /// App version
  ///
  /// In en, this message translates to:
  /// **'v1.0.0'**
  String get version;

  /// Number of enrolled courses
  ///
  /// In en, this message translates to:
  /// **'{count} enrolled courses'**
  String enrolledCoursesCount(int count);

  /// Average Progress
  ///
  /// In en, this message translates to:
  /// **'Average Progress'**
  String get averageProgress;

  /// Completed
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// Lesson from total
  ///
  /// In en, this message translates to:
  /// **'Lesson {current} of {total}'**
  String lessonFrom(int current, int total);

  /// Hour short
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hourShort;

  /// A while ago
  ///
  /// In en, this message translates to:
  /// **'A while ago'**
  String get timeAgo;

  /// No enrolled courses
  ///
  /// In en, this message translates to:
  /// **'You haven\'t enrolled in any courses yet'**
  String get noEnrolledCourses;

  /// Explore Courses
  ///
  /// In en, this message translates to:
  /// **'Explore Courses'**
  String get exploreCourses;

  /// No Title
  ///
  /// In en, this message translates to:
  /// **'No Title'**
  String get noTitle;

  /// Egyptian Pound short
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get egyptianPoundShort;

  /// Error loading notifications
  ///
  /// In en, this message translates to:
  /// **'Failed to load notifications: {error}'**
  String errorLoadingNotifications(String error);

  /// Error updating notification
  ///
  /// In en, this message translates to:
  /// **'Failed to update notification: {error}'**
  String errorUpdatingNotification(String error);

  /// Error updating notifications
  ///
  /// In en, this message translates to:
  /// **'Failed to update notifications: {error}'**
  String errorUpdatingNotifications(String error);

  /// New Notifications
  ///
  /// In en, this message translates to:
  /// **'New Notifications'**
  String get newNotifications;

  /// Number of new notifications
  ///
  /// In en, this message translates to:
  /// **'{count} new notifications'**
  String newNotificationsCount(int count);

  /// Mark All as Read
  ///
  /// In en, this message translates to:
  /// **'Mark All as Read'**
  String get markAllAsRead;

  /// New
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newSection;

  /// Past
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get past;

  /// No Notifications
  ///
  /// In en, this message translates to:
  /// **'No Notifications'**
  String get noNotifications;

  /// New notifications will appear here
  ///
  /// In en, this message translates to:
  /// **'New notifications will appear here'**
  String get newNotificationsWillAppear;

  /// Recently
  ///
  /// In en, this message translates to:
  /// **'Recently'**
  String get recently;

  /// Minutes ago
  ///
  /// In en, this message translates to:
  /// **'{count} minutes ago'**
  String minutesAgoShort(int count);

  /// Hours ago
  ///
  /// In en, this message translates to:
  /// **'{count} hours ago'**
  String hoursAgoShort(int count);

  /// Days ago
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgoShort(int count);

  /// Total Exams
  ///
  /// In en, this message translates to:
  /// **'Total Exams'**
  String get totalExams;

  /// Passed
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get passed;

  /// Failed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// Undefined date
  ///
  /// In en, this message translates to:
  /// **'Undefined date'**
  String get undefinedDate;

  /// January
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get monthJanuary;

  /// February
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get monthFebruary;

  /// March
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get monthMarch;

  /// April
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get monthApril;

  /// May
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// June
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get monthJune;

  /// July
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get monthJuly;

  /// August
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get monthAugust;

  /// September
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get monthSeptember;

  /// October
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get monthOctober;

  /// November
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get monthNovember;

  /// December
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get monthDecember;

  /// Downloaded files
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {downloaded file} other {downloaded files}}'**
  String downloadedFiles(int count);

  /// Storage
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// Storage used
  ///
  /// In en, this message translates to:
  /// **'{used} GB of {limit} GB used'**
  String storageUsed(String used, String limit);

  /// File
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// Undefined size
  ///
  /// In en, this message translates to:
  /// **'Undefined size'**
  String get undefinedSize;

  /// Watch Offline
  ///
  /// In en, this message translates to:
  /// **'Watch Offline'**
  String get watchOffline;

  /// File ID not available
  ///
  /// In en, this message translates to:
  /// **'File ID not available'**
  String get fileIdNotAvailable;

  /// Download link not available
  ///
  /// In en, this message translates to:
  /// **'Download link not available'**
  String get downloadLinkNotAvailable;

  /// Download link obtained
  ///
  /// In en, this message translates to:
  /// **'Download link obtained. Download will start soon...'**
  String get downloadLinkObtained;

  /// Course will open in offline mode
  ///
  /// In en, this message translates to:
  /// **'Course will open in offline mode'**
  String get courseWillOpenOffline;

  /// Course ID not available
  ///
  /// In en, this message translates to:
  /// **'Course ID not available'**
  String get courseIdNotAvailable;

  /// Download courses to watch offline
  ///
  /// In en, this message translates to:
  /// **'Download courses to watch offline'**
  String get downloadCoursesToWatchOffline;

  /// Number of sessions
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1 {session} other {sessions}} {status}'**
  String liveSessionsCount(int count, String status);

  /// live
  ///
  /// In en, this message translates to:
  /// **'live'**
  String get live;

  /// upcoming
  ///
  /// In en, this message translates to:
  /// **'upcoming'**
  String get upcoming;

  /// Live Session
  ///
  /// In en, this message translates to:
  /// **'Live Session'**
  String get liveSession;

  /// Live Now
  ///
  /// In en, this message translates to:
  /// **'Live Now'**
  String get liveNow;

  /// Remind Me
  ///
  /// In en, this message translates to:
  /// **'Remind Me'**
  String get remindMe;

  /// Join Now
  ///
  /// In en, this message translates to:
  /// **'Join Now'**
  String get joinNow;

  /// Successfully registered for session
  ///
  /// In en, this message translates to:
  /// **'Successfully registered for session'**
  String get registeredForSession;

  /// Must login first
  ///
  /// In en, this message translates to:
  /// **'Must login first'**
  String get mustLoginFirst;

  /// day
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get day;

  /// second
  ///
  /// In en, this message translates to:
  /// **'second'**
  String get second;

  /// 1 hour
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get oneHour;

  /// Achieved certificates
  ///
  /// In en, this message translates to:
  /// **'{count} achieved certificates'**
  String achievedCertificates(int count);

  /// Certificate of Completion
  ///
  /// In en, this message translates to:
  /// **'Certificate of Completion'**
  String get certificateOfCompletion;

  /// Download failed
  ///
  /// In en, this message translates to:
  /// **'Download failed: {code}'**
  String downloadFailed(int code);

  /// Certificate Number
  ///
  /// In en, this message translates to:
  /// **'Certificate Number'**
  String get certificateNumberLabel;

  /// Verification Link
  ///
  /// In en, this message translates to:
  /// **'Verification Link'**
  String get verificationLinkLabel;

  /// Attendance
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get centerAttendance;

  ///  attendance description
  ///
  /// In en, this message translates to:
  /// **'Show this QR code to mark your attendance'**
  String get centerAttendanceDescription;

  /// Loading QR code
  ///
  /// In en, this message translates to:
  /// **'Loading QR code...'**
  String get loadingQrCode;

  /// Error loading QR code
  ///
  /// In en, this message translates to:
  /// **'Error loading QR code'**
  String get errorLoadingQrCode;

  /// Scan QR code instruction
  ///
  /// In en, this message translates to:
  /// **'Show this QR code to mark your attendance'**
  String get scanQrCodeInstruction;

  /// Refresh QR Code
  ///
  /// In en, this message translates to:
  /// **'Refresh QR Code'**
  String get refreshQrCode;

  /// Retry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Unknown error
  ///
  /// In en, this message translates to:
  /// **'Unknown error occurred'**
  String get unknownError;

  /// Teachers section title
  ///
  /// In en, this message translates to:
  /// **'Teachers'**
  String get teachers;

  /// All teachers page title
  ///
  /// In en, this message translates to:
  /// **'All Teachers'**
  String get allTeachers;

  /// Fallback teacher title
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get teacherFallback;

  /// Title for teacher courses section
  ///
  /// In en, this message translates to:
  /// **'Courses offered'**
  String get teacherCoursesTitle;

  /// Students count label
  ///
  /// In en, this message translates to:
  /// **'{count} students'**
  String studentsCount(int count);

  /// Course audio record player empty state
  ///
  /// In en, this message translates to:
  /// **'Unable to load recording'**
  String get unableToLoadRecord;

  /// Course details accordion: video lessons subsection
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get courseLessonsSectionVideos;

  /// Course details accordion: PDF lessons subsection
  ///
  /// In en, this message translates to:
  /// **'PDFs'**
  String get courseLessonsSectionPdfs;

  /// Course details accordion: exam lessons subsection
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get courseLessonsSectionExams;

  /// Course details accordion: image lessons subsection
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get courseLessonsSectionImages;

  /// Course details accordion: audio record lessons subsection
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get courseLessonsSectionRecords;

  /// Fallback title when lesson has no image title
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get fallbackLessonImageTitle;

  /// Fallback title when lesson has no audio title
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get fallbackLessonRecordTitle;

  /// Fallback gallery title for image lessons
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get fallbackImagesGalleryTitle;

  /// SnackBar when stream has no quality variants
  ///
  /// In en, this message translates to:
  /// **'No video quality options available'**
  String get noVideoQualityOptions;

  /// SnackBar when only auto quality exists
  ///
  /// In en, this message translates to:
  /// **'Only automatic quality is available for this video'**
  String get onlyAutoQualityAvailable;

  /// Bottom sheet title for quality picker
  ///
  /// In en, this message translates to:
  /// **'Video quality'**
  String get videoQualitySheetTitle;

  /// Automatic video quality option label
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get videoQualityAuto;

  /// Download error when lesson or course id missing
  ///
  /// In en, this message translates to:
  /// **'Cannot download this video'**
  String get cannotDownloadVideoMissingIds;

  /// Download error when URL missing
  ///
  /// In en, this message translates to:
  /// **'No video link available to download'**
  String get noVideoDownloadUrl;

  /// Successful offline video download
  ///
  /// In en, this message translates to:
  /// **'Video downloaded successfully'**
  String get videoDownloadedSuccessfully;

  /// Generic video download failure
  ///
  /// In en, this message translates to:
  /// **'Failed to download video'**
  String get videoDownloadFailed;

  /// Video download error with server or system message
  ///
  /// In en, this message translates to:
  /// **'Error downloading video: {message}'**
  String videoDownloadError(String message);

  /// User cancelled an active download
  ///
  /// In en, this message translates to:
  /// **'Download stopped'**
  String get videoDownloadStopped;

  /// Fallback title for a video lesson
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get defaultVideoLessonTitle;

  /// Fallback course title when API title missing
  ///
  /// In en, this message translates to:
  /// **'Course {courseId}'**
  String defaultCourseTitleWithId(String courseId);

  /// Inline player error state
  ///
  /// In en, this message translates to:
  /// **'Unable to load video'**
  String get videoPlayerLoadError;

  /// Download progress overlay
  ///
  /// In en, this message translates to:
  /// **'Downloading: {percent}%'**
  String downloadProgressPercent(int percent);

  /// Cancel an in-progress download
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopDownloading;

  /// SnackBar when image lesson has no URL
  ///
  /// In en, this message translates to:
  /// **'No image available for this lesson'**
  String get noImageForLesson;

  /// SnackBar when audio lesson has no URL
  ///
  /// In en, this message translates to:
  /// **'No recording available for this lesson'**
  String get noRecordForLesson;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
