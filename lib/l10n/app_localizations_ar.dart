import 'app_localizations.dart';

class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([super.locale = 'ar']);

  @override
  String get appName => 'Nearfo';
  @override
  String get tagline => 'اعرف دائرتك';
  @override
  String get somethingWentWrong => 'حدث خطأ ما';
  @override
  String get signingIn => 'جاري الدخول...';
  @override
  String get loading => 'جاري التحميل...';
  @override
  String get cancel => 'إلغاء';
  @override
  String get save => 'حفظ';
  @override
  String get delete => 'حذف';
  @override
  String get create => 'إنشاء';
  @override
  String get done => 'تم';
  @override
  String get retry => 'إعادة محاولة';
  @override
  String get ok => 'حسناً';
  @override
  String get yes => 'نعم';
  @override
  String get no => 'لا';
  @override
  String get or => 'أو';
  @override
  String get search => 'بحث';
  @override
  String get submit => 'إرسال';
  @override
  String get close => 'إغلاق';
  @override
  String get back => 'رجوع';
  @override
  String get next => 'التالي';
  @override
  String get more => 'المزيد';
  @override
  String get remove => 'إزالة';
  @override
  String get block => 'حظر';
  @override
  String get unblock => 'إلغاء الحظر';
  @override
  String get mute => 'كتم الصوت';
  @override
  String get unmute => 'إلغاء كتم الصوت';
  @override
  String get report => 'إبلاغ';
  @override
  String get share => 'مشاركة';
  @override
  String get edit => 'تعديل';
  @override
  String get post => 'منشور';
  @override
  String get follow => 'متابعة';
  @override
  String get unfollow => 'إلغاء المتابعة';
  @override
  String get message => 'رسالة';
  @override
  String get accept => 'قبول';
  @override
  String get decline => 'رفض';
  @override
  String get continue_ => 'متابعة';
  @override
  String get stop => 'إيقاف';
  @override
  String get use => 'استخدام';
  @override
  String get splashLogoLetter => 'N';
  @override
  String get splashAppName => 'nearfo';
  @override
  String get onboardingSkip => 'تخطي';
  @override
  String get onboardingTitle1 => 'خط أنابيب محلي فائق';
  @override
  String get onboardingDesc1 => '80% محتوى محلي (نطاق قابل للتعديل 100-500 كم).
اكتشف ما يحدث حولك.';
  @override
  String get onboardingTitle2 => 'اعرف دائرتك';
  @override
  String get onboardingDesc2 => 'تواصل مع أشخاص حقيقيين بالقرب منك.
بناء مجتمعك المحلي.';
  @override
  String get onboardingTitle3 => 'اذهب عالمياً';
  @override
  String get onboardingDesc3 => '20% محتوى رائج من كل مكان.
ابقَ على اتصال بالعالم.';
  @override
  String get onboardingGetStarted => 'ابدأ الآن';
  @override
  String get loginWelcome => 'مرحباً بك في Nearfo';
  @override
  String get loginSubtitle => 'قم بتسجيل الدخول للتواصل مع الأشخاص بالقرب منك.';
  @override
  String get loginContinueWithGoogle => 'متابعة باستخدام Google';
  @override
  String get loginContinueWithPhone => 'متابعة برقم الهاتف';
  @override
  String get loginEnterMobile => 'أدخل رقم الهاتف';
  @override
  String get loginSendOtp => 'إرسال OTP';
  @override
  String get loginTermsAgreement => 'بالمتابعة، أنت توافق على شروط الخدمة وسياسة الخصوصية الخاصة بنا';
  @override
  String get loginTermsOfService => 'شروط الخدمة';
  @override
  String get loginPrivacyPolicy => 'سياسة الخصوصية';
  @override
  String get loginInvalidPhone => 'أدخل رقم هاتف صحيح بـ 10 أرقام';
  @override
  String get otpTitle => 'التحقق من OTP';
  @override
  String otpSubtitle({required String phone}) => 'أدخل الكود المكون من 6 أرقام المرسل عبر SMS إلى $phone';
  @override
  String get otpVerify => 'تحقق';
  @override
  String get otpIncomplete => 'أدخل OTP كاملاً بـ 6 أرقام';
  @override
  String get otpResent => 'تم إعادة إرسال OTP!';
  @override
  String get otpResend => 'إعادة إرسال OTP';
  @override
  String get otpPhoneMissing => 'رقم الهاتف غير محدد. عُد للخلف وحاول مرة أخرى.';
  @override
  String otpDevCode({required String otp}) => 'OTP للتطوير: $otp';
  @override
  String get permissionsTitle => 'تفعيل الأذونات';
  @override
  String get permissionsSubtitle => 'Nearfo يحتاج إلى بعض الأذونات لإعطاؤك أفضل تجربة مع الميزات المعتمدة على الموقع والإشعارات ومشاركة الوسائط.';
  @override
  String get permissionLocation => 'الموقع';
  @override
  String get permissionLocationDesc => 'البحث عن الأشخاص والمنشورات بالقرب منك';
  @override
  String get permissionNotifications => 'الإشعارات';
  @override
  String get permissionNotificationsDesc => 'احصل على تنبيهات للإعجابات والتعليقات والرسائل';
  @override
  String get permissionCamera => 'الكاميرا';
  @override
  String get permissionCameraDesc => 'التقط الصور للمنشورات والملف الشخصي';
  @override
  String get permissionPhotos => 'الصور والوسائط';
  @override
  String get permissionPhotosDesc => 'شارك الصور والفيديوهات في المنشورات';
  @override
  String get permissionsAllowAll => 'السماح بجميع الأذونات';
  @override
  String get permissionsRequestingLocation => 'جاري طلب الموقع...';
  @override
  String get permissionsRequestingNotifications => 'جاري طلب الإشعارات...';
  @override
  String get permissionsRequestingCamera => 'جاري طلب الكاميرا...';
  @override
  String get permissionsRequestingMedia => 'جاري طلب الوسائط...';
  @override
  String get permissionsAllDone => 'تم بنجاح!';
  @override
  String get permissionsSettingUp => 'جاري الإعداد...';
  @override
  String get permissionsSkip => 'تخطي الآن';
  @override
  String get setupTitle => 'اضبط هالتك';
  @override
  String get setupSubtitle => 'أخبرنا عن نفسك. هذا يساعد الأشخاص القريبين على إيجادك.';
  @override
  String get setupFullName => 'الاسم الكامل';
  @override
  String get setupEnterName => 'أدخل اسمك';
  @override
  String get setupUsername => 'اسم المستخدم';
  @override
  String get setupUsernamePlaceholder => 'your_username';
  @override
  String get setupUsernamePrefix => '@';
  @override
  String get setupBio => 'السيرة الذاتية (اختياري)';
  @override
  String get setupBioPlaceholder => 'ما هالتك؟';
  @override
  String get setupDob => 'تاريخ الميلاد';
  @override
  String get setupDobPlaceholder => 'اختر تاريخ ميلادك';
  @override
  String get setupShowBirthday => 'اعرض تاريخ الميلاد على الملف الشخصي';
  @override
  String get setupLocation => 'الموقع';
  @override
  String get setupGettingLocation => 'جاري الحصول على الموقع...';
  @override
  String get setupTapToEnable => 'انقر لتفعيل الموقع';
  @override
  String get setupEnable => 'تفعيل';
  @override
  String get setupLocationNote => 'موقعك يفعّل خط الأنابيب المحلي الفائق (100-500 كم قابل للتعديل). لا يتم مشاركته علناً.';
  @override
  String get setupStartVibing => 'ابدأ بالنشر';
  @override
  String get setupNameRequired => 'الاسم مطلوب';
  @override
  String get setupHandleMinLength => 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
  @override
  String get setupLocationRequired => 'يرجى تفعيل الوصول إلى الموقع';
  @override
  String get navHome => 'الرئيسية';
  @override
  String get navDiscover => 'اكتشف';
  @override
  String get navReels => 'الفيديوهات';
  @override
  String get navChat => 'الرسائل';
  @override
  String get navProfile => 'الملف الشخصي';
  @override
  String get homeAppName => 'Nearfo';
  @override
  String get homeFollowing => 'المتابَع';
  @override
  String get homeLocal => 'محلي';
  @override
  String get homeGlobal => 'عالمي';
  @override
  String get homeMixed => 'مختلط';
  @override
  String homeRadiusActive({required String radius}) => 'نطاق بمسافة $radiusكم نشط';
  @override
  String get homeLive => 'مباشر';
  @override
  String get homeNoVibes => 'لا توجد منشورات حتى الآن!';
  @override
  String get homeBeFirst => 'كن الأول في نشر منشور في منطقتك';
  @override
  String get homeEditPost => 'تعديل المنشور';
  @override
  String get homeEditPostHint => 'عدّل منشورك...';
  @override
  String get homePostDeleted => 'تم حذف المنشور';
  @override
  String get homeDeleteFailed => 'فشل حذف المنشور';
  @override
  String get homeSharedToStory => 'تم المشاركة إلى قصتك!';
  @override
  String get composeTitle => 'منشور جديد';
  @override
  String get composeHint => 'ما هالتك اليوم؟';
  @override
  String get composePhoto => 'صورة';
  @override
  String composePhotoCount({required String count}) => 'صورة ($count)';
  @override
  String get composeVideo => 'فيديو';
  @override
  String get composeLocation => 'الموقع';
  @override
  String get composeMood => 'المزاج';
  @override
  String get composeMoodHappy => 'سعيد';
  @override
  String get composeMoodCool => 'رائع';
  @override
  String get composeMoodFire => 'مشتعل';
  @override
  String get composeMoodSleepy => 'نعسان';
  @override
  String get composeMoodThinking => 'متفكر';
  @override
  String get composeMoodAngry => 'غاضب';
  @override
  String get composeMoodParty => 'احتفال';
  @override
  String get composeMoodLove => 'الحب';
  @override
  String get composeWriteSomething => 'اكتب شيئاً أو أضف صورة/فيديو!';
  @override
  String get composeRemovePhotosFirst => 'أزل الصور أولاً لإضافة فيديو';
  @override
  String get composeRemoveVideoFirst => 'أزل الفيديو أولاً لإضافة صور';
  @override
  String get composeVideoTooLarge => 'الفيديو كبير جداً. يرجى اختيار فيديو أقصر.';
  @override
  String get composeOptimizingVideo => 'جاري تحسين الفيديو';
  @override
  String get composeConvertingTo720p => 'جاري التحويل إلى 720p لأفضل جودة';
  @override
  String composeVideoOptimized({required String mb}) => 'تم تحسين الفيديو! تم حفظ $mbMB';
  @override
  String composeVideoStillLarge({required String mb}) => 'الفيديو لا يزال $mbMB بعد الضغط. الحد الأقصى 75MB. جرّب فيديو أقصر.';
  @override
  String get composeVideoTimeout => 'انتهت مهلة رفع الفيديو. جرّب فيديو أقصر أو تحقق من اتصالك.';
  @override
  String get composeImageUploadFailed => 'فشل رفع الصورة';
  @override
  String get composeUploadTimeout => 'انتهت مهلة الرفع. تحقق من اتصالك وحاول مجدداً.';
  @override
  String get composePosted => 'تم النشر!';
  @override
  String composeVideoPreviewError({required String error}) => 'تعذر تحميل معاينة الفيديو: $error';
  @override
  String get discoverTitle => 'اكتشف';
  @override
  String get discoverSearchHint => 'ابحث عن الأصدقاء بالاسم أو @handle...';
  @override
  String get discoverTabViral => 'رائج';
  @override
  String get discoverTabGlobal => 'عالمي';
  @override
  String get discoverTabSuggested => 'مقترح';
  @override
  String get discoverTabMap => 'خريطة';
  @override
  String get discoverTabTrending => 'الشهير';
  @override
  String get discoverTabPeople => 'الأشخاص';
  @override
  String get discoverViralNow => 'رائج الآن';
  @override
  String get discoverOneHour => 'ساعة واحدة';
  @override
  String get discoverSixHours => '6 ساعات';
  @override
  String get discoverTwentyFourHours => '24 ساعة';
  @override
  String get discoverSevenDays => '7 أيام';
  @override
  String get discoverThirtyDays => '30 يوماً';
  @override
  String get discoverLocal => 'محلي';
  @override
  String get discoverGlobal => 'عالمي';
  @override
  String get chatTitle => 'الرسائل';
  @override
  String get chatNewMessage => 'رسالة جديدة';
  @override
  String get chatSearchConversations => 'البحث في المحادثات';
  @override
  String get chatNoConversations => 'لا توجد محادثات حتى الآن';
  @override
  String get chatStartChatting => 'ابدأ الحوار مع الأشخاص القريبين!';
  @override
  String get chatSearchByName => 'ابحث بالاسم أو @handle';
  @override
  String get chatPinChat => 'تثبيت الرسالة';
  @override
  String get chatPinned => 'تم تثبيت الرسالة';
  @override
  String get chatUnpinned => 'تم إلغاء تثبيت الرسالة';
  @override
  String get chatMuteNotifications => 'كتم الإشعارات';
  @override
  String get chatNotificationsMuted => 'تم كتم الإشعارات';
  @override
  String get chatNotificationsUnmuted => 'تم إلغاء كتم الإشعارات';
  @override
  String get chatArchive => 'أرشفة الرسالة';
  @override
  String get chatArchived => 'تم أرشفة الرسالة';
  @override
  String get chatDeleteConversation => 'حذف المحادثة';
  @override
  String get chatDeleteConversationTitle => 'حذف المحادثة؟';
  @override
  String chatDeleteConversationMsg({required String name}) => 'سيؤدي هذا إلى حذف المحادثة بأكملها مع $name بشكل دائم. لا يمكن التراجع عن هذا الإجراء.';
  @override
  String get chatUndo => 'تراجع';
  @override
  String get chatConversationDeleted => 'تم حذف المحادثة';
  @override
  String get chatOnline => 'متصل';
  @override
  String get chatJustNow => 'للتو';
  @override
  String get chatTo => 'إلى: ';
  @override
  String get chatActiveNow => 'نشط الآن';
  @override
  String get chatSaySomething => 'قل شيئاً...';
  @override
  String get chatCalling => 'جاري الاتصال...';
  @override
  String get chatNoAnswer => 'لا إجابة';
  @override
  String get chatCannotConnect => 'تعذر الاتصال بالخادم. تحقق من الإنترنت.';
  @override
  String chatScreenshotAlert({required String user}) => 'التقط $user لقطة شاشة من هذه الرسالة';
  @override
  String chatMessageRequests({required String count, required String plural}) => '$count طلب رسالة$plural';
  @override
  String get chatAcceptAndRemove => 'قبول وإزالة';
  @override
  String get chatApproveAndRemove => 'الموافقة والإزالة';
  @override
  String get chatThemeBerry => 'التوت';
  @override
  String get chatThemeDefault => 'الافتراضي';
  @override
  String get chatThemeOcean => 'المحيط';
  @override
  String get chatThemeSunset => 'الغروب';
  @override
  String get chatThemeForest => 'الغابة';
  @override
  String get chatThemeGold => 'الذهب';
  @override
  String get chatThemeLavender => 'الخزامى';
  @override
  String get chatThemeMidnight => 'منتصف الليل';
  @override
  String get chatMediaCamera => 'الكاميرا';
  @override
  String get chatMediaPhoto => 'صورة';
  @override
  String get chatMediaVideo => 'فيديو';
  @override
  String get chatMediaAudio => 'صوت';
  @override
  String get chatMediaGif => 'GIF';
  @override
  String get chatSettingsProfile => 'الملف الشخصي';
  @override
  String get chatSettingsSearch => 'بحث';
  @override
  String get chatSettingsTheme => 'المظهر';
  @override
  String get chatSettingsNicknames => 'الألقاب';
  @override
  String get chatSettingsCustomNicknamesSet => 'تم تعيين ألقاب مخصصة';
  @override
  String get chatSettingsSetNicknames => 'تعيين الألقاب';
  @override
  String get chatSettingsDisappearing => 'الرسائل المختفية';
  @override
  String get chatSettingsDisappearingOff => 'معطّل';
  @override
  String get chatSettingsDisappearing24h => '24 ساعة';
  @override
  String get chatSettingsDisappearing7d => '7 أيام';
  @override
  String get chatSettingsDisappearing90d => '90 يوماً';
  @override
  String get chatSettingsPrivacy => 'الخصوصية والأمان';
  @override
  String get chatSettingsPrivacyDesc => 'التشفير والبيانات';
  @override
  String get chatSettingsEncrypted => 'رسائل مشفرة';
  @override
  String get chatSettingsEncryptedDesc => 'الرسائل مشفرة باستخدام AES-256 وتُخزن بأمان.';
  @override
  String get chatSettingsCreateGroup => 'إنشاء محادثة جماعية';
  @override
  String get chatSettingsCreateGroupBtn => 'إنشاء مجموعة';
  @override
  String chatSettingsBlockUser({required String name}) => 'حظر $name؟';
  @override
  String chatSettingsUserBlocked({required String name}) => 'تم حظر $name';
  @override
  String chatSettingsUserRestricted({required String name}) => 'تم تقييد $name';
  @override
  String get chatSettingsRestrictionDesc => 'التقييد: يمكنهم إرسال رسائل إليك، لكن الردود تذهب إلى طلبات الرسائل';
  @override
  String chatSettingsHideOnline({required String name}) => 'إخفاء حالة الاتصال عن $name';
  @override
  String chatSettingsCanSeeOnline({required String name}) => '$name يمكنه رؤية حالة اتصالك';
  @override
  String chatSettingsCannotSeeOnline({required String name}) => '$name لا يمكنه رؤية متى تكون نشطاً';
  @override
  String get chatSettingsChatDeleted => 'تم حذف الرسالة';
  @override
  String get chatSettingsChatMuted => 'تم كتم الرسالة';
  @override
  String get chatSettingsChatUnmuted => 'تم إلغاء كتم الرسالة';
  @override
  String get chatSettingsFailedDelete => 'فشل حذف الرسالة';
  @override
  String get chatSettingsFailedOnline => 'فشل تحديث حالة الاتصال';
  @override
  String get chatSettingsFailedBlock => 'فشل تحديث حالة الحظر';
  @override
  String get chatSettingsFailedRestriction => 'فشل تحديث التقييد';
  @override
  String get chatSettingsFailedVisibility => 'فشل تحديث الرؤية';
  @override
  String get chatSettingsReportFakeAccount => 'حساب وهمي';
  @override
  String get chatSettingsReportHarassment => 'التحرش';
  @override
  String get chatSettingsReportInappropriate => 'محتوى غير لائق';
  @override
  String get chatSettingsFailedReport => 'فشل تقديم التقرير';
  @override
  String get profileTitle => 'الملف الشخصي';
  @override
  String get profilePosts => 'المنشورات';
  @override
  String get profileFollowers => 'المتابعون';
  @override
  String get profileFollowing => 'المتابَع';
  @override
  String get profileAdminPanel => 'لوحة الإدارة';
  @override
  String get profileAnalytics => 'التحليلات';
  @override
  String get profileEarnings => 'لوحة الأرباح';
  @override
  String get profileGoPremium => 'اذهب Premium';
  @override
  String get profileMyCircle => 'دائرتي';
  @override
  String get profileSavedPosts => 'المنشورات المحفوظة';
  @override
  String get profileSavedReels => 'الفيديوهات المحفوظة';
  @override
  String get profileSignOut => 'تسجيل الخروج';
  @override
  String get profileEditProfile => 'تعديل الملف الشخصي';
  @override
  String get profileNearfoScore => 'نقاط Nearfo';
  @override
  String get profileNearfoScoreDesc => 'تأثيرك المحلي والتفاعل';
  @override
  String get profilePro => 'PRO';
  @override
  String get profileOwner => 'المالك';
  @override
  String get profilePremium => 'Premium';
  @override
  String get editProfileTitle => 'تعديل الملف الشخصي';
  @override
  String get editProfileDisplayName => 'اسم العرض';
  @override
  String get editProfileUsername => 'اسم المستخدم';
  @override
  String get editProfileUsernameRequired => 'اسم المستخدم مطلوب';
  @override
  String get editProfileUsernameMinLength => 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
  @override
  String get editProfileUsernameInvalid => 'فقط الحروف والأرقام والشرطات السفلية';
  @override
  String get editProfileNameRequired => 'الاسم مطلوب';
  @override
  String get editProfileNameMinLength => 'الاسم يجب أن يكون حرفين على الأقل';
  @override
  String get editProfileBio => 'السيرة الذاتية';
  @override
  String get editProfileBioHint => 'أخبر الناس عن نفسك...';
  @override
  String get editProfileDob => 'تاريخ الميلاد';
  @override
  String get editProfileNotSet => 'غير محدد';
  @override
  String get editProfileLocation => 'الموقع';
  @override
  String get editProfileLocationAutoUpdate => 'يتحدث الموقع تلقائياً بناءً على GPS الخاص بك';
  @override
  String get editProfileChangePhoto => 'تغيير الصورة';
  @override
  String get editProfileTakePhoto => 'التقط صورة';
  @override
  String get editProfileChooseGallery => 'اختر من المعرض';
  @override
  String get editProfileCreateAvatar => 'إنشاء أفتار رقمي';
  @override
  String get editProfileAvatarDesc => 'صورة ملف شخصي بأسلوب كرتون';
  @override
  String get editProfileTapToSelect => 'انقر للاختيار';
  @override
  String get editProfileUpdated => 'تم تحديث الملف الشخصي!';
  @override
  String get editProfilePhotoUpdated => 'تم تحديث الصورة!';
  @override
  String get editProfileUploadFailed => 'فشل الرفع';
  @override
  String editProfileError({required String error}) => 'خطأ: $error';
  @override
  String get editProfileFailed => 'فشل تحديث الملف الشخصي';
  @override
  String get userProfileNoPosts => 'لا توجد منشورات حتى الآن';
  @override
  String get userProfileBlockUser => 'حظر المستخدم';
  @override
  String get userProfileBlockConfirm => 'حظر المستخدم؟';
  @override
  String get userProfileUnblockUser => 'إلغاء حظر المستخدم';
  @override
  String get userProfileUnblockConfirm => 'إلغاء حظر المستخدم؟';
  @override
  String get userProfileLocalInfluence => 'التأثير المحلي والتفاعل';
  @override
  String get userProfileBlocked => 'لقد حظرت هذا المستخدم';
  @override
  String get userProfileBlockedByThem => 'لا يمكنك التفاعل مع هذا الملف الشخصي لأنهم حظروك';
  @override
  String get userProfileUnblockDesc => 'سيكونون قادرين على رؤية ملفك الشخصي والتفاعل معك مجدداً.';
  @override
  String get userProfileBlockDesc => 'لن يكونوا قادرين على رؤية ملفك الشخصي والتفاعل معك.';
  @override
  String get userProfileBlockedSnack => 'تم حظر المستخدم';
  @override
  String get userProfileUnblockedSnack => 'تم إلغاء حظر المستخدم';
  @override
  String get userProfileNotFound => 'المستخدم غير موجود';
  @override
  String get userProfileNoHandle => 'لا يوجد handle أو userId';
  @override
  String get userProfileFollowFailed => 'فشل تحديث حالة المتابعة';
  @override
  String get userProfileReportUser => 'الإبلاغ عن مستخدم';
  @override
  String get userProfileReportSubmitted => 'تم تقديم التقرير';
  @override
  String followersTitle({required String count}) => 'المتابعون $count';
  @override
  String followingTitle({required String count}) => 'المتابَع $count';
  @override
  String get followersLoadMore => 'تحميل المزيد';
  @override
  String get followersNoFollowers => 'لا متابعون حتى الآن';
  @override
  String get followersNotFollowing => 'لم تتابع أي شخص حتى الآن';
  @override
  String get followersUserIdMissing => 'معرف المستخدم مفقود';
  @override
  String get notificationsTitle => 'الإشعارات';
  @override
  String get notificationsNone => 'لا توجد إشعارات حتى الآن';
  @override
  String get notificationsNoneDesc => 'عندما يتفاعل الأشخاص مع منشوراتك،
ستراها هنا';
  @override
  String get notificationsMarkAllRead => 'اعتبر الكل كمقروء';
  @override
  String get reelsForYou => 'لك';
  @override
  String get reelsFollowing => 'المتابَع';
  @override
  String get reelsNearby => 'بالقرب منك';
  @override
  String get reelsNoReels => 'لا توجد فيديوهات حتى الآن';
  @override
  String get reelsBeFirst => 'كن الأول في نشر فيديو!';
  @override
  String get reelsLoading => 'جاري تحميل الفيديو...';
  @override
  String get reelsShare => 'مشاركة الفيديو';
  @override
  String reelsShareText({required String url}) => 'تحقق من هذا الفيديو على Nearfo! $url';
  @override
  String get reelsDeleteReel => 'حذف الفيديو';
  @override
  String get reelsDeleteConfirm => 'حذف الفيديو؟';
  @override
  String get reelsDeleteWarning => 'لا يمكن التراجع عن هذا الإجراء.';
  @override
  String get reelsReportReel => 'الإبلاغ عن الفيديو';
  @override
  String get reelsReportSubmitted => 'تم تقديم التقرير';
  @override
  String reelsOriginalAudio({required String name}) => 'الصوت الأصلي - $name';
  @override
  String get createReelTitle => 'إنشاء فيديو جديد';
  @override
  String get createReelRecord => 'تسجيل فيديو';
  @override
  String get createReelRecordDesc => 'استخدم الكاميرا لتسجيل فيديو جديد';
  @override
  String get createReelSelect => 'اختر فيديو موجود';
  @override
  String get createReelUploadPhoto => 'رفع صورة';
  @override
  String get createReelPhotoDesc => 'إنشاء فيديو صورة من المعرض';
  @override
  String get createReelSettings => 'الإعدادات';
  @override
  String get createReelWhoCanSee => 'من يمكنه الرؤية';
  @override
  String get createReelEveryone => 'الجميع';
  @override
  String get createReelNearby => 'بالقرب منك';
  @override
  String get createReelCircle => 'الدائرة';
  @override
  String get createReelSpecs => 'فيديو: أقصى 90 ث • 720p | صورة: أقصى 20MB';
  @override
  String get createReelCameraPermission => 'مطلوب إذن الكاميرا';
  @override
  String get createReelGalleryPermission => 'مطلوب إذن المعرض';
  @override
  String get createReelPreparingVideo => 'جاري تحضير الفيديو...';
  @override
  String get createReelConverting => 'جاري التحويل إلى 720p لأفضل جودة...';
  @override
  String get createReelOptimizing => 'جاري تحسين الفيديو';
  @override
  String get createReelVideoTooLarge => 'الفيديو كبير جداً (أقصى 1GB). يرجى اختيار فيديو أقصر.';
  @override
  String get createReelImageTooLarge => 'الصورة كبيرة جداً (أقصى 20MB). يرجى اختيار صورة أصغر.';
  @override
  String createReelCompressedTooLarge({required String mb}) => 'الفيديو كبير جداً بعد الضغط ($mbMB). أقصى 75MB.';
  @override
  String createReelCompressionFailed({required String error}) => 'فشل الضغط: $error';
  @override
  String createReelPickVideoFailed({required String error}) => 'فشل اختيار الفيديو: $error';
  @override
  String createReelPickImageFailed({required String error}) => 'فشل اختيار الصورة: $error';
  @override
  String get storyLabel => 'قصة';
  @override
  String get reelLabel => 'فيديو';
  @override
  String get liveLabel => 'مباشر';
  @override
  String get postLabel => 'منشور';
  @override
  String get storyMulti => 'متعدد';
  @override
  String get storyBoomerang => 'Boomerang';
  @override
  String get storyTapInstruction => 'انقر الزر لالتقاط صورة
اضغط مع الاستمرار لفيديو 30 ث
أو اختر من المعرض أدناه';
  @override
  String get storyTapShort => 'انقر للصورة • اضغط مع الاستمرار لفيديو 30 ث';
  @override
  String get storyTapReel => 'انقر لتسجيل فيديو';
  @override
  String get storyPhotoPermission => 'مطلوب إذن مكتبة الصور';
  @override
  String get storyCameraPermission => 'مطلوب إذن الكاميرا';
  @override
  String get storyGalleryPermission => 'مطلوب إذن المعرض';
  @override
  String get storyMaxDuration => '30 ثانية';
  @override
  String get storyLayout => 'التخطيط';
  @override
  String get storySettings => 'الإعدادات';
  @override
  String get storyAddAnother => 'أضف آخر';
  @override
  String storyProgress({required String current, required String total}) => 'القصة $current من $total';
  @override
  String get storyEditEach => 'عدّل كل قصة قبل الرفع';
  @override
  String get storyUploaded => 'تم رفع القصة!';
  @override
  String get storyAddAnotherQuestion => 'هل تريد إضافة قصة أخرى؟';
  @override
  String get storyContinueUploading => 'هل تريد متابعة الرفع؟';
  @override
  String storyUploadedCount({required String uploaded, required String max}) => '$uploaded من $max قصص مضافة';
  @override
  String get storyMaxReached => 'الحد الأقصى 10 قصص في المرة';
  @override
  String storyMaxReachedCount({required String count}) => '$count قصص مرفوعة! (الحد الأقصى وصل)';
  @override
  String storyAllUploaded({required String count}) => '$count قصص مرفوعة!';
  @override
  String storyContinueRemaining({required String done, required String total}) => '$done من $total قصص تمت.
هل تريد المتابعة مع القصص المتبقية؟';
  @override
  String get storyEditorText => 'نص';
  @override
  String get storyEditorStickers => 'الملصقات';
  @override
  String get storyEditorEffects => 'التأثيرات';
  @override
  String get storyEditorDraw => 'رسم';
  @override
  String get storyEditorMusic => 'موسيقى';
  @override
  String get storyEditorAddMusic => 'إضافة موسيقى';
  @override
  String get storyEditorAddPoll => 'إضافة استطلاع';
  @override
  String get storyEditorAddQuestion => 'إضافة سؤال';
  @override
  String get storyEditorAddLink => 'إضافة رابط';
  @override
  String get storyEditorAddCountdown => 'إضافة عد تنازلي';
  @override
  String get storyEditorAddMention => 'إضافة إشارة';
  @override
  String get storyEditorMusicRemoved => 'تم حذف الموسيقى';
  @override
  String get storyEditorSearchMusic => 'البحث عن موسيقى...';
  @override
  String get storyEditorNoMusic => 'لم يتم العثور على موسيقى';
  @override
  String storyEditorMusicError({required String name}) => 'تعذر تشغيل "$name"';
  @override
  String get storyEditorCaption => 'أضف تعليق...';
  @override
  String get storyEditorTypeQuestion => 'اكتب سؤالك';
  @override
  String get storyEditorYourQuestion => 'سؤالك';
  @override
  String get storyEditorAskQuestion => 'اطرح سؤالاً...';
  @override
  String get storyEditorTypeSomething => 'اكتب شيئاً...';
  @override
  String get storyEditorSearchUser => 'ابحث عن مستخدم لإضافة إشارة';
  @override
  String get storyEditorSearchUsers => 'ابحث عن مستخدمين...';
  @override
  String get storyEditorMentionSomeone => 'أضف إشارة لشخص';
  @override
  String get storyEditorMention => 'إشارة';
  @override
  String get storyEditorLinkLabel => 'تسمية الرابط';
  @override
  String get storyEditorLink => 'الرابط';
  @override
  String get storyEditorLinkHint => 'https://...';
  @override
  String get storyEditorCountdownTitle => 'إضافة عد تنازلي';
  @override
  String get storyEditorCountdown => 'العد التنازلي';
  @override
  String get storyEditorAiLabels => 'تسميات AI';
  @override
  String get storyEditorAiSuggested => 'التسميات المقترحة من AI';
  @override
  String get storyEditorHashtag => 'الهاشتاج';
  @override
  String get storyEditorPoll => 'استطلاع';
  @override
  String get storyEditorQuestion => 'سؤال';
  @override
  String get storyEditorLinkTag => 'رابط';
  @override
  String get storyEditorMentionTag => 'إشارة';
  @override
  String get storyEditorLocationTag => 'موقع';
  @override
  String get storyEditorMusicTag => 'موسيقى';
  @override
  String get storyEditorHashtagTag => 'هاشتاج';
  @override
  String get storyEditorOption1 => 'الخيار 1';
  @override
  String get storyEditorOption2 => 'الخيار 2';
  @override
  String get storyEditorPollLabel => 'استطلاع';
  @override
  String get storyEditorCreatePoll => 'إنشاء استطلاع';
  @override
  String get storyEditorShares => 'المشاركات';
  @override
  String storyEditorLikes({required String count}) => 'الإعجابات: $count';
  @override
  String get storyEditorViewers => 'المشاهدون';
  @override
  String storyEditorCountdownEnd({required String date}) => 'الانتهاء: $date';
  @override
  String get storyEditorEventName => 'اسم الحدث';
  @override
  String get storyEditorCountdownTag => 'عد تنازلي';
  @override
  String get storyEditorDays => 'أيام';
  @override
  String get storyEditorHours => 'ساعات';
  @override
  String get storyEditorCountdownTimer => 'مؤقت العد التنازلي';
  @override
  String get storyEditorRemoveElement => 'إزالة هذا العنصر؟';
  @override
  String get storyEditorPermanentMarker => 'قلم دائم';
  @override
  String get storyEditorNormal => 'عادي';
  @override
  String get storyEditorFilterDefault => 'افتراضي';
  @override
  String get storyEditorFilterClarendon => 'Clarendon';
  @override
  String get storyEditorFilterGingham => 'Gingham';
  @override
  String get storyEditorFilterJuno => 'Juno';
  @override
  String get storyEditorFilterLark => 'Lark';
  @override
  String get storyEditorFilterLudwig => 'Ludwig';
  @override
  String get storyEditorFilterPerpetua => 'Perpetua';
  @override
  String get storyEditorFilterReyes => 'Reyes';
  @override
  String get storyEditorFilterSlumber => 'Slumber';
  @override
  String get storyEditorFilterAden => 'Aden';
  @override
  String get storyEditorFilterCrema => 'Crema';
  @override
  String get storyEditorTurnOffCommenting => 'إيقاف التعليقات';
  @override
  String get storyEditorVisibilityEveryone => 'الجميع';
  @override
  String get storyEditorVisibilityCloseFriends => 'الأصدقاء المقربون';
  @override
  String get storyEditorVisibilityMyCircle => 'دائرتي';
  @override
  String get storyEditorVisibilityNearby => 'بالقرب منك';
  @override
  String get storyEditorVisibilityTrending => 'الشهير';
  @override
  String get storyEditorSaveToGallery => 'حفظ إلى المعرض';
  @override
  String get storyEditorSaved => 'تم الحفظ إلى المعرض!';
  @override
  String get storyEditorPostReel => 'نشر الفيديو';
  @override
  String get storyEditorPostingReel => 'جاري نشر فيديوك...';
  @override
  String get storyEditorSharingStory => 'جاري مشاركة قصتك...';
  @override
  String get storyEditorReelFailed => 'فشل إنشاء الفيديو';
  @override
  String get storyEditorStoryFailed => 'فشل إنشاء القصة';
  @override
  String get storyEditorImageUploadFailed => 'فشل رفع الصورة';
  @override
  String get storyEditorVideoUploadFailed => 'فشل رفع الفيديو';
  @override
  String get storyEditorUploadEmptyUrl => 'الرفع أرجع عنواناً فارغاً';
  @override
  String get storyEditorCouldNotSave => 'تعذر الحفظ';
  @override
  String get storiesDeleteStory => 'حذف القصة';
  @override
  String get storiesDeleteConfirm => 'حذف القصة؟';
  @override
  String get storiesDeleteWarning => 'سيتم حذف هذه القصة بشكل دائم. لا يمكن التراجع عن هذا الإجراء.';
  @override
  String get storiesReportStory => 'الإبلاغ عن القصة';
  @override
  String get storiesDeleted => 'تم حذف القصة';
  @override
  String get storiesReported => 'تم الإبلاغ عن القصة';
  @override
  String get storiesReplySent => 'تم إرسال الرد!';
  @override
  String get storiesDeleteFailed => 'فشل الحذف';
  @override
  String get storiesNetworkError => 'خطأ في الشبكة، حاول مجدداً';
  @override
  String get storiesSendMessage => 'أرسل رسالة...';
  @override
  String storiesViewers({required String count}) => 'المشاهدون ($count)';
  @override
  String storiesLikes({required String count}) => 'الإعجابات ($count)';
  @override
  String get storiesNoViewers => 'لا مشاهدين حتى الآن';
  @override
  String get storiesNoLikes => 'لا إعجابات حتى الآن';
  @override
  String get storiesUnknown => 'غير معروف';
  @override
  String get storiesCouldntLoad => 'تعذر التحميل';
  @override
  String get storiesMediaNotAvailable => 'الوسائط غير متاحة';
  @override
  String get collectionsTitle => 'المجموعات';
  @override
  String get collectionsNone => 'لا توجد مجموعات حتى الآن';
  @override
  String get collectionsNoneDesc => 'احفظ المنشورات في مجموعات لتنظيمها';
  @override
  String get collectionsCreate => 'إنشاء مجموعة';
  @override
  String get collectionsNew => 'مجموعة جديدة';
  @override
  String get collectionsNameHint => 'اسم المجموعة';
  @override
  String get collectionsUntitled => 'بدون عنوان';
  @override
  String collectionsPostCount({required String count}) => '$count منشور';
  @override
  String get collectionsNoPosts => 'لا منشورات في هذه المجموعة';
  @override
  String get collectionsDeleteConfirm => 'حذف المجموعة؟';
  @override
  String get collectionsDeleteWarning => 'لا يمكن التراجع عن هذا.';
  @override
  String get savedPostsTitle => 'المنشورات المحفوظة';
  @override
  String get savedPostsNone => 'لا توجد منشورات محفوظة حتى الآن';
  @override
  String get savedPostsNoneDesc => 'ستظهر المنشورات التي تحفظها هنا';
  @override
  String get savedReelsTitle => 'الفيديوهات المحفوظة';
  @override
  String get savedReelsNone => 'لا توجد فيديوهات محفوظة حتى الآن';
  @override
  String get savedReelsNoneDesc => 'ستظهر الفيديوهات التي تضيفها لقائمة المرجعية هنا';
  @override
  String get savedReelsRemoveConfirm => 'إزالة من المحفوظ؟';
  @override
  String get savedReelsRemoveDesc => 'سيتم إزالة هذا الفيديو من قائمة المحفوظات.';
  @override
  String get liveStartTitle => 'بدء بث مباشر';
  @override
  String get liveStartDesc => 'ابدأ بث مباشر وتواصل
مع الأشخاص بالقرب منك!';
  @override
  String get liveYouAreLive => 'أنت مباشر الآن!';
  @override
  String get liveYouAreLiveDesc => 'أنت الآن مباشر! يمكن للمشاهدين الانضمام في أي وقت.';
  @override
  String get liveStreaming => 'البث إلى جمهورك';
  @override
  String get liveStartStreaming => 'ابدأ البث إلى جمهورك';
  @override
  String get liveGoLiveNow => 'اذهب مباشراً الآن';
  @override
  String get liveGoLive => 'اذهب مباشراً';
  @override
  String get liveTitleHint => 'أعطِ عنواناً لبثك المباشر...';
  @override
  String get liveCategoryGeneral => 'عام';
  @override
  String get liveCategoryGaming => 'الألعاب';
  @override
  String get liveCategoryMusic => 'الموسيقى';
  @override
  String get liveCategoryEducation => 'التعليم';
  @override
  String get liveCategoryFitness => 'اللياقة البدنية';
  @override
  String get liveCategoryCooking => 'الطبخ';
  @override
  String get liveCategoryOther => 'آخر';
  @override
  String get liveCategory => 'الفئة';
  @override
  String liveDuration({required String duration}) => 'المدة: $duration';
  @override
  String get liveEndConfirm => 'إنهاء البث المباشر؟';
  @override
  String get liveEndStream => 'إنهاء البث';
  @override
  String get liveEnd => 'إنهاء';
  @override
  String get liveEndWarning => 'سينتهي البث المباشر والمشاهدون سيُقطعون.';
  @override
  String get liveStreamEnded => 'انتهى البث';
  @override
  String get liveStreamEndedDesc => 'انتهى هذا البث المباشر';
  @override
  String get liveNoOneIsLive => 'لا أحد مباشر الآن';
  @override
  String get liveWatch => 'شاهد';
  @override
  String get liveViewer => 'مشاهد';
  @override
  String liveViewers({required String count}) => 'المشاهدون: $count';
  @override
  String liveLikes({required String count}) => 'الإعجابات: $count';
  @override
  String get liveSaySomething => 'قل شيئاً...';
  @override
  String get liveChat => 'الدردشة';
  @override
  String get liveChats => 'الدردشات';
  @override
  String get liveLikesTab => 'الإعجابات';
  @override
  String get liveViewersTab => 'المشاهدون';
  @override
  String get liveSystem => 'النظام';
  @override
  String get liveWelcome => 'مرحباً بك في البث المباشر!';
  @override
  String get liveYou => 'أنت';
  @override
  String get liveStartFailed => 'فشل بدء البث المباشر';
  @override
  String get liveJustStarted => 'بدأ للتو';
  @override
  String liveShareText({required String name, required String title}) => '$name مباشر على Nearfo! "$title" — انضم الآن وشاهد!';
  @override
  String get hashtagRecent => 'حديث';
  @override
  String get hashtagTop => 'الأفضل';
  @override
  String hashtagPostCount({required String count}) => '$count منشور';
  @override
  String hashtagNoPosts({required String tag}) => 'لا منشورات مع #$tag';
  @override
  String get myCircleTitle => 'دائرتي';
  @override
  String get myCircleNone => 'لا أحد في دائرتك حتى الآن';
  @override
  String get myCircleNoneDesc => 'الأشخاص الذين يتابعونك وتتابعهم';
  @override
  String get myCircleNoneDetail => 'تظهر دائرتك المتابعين المتبادلين — الأشخاص الذين تتابعهم والذين يتابعونك أيضاً. ابدأ بمتابعة الأشخاص بالقرب منك!';
  @override
  String get myCircleDiscover => 'اكتشف الأشخاص';
  @override
  String get myCircleMutual => 'متبادل';
  @override
  String myCircleCount({required String count, required String label}) => '$count $label متبادل';
  @override
  String get myCircleConnection => 'اتصال';
  @override
  String get myCircleConnections => 'اتصالات';
  @override
  String get messageRequestsTitle => 'طلبات الرسائل';
  @override
  String get messageRequestsNone => 'لا توجد طلبات رسائل';
  @override
  String get messageRequestsNoneDesc => 'عندما يرسل إليك أشخاص ليسوا في قائمة متابعيك رسائل، ستظهر هنا أولاً.';
  @override
  String get messageRequestsNoNotify => 'لن تحصل على إشعارات حول هذه الرسائل.';
  @override
  String get messageRequestsSentMessage => 'أرسل لك رسالة';
  @override
  String get messageRequestsUser => 'مستخدم';
  @override
  String get messageRequestsKeep => 'احتفظ';
  @override
  String get messageRequestsDecline => 'رفض';
  @override
  String get messageRequestsDeclineConfirm => 'رفض الطلب؟';
  @override
  String get messageRequestsDeclined => 'تم رفض الطلب';
  @override
  String get messageRequestsAcceptFailed => 'فشل قبول الطلب';
  @override
  String get messageRequestsDeclineFailed => 'فشل رفض الطلب';
  @override
  String get settingsTitle => 'الإعدادات';
  @override
  String get settingsAccount => 'الحساب';
  @override
  String settingsEmail({required String email}) => 'البريد الإلكتروني: $email';
  @override
  String settingsPhone({required String phone}) => 'الهاتف: $phone';
  @override
  String get settingsNotSetValue => 'غير محدد';
  @override
  String get settingsUpdateEmail => 'تحديث البريد الإلكتروني';
  @override
  String get settingsUpdatePhone => 'تحديث رقم الهاتف';
  @override
  String get settingsEnterEmail => 'أدخل عنوان بريدك الإلكتروني الجديد';
  @override
  String get settingsEnterPhone => 'أدخل رقم هاتفك';
  @override
  String get settingsValidEmail => 'يرجى إدخال بريد إلكتروني صحيح';
  @override
  String get settingsValidPhone => 'يرجى إدخال رقم هاتف';
  @override
  String get settingsSaveEmail => 'حفظ البريد الإلكتروني';
  @override
  String get settingsSavePhone => 'حفظ رقم الهاتف';
  @override
  String get settingsEmailUpdated => 'تم تحديث البريد الإلكتروني!';
  @override
  String get settingsPhoneUpdated => 'تم تحديث رقم الهاتف!';
  @override
  String get settingsPreferences => 'التفضيلات';
  @override
  String get settingsFeedPreference => 'تفضيل الخط الزمني';
  @override
  String settingsFeedPreferenceValue({required String value}) => 'تفضيل الخط الزمني: $value';
  @override
  String get settingsFeedDesc => 'اختر كيفية تنظيم خط زمنيك';
  @override
  String get settingsFeedNearby => 'المحلي أولاً';
  @override
  String get settingsFeedTrending => 'الشهير';
  @override
  String get settingsFeedMixed => 'مختلط';
  @override
  String get settingsFeedMixedDesc => 'مزيج من المنشورات المحلية والشهيرة';
  @override
  String get settingsFeedNearbyDesc => 'أعطِ الأولوية للمنشورات من الأشخاص بالقرب منك';
  @override
  String get settingsFeedTrendingDesc => 'اعرض المنشورات الشهيرة أولاً';
  @override
  String get settingsProfileVisibility => 'رؤية الملف الشخصي';
  @override
  String settingsProfileVisibilityValue({required String value}) => 'رؤية الملف الشخصي: $value';
  @override
  String get settingsProfileVisibilityDesc => 'من يمكنه رؤية ملفك الشخصي';
  @override
  String get settingsPublic => 'عام';
  @override
  String get settingsPublicDesc => 'يمكن للجميع رؤية ملفك الشخصي';
  @override
  String get settingsPrivate => 'خاص';
  @override
  String get settingsPrivateDesc => 'يمكنك فقط رؤية تفاصيل ملفك الشخصي';
  @override
  String get settingsFollowersOnly => 'المتابعون فقط';
  @override
  String get settingsFollowersOnlyDesc => 'يمكن لمتابعيك فقط رؤية ملفك الشخصي الكامل';
  @override
  String get settingsActivityFriends => 'النشاط في تبويب الأصدقاء';
  @override
  String get settingsActivityFriendsDesc => 'التحكم في رؤية نشاطك';
  @override
  String get settingsShowNewFollows => 'عرض المتابعات الجديدة';
  @override
  String get settingsShowNewFollowsDesc => 'يمكن للأصدقاء رؤية من تتابعه';
  @override
  String get settingsShowComments => 'عرض التعليقات';
  @override
  String get settingsShowCommentsDesc => 'يمكن للأصدقاء رؤية تعليقاتك';
  @override
  String get settingsShowLikedPosts => 'عرض المنشورات المعجب بها';
  @override
  String get settingsShowLikedPostsDesc => 'يمكن للأصدقاء رؤية المنشورات التي أعجبت بها';
  @override
  String get settingsShowOnline => 'عرض حالة الاتصال';
  @override
  String get settingsOnlineVisible => 'الحالة على الإنترنت مرئية. يمكن للآخرين رؤية متى تكون نشطاً.';
  @override
  String get settingsOnlineHidden => 'الحالة على الإنترنت مخفية. ستظهر بحالة عدم الاتصال للجميع.';
  @override
  String get settingsShowBirthday => 'عرض تاريخ الميلاد على الملف الشخصي';
  @override
  String get settingsVisibilityPublic => 'تم تعيين الرؤية إلى عام';
  @override
  String get settingsVisibilityPrivate => 'تم تعيين الرؤية إلى خاص';
  @override
  String get settingsVisibilityFollowers => 'تم تعيين الرؤية إلى المتابعون فقط';
  @override
  String get settingsStoryLiveLocation => 'القصة والبث المباشر والموقع';
  @override
  String get settingsStoryLiveLocationDesc => 'التحكم في من يرى قصصك وموقعك';
  @override
  String get settingsAllowStoryReplies => 'السماح برد على القصص';
  @override
  String get settingsAllowStoryRepliesDesc => 'يمكن للجميع الرد على قصصك';
  @override
  String get settingsShowLocationStories => 'عرض الموقع في القصص';
  @override
  String get settingsShowLocationStoriesDesc => 'مدينتك مرئية على قصصك';
  @override
  String get settingsLiveNotifications => 'إشعارات البث المباشر';
  @override
  String get settingsLiveNotificationsDesc => 'احصل على إشعار عندما يذهب الأصدقاء مباشراً';
  @override
  String get settingsLocation => 'الموقع';
  @override
  String settingsRadius({required String radius}) => 'النطاق: $radiusكم (قابل للتعديل في اكتشف)';
  @override
  String get settingsLocationUpdated => 'تم تحديث الموقع!';
  @override
  String get settingsLocationError => 'تعذر الحصول على الموقع. تحقق من GPS والأذونات.';
  @override
  String settingsLocationErrorDetail({required String error}) => 'خطأ في الموقع: $error';
  @override
  String get settingsNotifications => 'الإشعارات';
  @override
  String get settingsNotificationsEnabled => 'الإشعارات مفعلة';
  @override
  String get settingsNotificationsDisabled => 'الإشعارات معطلة';
  @override
  String get settingsTheme => 'المظهر';
  @override
  String settingsThemeValue({required String name}) => 'المظهر: $name';
  @override
  String get settingsChooseTheme => 'اختر المظهر';
  @override
  String get settingsApp => 'التطبيق';
  @override
  String get settingsHelpImprove => 'ساعدنا في تحسين Nearfo';
  @override
  String get settingsReportBug => 'الإبلاغ عن خلل';
  @override
  String get settingsReportBugHint => 'صف الخلل الذي وجدته...';
  @override
  String get settingsSubmitReport => 'إرسال التقرير';
  @override
  String get settingsBugReportSubmitted => 'تم إرسال التقرير! شكراً لك.';
  @override
  String get settingsCouldNotOpenLink => 'تعذر فتح الرابط';
  @override
  String get settingsPrivacyPolicy => 'سياسة الخصوصية';
  @override
  String get settingsTermsOfService => 'شروط الخدمة';
  @override
  String get settingsAbout => 'عن Nearfo';
  @override
  String get settingsVersion => 'Nearfo v1.0.0';
  @override
  String get settingsAccountPrivacy => 'خصوصية الحساب';
  @override
  String get settingsAccountPrivacyDesc => 'خصوصية الحساب';
  @override
  String get settingsBlocked => 'محظور';
  @override
  String get settingsBlockedUsers => 'المستخدمون المحظورون';
  @override
  String get settingsHideFollowersList => 'إخفاء قائمة المتابعين/المتابَع';
  @override
  String get settingsFollowersVisible => 'قائمة المتابعين/المتابَع مرئية للجميع.';
  @override
  String get settingsFollowersHidden => 'قائمة المتابعين/المتابَع مخفية. سيظهر الرقم فقط.';
  @override
  String get settingsAdmin => 'الإدارة';
  @override
  String get settingsModeration => 'الإشراف (الحظر/DMCA)';
  @override
  String get settingsMonetization => 'تحقيق الربح';
  @override
  String get settingsCopyrightReport => 'الإبلاغ عن انتهاك حقوق النشر';
  @override
  String get settingsDeleteAccount => 'حذف الحساب';
  @override
  String get settingsDeleteAccountConfirm => 'هل أنت متأكد؟ سيؤدي هذا إلى حذف حسابك والمنشورات وجميع البيانات بشكل دائم. لا يمكن التراجع عن هذا الإجراء.';
  @override
  String get settingsDeleteAccountSent => 'تم إرسال طلب حذف الحساب. سنعالجه في غضون 24 ساعة.';
  @override
  String get settingsFailedOnlineStatus => 'فشل تحديث حالة الاتصال';
  @override
  String get settingsFeedSetMixed => 'تم تعيين الخط الزمني إلى مختلط';
  @override
  String get settingsFeedSetNearby => 'تم تعيين الخط الزمني إلى المحلي أولاً';
  @override
  String get settingsFeedSetTrending => 'تم تعيين الخط الزمني إلى الشهير';
  @override
  String get accountPrivacyTitle => 'خصوصية الحساب';
  @override
  String get accountPrivacyPublicSet => 'تم تعيين الحساب إلى عام';
  @override
  String get accountPrivacyPrivateSet => 'تم تعيين الحساب إلى خاص';
  @override
  String get accountPrivacyPublicTitle => 'حساب عام';
  @override
  String get accountPrivacyPrivateTitle => 'حساب خاص';
  @override
  String get accountPrivacyPublicShort => 'يمكن للجميع رؤية منشوراتك وملفك الشخصي';
  @override
  String get accountPrivacyPublicDesc => 'يمكن للجميع رؤية منشوراتك وقصصك وملفك الشخصي. يمكن للأشخاص متابعتك دون موافقة.';
  @override
  String get accountPrivacyPrivateShort => 'فقط المتابعون المعتمدون يمكنهم رؤية منشوراتك';
  @override
  String get accountPrivacyPrivateDesc => 'فقط المتابعون الذين تعتمدهم يمكنهم رؤية منشوراتك وقصصك. معلومات ملفك الشخصي مخفية عن المتابعين الآخرين.';
  @override
  String get accountPrivacyWhenPublic => 'عندما يكون حسابك عاماً';
  @override
  String get accountPrivacyWhenPrivate => 'عندما يكون حسابك خاصاً';
  @override
  String get accountPrivacySwitchNote => 'تبديل إلى خاص لن يؤثر على المتابعين الحاليين.';
  @override
  String get accountPrivacyNote => 'ملاحظة';
  @override
  String get premiumTitle => 'اذهب Premium';
  @override
  String get premiumSubtitle => 'Nearfo Premium';
  @override
  String get premiumDesc => 'فتح تجربة Nearfo الكاملة';
  @override
  String get premiumChoosePlan => 'اختر خطتك';
  @override
  String get premiumChoosePlanBtn => 'اختر الخطة';
  @override
  String get premiumMonthly => 'شهري';
  @override
  String get premiumYearly => 'سنوي';
  @override
  String get premiumLifetime => 'مدى الحياة';
  @override
  String get premiumPopular => 'الشهير';
  @override
  String get premiumVerifiedBadge => 'شارة التحقق';
  @override
  String get premiumVerifiedBadgeDesc => 'برز بملف شخصي موثق';
  @override
  String get premiumAdFree => 'تجربة خالية من الإعلانات';
  @override
  String get premiumAdFreeDesc => 'تصفح بدون انقطاعات';
  @override
  String get premiumPriorityFeed => 'خط زمني ذو أولوية';
  @override
  String get premiumPriorityFeedDesc => 'يتم تعزيز منشوراتك محلياً';
  @override
  String get premiumCustomThemes => 'مظاهر مخصصة';
  @override
  String get premiumCustomThemesDesc => 'شخصّن مظهر ملفك الشخصي';
  @override
  String get premiumUnlockChatTheme => 'فتح مظهر دردشة مخصص';
  @override
  String get premiumAdvancedAnalytics => 'تحليلات متقدمة';
  @override
  String get premiumAdvancedAnalyticsDesc => 'رؤى عميقة في نطاق وصولك';
  @override
  String get premiumPrioritySupport => 'دعم ذو أولوية';
  @override
  String get premiumPrioritySupportDesc => 'احصل على مساعدة أسرع عند الحاجة';
  @override
  String get premiumSeeProfileViews => 'رؤية من شاهد ملفك الشخصي';
  @override
  String get premiumEverythingMonthly => 'كل شيء في الشهري';
  @override
  String get premiumEverythingForever => 'كل شيء للأبد';
  @override
  String get premiumFoundingBadge => 'شارة العضو المؤسس';
  @override
  String get premiumEarlyAccess => 'الوصول المبكر إلى الميزات';
  @override
  String get premiumGetStarted => 'ابدأ الآن';
  @override
  String premiumRewardUnlocked({required String label}) => 'تم فتح المكافأة! $label';
  @override
  String get premiumWatchAdsDesc => 'احصل على ميزات premium مجانية بمشاهدة إعلانات قصيرة';
  @override
  String get premiumWatchAdsTitle => 'شاهد الإعلانات، احصل على مكافآت!';
  @override
  String get premiumWatchAdToUnlock => 'شاهد إعلاناً لفتح';
  @override
  String get premiumWatchAdToBoost => 'شاهد إعلاناً للتعزيز';
  @override
  String get premiumBoostPost => 'عزز منشورك لمدة ساعة';
  @override
  String get premiumSaveYearly => 'وفّر ₹389!';
  @override
  String get premiumPaymentComingSoon => 'دمج الدفع قريباً. شاهد الإعلانات لفتح الميزات الآن!';
  @override
  String get premiumAdLoading => 'جاري تحميل الإعلان، يرجى المحاولة مجدداً خلال لحظة...';
  @override
  String get premiumPriceMonthly => '₹99';
  @override
  String get premiumPriceYearly => '₹799';
  @override
  String get premiumPriceLifetime => '₹1,999';
  @override
  String get premiumPerMonth => '/شهر';
  @override
  String get premiumPerYear => '/سنة';
  @override
  String get premiumOneTime => 'مرة واحدة';
  @override
  String get analyticsTitle => 'التحليلات';
  @override
  String get analyticsOverview => 'نظرة عامة';
  @override
  String get analyticsPosts => 'المنشورات';
  @override
  String get analyticsReels => 'الفيديوهات';
  @override
  String get analyticsThisWeek => 'هذا الأسبوع';
  @override
  String get analyticsPostsCreated => 'منشورات تم إنشاؤها';
  @override
  String get analyticsReelsUploaded => 'فيديوهات تم رفعها';
  @override
  String get analyticsTotalLikes => 'إجمالي الإعجابات';
  @override
  String get analyticsComments => 'التعليقات';
  @override
  String get analyticsEngagement => 'التفاعل';
  @override
  String get analyticsFollowers => 'المتابعون';
  @override
  String get analyticsFollowing => 'المتابَع';
  @override
  String get analyticsNewFollowers => 'متابعون جدد';
  @override
  String get analyticsReelViews => 'عدد مشاهدات الفيديو';
  @override
  String get analyticsLegend => 'المفتاح';
  @override
  String get analyticsNewcomer => 'الجديد';
  @override
  String get analyticsRising => 'الصاعد';
  @override
  String get analyticsStar => 'النجم';
  @override
  String get analyticsActive => 'نشط';
  @override
  String get analyticsCouldNotLoad => 'تعذر تحميل التحليلات';
  @override
  String get analyticsTipToGrow => 'نصيحة للنمو';
  @override
  String get analyticsGreatStart => 'لديك بداية رائعة!';
  @override
  String get analyticsNewcomerTip => 'بداية رائعة! جرّب نشر فيديوهات — تحصل على المزيد من المشاهدات وتساعد في زيادة التفاعل.';
  @override
  String get analyticsAlmostThere => 'أنت قريب جداً! محتواك يؤدي بشكل جيد. استمر بنفس الزخم!';
  @override
  String get analyticsKeepPosting => 'استمر بالنشر والتفاعل مع مجتمعك لزيادة نقاطك!';
  @override
  String get analyticsRisingCreator => 'أنت مبدع صاعد!';
  @override
  String get nearfoScoreTitle => 'نقاط Nearfo';
  @override
  String get nearfoScoreDesc => 'درجة تأثيرك المحلي والتفاعل';
  @override
  String get nearfoScoreOutOf => '/100';
  @override
  String get nearfoScoreBreakdown => 'تفصيل الدرجة';
  @override
  String get nearfoScoreTipToImprove => 'نصيحة للتحسين';
  @override
  String get nearfoScoreActivity => 'النشاط';
  @override
  String get nearfoScoreActivityTip => 'كن نشطاً يومياً — ارق واعلّق على المنشورات وشاركها لزيادة درجة نشاطك.';
  @override
  String get nearfoScorePosts => 'المنشورات';
  @override
  String get nearfoScoreReels => 'الفيديوهات';
  @override
  String get nearfoScoreFollowers => 'المتابعون';
  @override
  String get nearfoScoreEngagement => 'التفاعل';
  @override
  String get nearfoScoreFollowersTip => 'تابع الأشخاص في منطقتك وتفاعل مع محتواهم — سيتابعونك بالمقابل!';
  @override
  String get nearfoScorePostsTip => 'جرّب النشر بتكرار أكثر! شارك الصور والأفكار والتحديثات مع مجتمعك المحلي.';
  @override
  String get nearfoScoreReelsTip => 'أنشئ فيديوهات قصيرة لزيادة ظهورك والوصول لمزيد من الأشخاص بالقرب منك.';
  @override
  String get nearfoScoreEngagementTip => 'اكتب تسميات توضيحية جذابة وادرد على التعليقات لتعزيز معدل التفاعل.';
  @override
  String get nearfoScoreWelcome => 'مرحباً! ابدأ بالنشر للنمو';
  @override
  String get nearfoScoreGettingStarted => 'جاري البدء! انشر المزيد';
  @override
  String get nearfoScoreGoodStart => 'بداية جيدة! استمر بالتفاعل';
  @override
  String get nearfoScoreGreat => 'رائع! أنت تبني زخماً';
  @override
  String get nearfoScoreExcellent => 'ممتاز! أنت مؤثر محلي';
  @override
  String get blockedUsersTitle => 'المستخدمون المحظورون';
  @override
  String get blockedUsersNone => 'لا يوجد مستخدمون محظورون';
  @override
  String get blockedUsersNoneDesc => 'سيظهر هنا المستخدمون الذين تحظرهم';
  @override
  String blockedUsersUnblocked({required String name}) => 'تم إلغاء حظر $name';
  @override
  String get blockedUsersUnblockTitle => 'إلغاء حظر المستخدم';
  @override
  String blockedUsersUnblockConfirm({required String name}) => 'هل أنت متأكد من رغبتك في إلغاء حظر $name؟ سيكونون قادرين على رؤية ملفك الشخصي والتفاعل معك مجدداً.';
  @override
  String get createGroupTitle => 'إنشاء مجموعة';
  @override
  String get createGroupNameHint => 'اسم المجموعة';
  @override
  String get createGroupNameRequired => 'اسم المجموعة مطلوب';
  @override
  String get createGroupDescHint => 'الوصف (اختياري)';
  @override
  String get createGroupSearchHint => 'ابحث عن أشخاص لإضافتهم...';
  @override
  String get createGroupMinMembers => 'اختر 2 أعضاء على الأقل';
  @override
  String get createGroupFailed => 'فشل';
  @override
  String get groupInfoEditGroup => 'تعديل المجموعة';
  @override
  String get groupInfoMembers => 'الأعضاء';
  @override
  String groupInfoMemberCount({required String count}) => '$count أعضاء';
  @override
  String get groupInfoAddMembers => 'إضافة أعضاء';
  @override
  String get groupInfoAdd => 'إضافة';
  @override
  String get groupInfoSearchHint => 'ابحث عن أشخاص...';
  @override
  String get groupInfoAdmin => 'إدارة';
  @override
  String get groupInfoViewProfile => 'عرض الملف الشخصي';
  @override
  String get groupInfoRemoveFromGroup => 'إزالة من المجموعة';
  @override
  String groupInfoMemberRemoved({required String name}) => 'تم إزالة $name';
  @override
  String groupInfoRemoveConfirm({required String name}) => 'إزالة $name؟';
  @override
  String get groupInfoRemoveDesc => 'لن يكونوا قادرين على إرسال أو استقبال رسائل في هذه المجموعة.';
  @override
  String get groupInfoMuteToggled => 'تم تبديل كتم الصوت';
  @override
  String get groupInfoLeaveGroup => 'مغادرة المجموعة';
  @override
  String get groupInfoLeaveConfirm => 'مغادرة المجموعة؟';
  @override
  String get groupInfoLeaveDesc => 'لن تستقبل رسائل من هذه المجموعة. لا يمكن التراجع عن هذا الإجراء.';
  @override
  String get groupInfoLeaveShort => 'لن تستقبل رسائل';
  @override
  String get groupInfoLeave => 'مغادرة';
  @override
  String get groupInfoLeaveFailed => 'فشل مغادرة المجموعة';
  @override
  String groupInfoUserAdded({required String name}) => 'تم إضافة $name';
  @override
  String groupInfoYou({required String name}) => '$name (أنت)';
  @override
  String get copyrightTitle => 'الإبلاغ عن حقوق النشر';
  @override
  String get copyrightDesc => 'إذا قام شخص بنشر محتواك محمي بحقوق النشر دون إذن، أكمل هذا النموذج لطلب إزالته.';
  @override
  String get copyrightYourName => 'اسمك';
  @override
  String get copyrightNameHint => 'أدخل اسمك الكامل';
  @override
  String get copyrightYourEmail => 'بريدك الإلكتروني';
  @override
  String get copyrightEmailHint => 'أدخل بريدك الإلكتروني';
  @override
  String get copyrightContentType => 'نوع المحتوى';
  @override
  String get copyrightTypePost => 'منشور';
  @override
  String get copyrightTypeReel => 'فيديو';
  @override
  String get copyrightTypeStory => 'قصة';
  @override
  String get copyrightTypeComment => 'تعليق';
  @override
  String get copyrightContentId => 'معرف المحتوى';
  @override
  String get copyrightContentIdHint => 'معرف المنشور/الفيديو المخالف';
  @override
  String get copyrightDescription => 'الوصف';
  @override
  String get copyrightDescHint => 'اشرح كيف تم انتهاك حقوق النشر الخاصة بك';
  @override
  String get copyrightOriginalUrl => 'عنوان العمل الأصلي';
  @override
  String get copyrightOriginalUrlHint => 'رابط عملك الأصلي (اختياري)';
  @override
  String get copyrightSwornStatement => 'أقسم، تحت طائلة العقوبات المترتبة على الكذب، أن المعلومات الواردة في هذا الإشعار دقيقة وأنني أملك حقوق النشر أو أن لديّ الترخيص للتصرف نيابة عنهم.';
  @override
  String get copyrightMustConfirm => 'يجب عليك تأكيد الإقرار الموثق';
  @override
  String get copyrightSubmit => 'تقديم تقرير DMCA';
  @override
  String get copyrightRequired => 'مطلوب';
  @override
  String get copyrightSubmitted => 'تم تقديم تقرير DMCA. سنراجعه في غضون 48 ساعة.';
  @override
  String get copyrightFailed => 'فشل التقديم';
  @override
  String get moderationTitle => 'الإشراف';
  @override
  String moderationTakedowns({required String count}) => 'الإزالات ($count)';
  @override
  String moderationBanned({required String count}) => 'محظور ($count)';
  @override
  String get moderationNoPendingTakedowns => 'لا توجد إزالات معلقة';
  @override
  String get moderationNoBannedUsers => 'لا مستخدمون محظورون';
  @override
  String get moderationReason => 'السبب';
  @override
  String moderationType({required String type}) => 'النوع: $type';
  @override
  String get moderationDuration => 'المدة';
  @override
  String get moderationDuration24h => '24 ساعة';
  @override
  String get moderationDuration3d => '3 أيام';
  @override
  String get moderationDuration7d => '7 أيام';
  @override
  String get moderationDuration30d => '30 يوماً';
  @override
  String get moderationSuspend => 'تعليق';
  @override
  String get moderationSuspendUser => 'تعليق المستخدم';
  @override
  String get moderationBan => 'حظر';
  @override
  String get moderationBanUser => 'حظر المستخدم';
  @override
  String get moderationReject => 'رفض';
  @override
  String get moderationUnban => 'إلغاء الحظر';
  @override
  String get moderationTakedownApproved => 'تم الموافقة على الإزالة. تم حذف المحتوى.';
  @override
  String get moderationTakedownRejected => 'تم رفض الإزالة';
  @override
  String get moderationUserBanned => 'تم حظر المستخدم';
  @override
  String get moderationUserSuspended => 'تم تعليق المستخدم';
  @override
  String get moderationUserUnbanned => 'تم إلغاء حظر المستخدم';
  @override
  String get moderationUnknown => 'غير معروف';
  @override
  String get moderationUserId => 'معرف المستخدم';
  @override
  String get adminTitle => 'لوحة الإدارة';
  @override
  String get adminDashboard => 'لوحة التحكم';
  @override
  String get adminTotalUsers => 'إجمالي المستخدمين';
  @override
  String get adminPostsToday => 'المنشورات اليوم';
  @override
  String get adminReelsToday => 'الفيديوهات اليوم';
  @override
  String get adminOnlineUsers => 'المستخدمون النشطون';
  @override
  String get adminPendingReports => 'التقارير المعلقة';
  @override
  String get adminReports => 'التقارير';
  @override
  String get adminActiveStories => 'القصص النشطة';
  @override
  String get adminAiAgents => 'عملاء AI';
  @override
  String get adminSearchUsers => 'ابحث عن مستخدمين بالاسم أو البريد الإلكتروني...';
  @override
  String get adminUsers => 'المستخدمون';
  @override
  String get adminVerified => 'موثق';
  @override
  String get adminUnverified => 'غير موثق';
  @override
  String get adminVerify => 'التحقق';
  @override
  String get adminUnverify => 'إلغاء التحقق';
  @override
  String adminReportFrom({required String name}) => 'تقرير من $name';
  @override
  String get adminNoReason => 'لم يتم توفير سبب';
  @override
  String get adminDismiss => 'رفض';
  @override
  String get adminReportDismissed => 'تم رفض التقرير';
  @override
  String get adminTakeAction => 'اتخاذ إجراء';
  @override
  String get adminContentType => 'نوع المحتوى';
  @override
  String get adminContentHidden => 'تم إخفاء المحتوى بنجاح';
  @override
  String get adminNoDescription => 'لا وصف';
  @override
  String get adminNoPendingReports => 'لا توجد تقارير معلقة';
  @override
  String adminErrorLoadingReports({required String error}) => 'خطأ في تحميل التقارير: $error';
  @override
  String adminErrorLoadingDashboard({required String error}) => 'خطأ في تحميل لوحة التحكم: $error';
  @override
  String adminErrorLoadingUsers({required String error}) => 'خطأ في تحميل المستخدمين: $error';
  @override
  String adminErrorTakingAction({required String error}) => 'خطأ في اتخاذ إجراء: $error';
  @override
  String adminErrorDismissing({required String error}) => 'خطأ في رفض التقرير: $error';
  @override
  String adminErrorUpdatingUser({required String error}) => 'خطأ في تحديث المستخدم: $error';
  @override
  String get adminNoData => 'لا بيانات متاحة';
  @override
  String get adminNoEmail => 'لا بريد إلكتروني';
  @override
  String get adminNoUsers => 'لم يتم العثور على مستخدمين';
  @override
  String get adminTotalMessages => 'إجمالي الرسائل';
  @override
  String get adminTotalFollows => 'إجمالي المتابعات';
  @override
  String get adminAnonymous => 'مجهول';
  @override
  String get bossAllAgents => 'جميع الوكلاء';
  @override
  String get bossQuickCommands => 'أوامر سريعة';
  @override
  String get bossOrders => 'الأوامر';
  @override
  String get bossFirstCommand => 'أعطِ أمرك الأول أعلاه!';
  @override
  String get bossNoOrders => 'لا توجد أوامر حتى الآن';
  @override
  String get bossOrderNotFound => 'الأمر غير موجود';
  @override
  String get bossOrderSent => 'تم إرسال الأمر! الوكلاء يعملون...';
  @override
  String get bossCommand => 'الأمر';
  @override
  String get bossAgent => 'الوكيل';
  @override
  String get bossProcessing => 'جاري المعالجة';
  @override
  String get bossCompleted => 'مكتمل';
  @override
  String get bossFailed => 'فشل';
  @override
  String get bossQueued => 'في قائمة الانتظار';
  @override
  String get bossAvgTime => 'متوسط الوقت';
  @override
  String get bossJustNow => 'للتو';
  @override
  String get bossDone => 'تم';
  @override
  String get bossAgentAura => 'Aura';
  @override
  String get bossAgentBlaze => 'Blaze';
  @override
  String get bossAgentBolt => 'Bolt';
  @override
  String get bossAgentCare => 'Care';
  @override
  String get bossAgentCrown => 'Crown';
  @override
  String get bossAgentHawk => 'Hawk';
  @override
  String get bossAgentJustice => 'Justice';
  @override
  String get bossAgentPhoenix => 'Phoenix';
  @override
  String get bossAgentPulse => 'Pulse';
  @override
  String get bossAgentSentinel => 'Sentinel';
  @override
  String get bossAgentShadow => 'Shadow';
  @override
  String get bossAgentShield => 'Shield';
  @override
  String get bossFullAudit => 'مراجعة شاملة';
  @override
  String get bossSecurityCheck => 'فحص الأمان';
  @override
  String get bossCompetitorAnalysis => 'تحليل المنافسين';
  @override
  String get bossGrowthIdeas => 'أفكار النمو';
  @override
  String get bossFindBugs => 'البحث عن الأخطاء';
  @override
  String get bossInvestorPrep => 'تحضير المستثمرين';
  @override
  String get bossSendEmailReport => 'إرسال تقرير عبر البريد';
  @override
  String get bossSelectAgent => 'اختر وكيلاً';
  @override
  String bossCommandInitiated({required String command}) => 'تم بدء $command!';
  @override
  String bossTokenCount({required String tokens}) => '$tokens رمز';
  @override
  String bossTotalTokens({required String total}) => '$total رموز';
  @override
  String get monetizationTitle => 'لوحة الأرباح';
  @override
  String commentsTitle({required String count}) => 'التعليقات ($count)';
  @override
  String get commentsNone => 'لا توجد تعليقات حتى الآن';
  @override
  String get commentsBeFirst => 'كن الأول في التعليق!';
  @override
  String get commentsAddHint => 'أضف تعليقاً...';
  @override
  String commentsReplyTo({required String name}) => 'رد على $name...';
  @override
  String commentsReplyingTo({required String name}) => 'ترد على $name';
  @override
  String get commentsReply => 'رد';
  @override
  String get commentsLike => 'إعجاب';
  @override
  String commentsViewReplies({required String count, required String label}) => 'عرض $count $label';
  @override
  String get commentsReplyLabel => 'رد';
  @override
  String get commentsRepliesLabel => 'ردود';
  @override
  String get commentsHideReplies => 'إخفاء الردود';
  @override
  String get postCardReportPost => 'الإبلاغ عن المنشور';
  @override
  String get postCardEditPost => 'تعديل المنشور';
  @override
  String get postCardDeletePost => 'حذف المنشور';
  @override
  String get postCardDeleteConfirm => 'حذف المنشور؟';
  @override
  String get postCardDeleteWarning => 'لا يمكن التراجع عن هذا الإجراء.';
  @override
  String get postCardSharePost => 'مشاركة المنشور';
  @override
  String get postCardShareToStory => 'مشاركة إلى القصة';
  @override
  String postCardFeeling({required String mood}) => 'الشعور $mood';
  @override
  String get postCardGlobal => 'عالمي';
  @override
  String get postCardVideoUnavailable => 'الفيديو غير متاح';
  @override
  String get postCardVideoFailed => 'فشل تحميل الفيديو';
  @override
  String get reportTitle => 'الإبلاغ عن المحتوى';
  @override
  String reportWhy({required String type}) => 'لماذا تُبلِغ عن هذا $type؟';
  @override
  String get reportFalseInfo => 'معلومات خاطئة';
  @override
  String get reportHarassment => 'التحرش أو المضايقة';
  @override
  String get reportHateSpeech => 'خطاب الكراهية';
  @override
  String get reportNudity => 'العري أو المحتوى الجنسي';
  @override
  String get reportSpam => 'البريد المزعج';
  @override
  String get reportScam => 'احتيال أو غش';
  @override
  String get reportViolence => 'العنف أو التهديدات';
  @override
  String get reportOther => 'آخر';
  @override
  String get reportDetailsHint => 'أضف التفاصيل (اختياري)...';
  @override
  String get reportSubmit => 'إرسال التقرير';
  @override
  String get reportSubmitted => 'تم تقديم التقرير. شكراً لك!';
  @override
  String get reportFailed => 'فشل التقرير';
  @override
  String get storyRowYourStory => 'قصتك';
  @override
  String get storyRowAddStory => 'أضف قصة';
  @override
  String get gifSearchHint => 'البحث عن صور متحركة';
  @override
  String get gifNoResults => 'لم يتم العثور على صور متحركة';
  @override
  String get gifPoweredBy => 'من تطوير GIPHY';
  @override
  String get unreadCount99Plus => '99+';
  @override
  String get incomingCallAudio => 'مكالمة صوتية واردة...';
  @override
  String get incomingCallVideo => 'مكالمة فيديو واردة...';
  @override
  String get highlightsNew => 'جديد';
  @override
  String get highlightsNewHighlight => 'تسليط ضوء جديد';
  @override
  String get highlightsNameHint => 'اسم التسليط';
  @override
  String get callMissed => 'مكالمة ضائعة';
  @override
  String get callBack => 'إعادة الاتصال';
  @override
  String pushNewMessages({required String count}) => '$count رسالة جديدة';
  @override
  String get pushTypeMessage => 'اكتب رسالة...';
  @override
  String get pushNearfoMessage => 'رسالة Nearfo';
  @override
  String get pushView => 'عرض';
  @override
  String get languageTitle => 'اللغة';
  @override
  String get languageSubtitle => 'اختر لغتك المفضلة';
  @override
  String get languageEnglish => 'English';
  @override
  String get languageHindi => 'हिन्दी (Hindi)';
  @override
  String languageChanged({required String language}) => 'تم تغيير اللغة إلى $language';
  @override
  String get digitalAvatarTitle => 'أفتار رقمي';
  @override
  String get digitalAvatarDesc => 'إنشاء أفتار فريد بأسلوب كرتون';
  @override
  String get callScreenConnecting => 'جاري الاتصال...';
  @override
  String get callScreenRinging => 'جاري الرنين...';
  @override
  String get callScreenReconnecting => 'جاري إعادة الاتصال...';
  @override
  String get callScreenCallEnded => 'انتهت المكالمة';
  @override
  String percentage({required String value}) => '$value%';
  @override
  String get settingsEditProfile => 'تعديل الملف الشخصي';
  @override
  String get settingsWhoCanSee => 'من يمكنه رؤية محتواك';
  @override
  String get settingsLanguage => 'اللغة';
  @override
  String get settingsSignOut => 'تسجيل الخروج';
  @override
  String get settingsEarningsDashboard => 'لوحة الأرباح';
  @override
  String get settingsAdminPanel => 'لوحة الإدارة';
  @override
  String get settingsPersonalizeExperience => 'خصص تجربة Nearfo الخاصة بك';
  @override
  String get settingsOnlineFailed => 'فشل تحديث حالة الاتصال';
}
