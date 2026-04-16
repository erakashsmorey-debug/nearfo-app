import 'app_localizations.dart';

class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([super.locale = 'ru']);

  @override
  String get appName => 'Nearfo';
  @override
  String get tagline => 'Знай свой круг';
  @override
  String get somethingWentWrong => 'Что-то пошло не так';
  @override
  String get signingIn => 'Вход в систему...';
  @override
  String get loading => 'Загрузка...';
  @override
  String get cancel => 'Отмена';
  @override
  String get save => 'Сохранить';
  @override
  String get delete => 'Удалить';
  @override
  String get create => 'Создать';
  @override
  String get done => 'Готово';
  @override
  String get retry => 'Повторить';
  @override
  String get ok => 'ОК';
  @override
  String get yes => 'Да';
  @override
  String get no => 'Нет';
  @override
  String get or => 'ИЛИ';
  @override
  String get search => 'Поиск';
  @override
  String get submit => 'Отправить';
  @override
  String get close => 'Закрыть';
  @override
  String get back => 'Назад';
  @override
  String get next => 'Далее';
  @override
  String get more => 'Ещё';
  @override
  String get remove => 'Удалить';
  @override
  String get block => 'Заблокировать';
  @override
  String get unblock => 'Разблокировать';
  @override
  String get mute => 'Отключить';
  @override
  String get unmute => 'Включить';
  @override
  String get report => 'Пожаловаться';
  @override
  String get share => 'Поделиться';
  @override
  String get edit => 'Редактировать';
  @override
  String get post => 'Опубликовать';
  @override
  String get follow => 'Следить';
  @override
  String get unfollow => 'Перестать следить';
  @override
  String get message => 'Сообщение';
  @override
  String get accept => 'Принять';
  @override
  String get decline => 'Отклонить';
  @override
  String get continue_ => 'Продолжить';
  @override
  String get stop => 'Остановить';
  @override
  String get use => 'Использовать';
  @override
  String get splashLogoLetter => 'N';
  @override
  String get splashAppName => 'nearfo';
  @override
  String get onboardingSkip => 'Пропустить';
  @override
  String get onboardingTitle1 => 'Локальная лента';
  @override
  String get onboardingDesc1 => '80% локального контента (100–500км с настраиваемым радиусом).
Узнавайте, что происходит рядом с вами.';
  @override
  String get onboardingTitle2 => 'Знай свой круг';
  @override
  String get onboardingDesc2 => 'Общайтесь с реальными людьми рядом.
Стройте свою местную сообщество.';
  @override
  String get onboardingTitle3 => 'Выходи в глобальное';
  @override
  String get onboardingDesc3 => '20% трендового контента со всего мира.
Оставайтесь в контакте с миром.';
  @override
  String get onboardingGetStarted => 'Начать';
  @override
  String get loginWelcome => 'Добро пожаловать в Nearfo';
  @override
  String get loginSubtitle => 'Войдите, чтобы общаться с людьми рядом с вами.';
  @override
  String get loginContinueWithGoogle => 'Продолжить с Google';
  @override
  String get loginContinueWithPhone => 'Продолжить по телефону';
  @override
  String get loginEnterMobile => 'Введите номер телефона';
  @override
  String get loginSendOtp => 'Отправить OTP';
  @override
  String get loginTermsAgreement => 'Продолжая, вы соглашаетесь с нашими Условиями использования и Политикой конфиденциальности';
  @override
  String get loginTermsOfService => 'Условия использования';
  @override
  String get loginPrivacyPolicy => 'Политика конфиденциальности';
  @override
  String get loginInvalidPhone => 'Введите корректный 10-значный номер телефона';
  @override
  String get otpTitle => 'Проверьте OTP';
  @override
  String otpSubtitle({required String phone}) => 'Введите 6-значный код, отправленный по SMS на номер $phone';
  @override
  String get otpVerify => 'Проверить';
  @override
  String get otpIncomplete => 'Введите полный 6-значный OTP';
  @override
  String get otpResent => 'OTP отправлен повторно!';
  @override
  String get otpResend => 'Отправить OTP ещё раз';
  @override
  String get otpPhoneMissing => 'Номер телефона отсутствует. Вернитесь и попробуйте ещё раз.';
  @override
  String otpDevCode({required String otp}) => 'Dev OTP: $otp';
  @override
  String get permissionsTitle => 'Включите разрешения';
  @override
  String get permissionsSubtitle => 'Nearfo нужны несколько разрешений для лучшего опыта с функциями на основе местоположения, уведомлениями и совместным использованием медиа.';
  @override
  String get permissionLocation => 'Местоположение';
  @override
  String get permissionLocationDesc => 'Найдите людей и посты рядом с вами';
  @override
  String get permissionNotifications => 'Уведомления';
  @override
  String get permissionNotificationsDesc => 'Получайте оповещения о лайках, комментариях и сообщениях';
  @override
  String get permissionCamera => 'Камера';
  @override
  String get permissionCameraDesc => 'Фотографируйте для постов и профиля';
  @override
  String get permissionPhotos => 'Фото и медиа';
  @override
  String get permissionPhotosDesc => 'Делитесь фото и видео в постах';
  @override
  String get permissionsAllowAll => 'Разрешить все разрешения';
  @override
  String get permissionsRequestingLocation => 'Запрос доступа к местоположению...';
  @override
  String get permissionsRequestingNotifications => 'Запрос разрешения на уведомления...';
  @override
  String get permissionsRequestingCamera => 'Запрос доступа к камере...';
  @override
  String get permissionsRequestingMedia => 'Запрос доступа к медиа...';
  @override
  String get permissionsAllDone => 'Всё готово!';
  @override
  String get permissionsSettingUp => 'Настройка...';
  @override
  String get permissionsSkip => 'Пропустить пока';
  @override
  String get setupTitle => 'Определите свой стиль';
  @override
  String get setupSubtitle => 'Расскажите о себе. Это поможет людям рядом найти вас.';
  @override
  String get setupFullName => 'Полное имя';
  @override
  String get setupEnterName => 'Введите своё имя';
  @override
  String get setupUsername => 'Имя пользователя';
  @override
  String get setupUsernamePlaceholder => 'ваше_имя';
  @override
  String get setupUsernamePrefix => '@';
  @override
  String get setupBio => 'О себе (опционально)';
  @override
  String get setupBioPlaceholder => 'Какой твой стиль?';
  @override
  String get setupDob => 'Дата рождения';
  @override
  String get setupDobPlaceholder => 'Выберите дату рождения';
  @override
  String get setupShowBirthday => 'Показать дату рождения в профиле';
  @override
  String get setupLocation => 'Местоположение';
  @override
  String get setupGettingLocation => 'Определение местоположения...';
  @override
  String get setupTapToEnable => 'Нажмите, чтобы включить местоположение';
  @override
  String get setupEnable => 'Включить';
  @override
  String get setupLocationNote => 'Ваше местоположение активирует гиперлокальную ленту (100–500км с регулировкой). Оно никогда не будет опубликовано публично.';
  @override
  String get setupStartVibing => 'Начать вибировать';
  @override
  String get setupNameRequired => 'Имя требуется';
  @override
  String get setupHandleMinLength => 'Имя пользователя должно быть не менее 3 символов';
  @override
  String get setupLocationRequired => 'Пожалуйста, разрешите доступ к местоположению';
  @override
  String get navHome => 'Дом';
  @override
  String get navDiscover => 'Открыть';
  @override
  String get navReels => 'Видео';
  @override
  String get navChat => 'Чат';
  @override
  String get navProfile => 'Профиль';
  @override
  String get homeAppName => 'Nearfo';
  @override
  String get homeFollowing => 'Подписки';
  @override
  String get homeLocal => 'Локально';
  @override
  String get homeGlobal => 'Глобально';
  @override
  String get homeMixed => 'Смешанное';
  @override
  String homeRadiusActive({required String radius}) => 'Активен радиус $radiusкм';
  @override
  String get homeLive => 'Прямой эфир';
  @override
  String get homeNoVibes => 'Пока нет постов!';
  @override
  String get homeBeFirst => 'Будьте первым, кто опубликует пост в вашем районе';
  @override
  String get homeEditPost => 'Редактировать пост';
  @override
  String get homeEditPostHint => 'Редактируйте ваш пост...';
  @override
  String get homePostDeleted => 'Пост удален';
  @override
  String get homeDeleteFailed => 'Не удалось удалить пост';
  @override
  String get homeSharedToStory => 'Поделено в историю!';
  @override
  String get composeTitle => 'Новый пост';
  @override
  String get composeHint => 'Какой у вас сегодня стиль?';
  @override
  String get composePhoto => 'Фото';
  @override
  String composePhotoCount({required String count}) => 'Фото ($count)';
  @override
  String get composeVideo => 'Видео';
  @override
  String get composeLocation => 'Местоположение';
  @override
  String get composeMood => 'Настроение';
  @override
  String get composeMoodHappy => 'Весело';
  @override
  String get composeMoodCool => 'Круто';
  @override
  String get composeMoodFire => 'Огонь';
  @override
  String get composeMoodSleepy => 'Сонный';
  @override
  String get composeMoodThinking => 'Думаю';
  @override
  String get composeMoodAngry => 'Злой';
  @override
  String get composeMoodParty => 'Вечеринка';
  @override
  String get composeMoodLove => 'Любовь';
  @override
  String get composeWriteSomething => 'Напишите что-нибудь или добавьте фото/видео!';
  @override
  String get composeRemovePhotosFirst => 'Сначала удалите фото, чтобы добавить видео';
  @override
  String get composeRemoveVideoFirst => 'Сначала удалите видео, чтобы добавить фото';
  @override
  String get composeVideoTooLarge => 'Видео слишком большое. Пожалуйста, выберите более короткое видео.';
  @override
  String get composeOptimizingVideo => 'Оптимизация видео';
  @override
  String get composeConvertingTo720p => 'Преобразование в 720p для лучшего качества';
  @override
  String composeVideoOptimized({required String mb}) => 'Видео оптимизировано! Сохранено $mbМБ';
  @override
  String composeVideoStillLarge({required String mb}) => 'Видео всё ещё $mbМБ после сжатия. Макс 75МБ. Попробуйте более короткое видео.';
  @override
  String get composeVideoTimeout => 'Время загрузки видео истекло. Попробуйте более короткое видео или проверьте соединение.';
  @override
  String get composeImageUploadFailed => 'Не удалось загрузить изображение';
  @override
  String get composeUploadTimeout => 'Время загрузки истекло. Проверьте соединение и попробуйте ещё раз.';
  @override
  String get composePosted => 'Опубликовано!';
  @override
  String composeVideoPreviewError({required String error}) => 'Не удалось загрузить предпросмотр видео: $error';
  @override
  String get discoverTitle => 'Открыть';
  @override
  String get discoverSearchHint => 'Найдите друзей по имени или @ручке...';
  @override
  String get discoverTabViral => 'Вирусное';
  @override
  String get discoverTabGlobal => 'Глобальное';
  @override
  String get discoverTabSuggested => 'Рекомендуется';
  @override
  String get discoverTabMap => 'Карта';
  @override
  String get discoverTabTrending => 'Тренды';
  @override
  String get discoverTabPeople => 'Люди';
  @override
  String get discoverViralNow => 'Вирусное сейчас';
  @override
  String get discoverOneHour => '1 час';
  @override
  String get discoverSixHours => '6 часов';
  @override
  String get discoverTwentyFourHours => '24 часа';
  @override
  String get discoverSevenDays => '7 дней';
  @override
  String get discoverThirtyDays => '30 дней';
  @override
  String get discoverLocal => 'Локальное';
  @override
  String get discoverGlobal => 'Глобальное';
  @override
  String get chatTitle => 'Чаты';
  @override
  String get chatNewMessage => 'Новое сообщение';
  @override
  String get chatSearchConversations => 'Поиск диалогов';
  @override
  String get chatNoConversations => 'Пока нет диалогов';
  @override
  String get chatStartChatting => 'Начните общаться с людьми рядом!';
  @override
  String get chatSearchByName => 'Поиск по имени или @ручке';
  @override
  String get chatPinChat => 'Закрепить чат';
  @override
  String get chatPinned => 'Чат закреплен';
  @override
  String get chatUnpinned => 'Чат откреплен';
  @override
  String get chatMuteNotifications => 'Отключить уведомления';
  @override
  String get chatNotificationsMuted => 'Уведомления отключены';
  @override
  String get chatNotificationsUnmuted => 'Уведомления включены';
  @override
  String get chatArchive => 'Архивировать чат';
  @override
  String get chatArchived => 'Чат архивирован';
  @override
  String get chatDeleteConversation => 'Удалить диалог';
  @override
  String get chatDeleteConversationTitle => 'Удалить диалог?';
  @override
  String chatDeleteConversationMsg({required String name}) => 'Это навсегда удалит весь диалог с $name. Это действие невозможно отменить.';
  @override
  String get chatUndo => 'Отменить';
  @override
  String get chatConversationDeleted => 'Диалог удален';
  @override
  String get chatOnline => 'Онлайн';
  @override
  String get chatJustNow => 'Только что';
  @override
  String get chatTo => 'Кому: ';
  @override
  String get chatActiveNow => 'Активен сейчас';
  @override
  String get chatSaySomething => 'Напишите что-нибудь...';
  @override
  String get chatCalling => 'Вызов...';
  @override
  String get chatNoAnswer => 'Нет ответа';
  @override
  String get chatCannotConnect => 'Не удалось подключиться к серверу. Проверьте интернет.';
  @override
  String chatScreenshotAlert({required String user}) => '$user сделал скриншот этого чата';
  @override
  String chatMessageRequests({required String count, required String plural}) => '$count запрос сообщения$plural';
  @override
  String get chatAcceptAndRemove => 'Принять и удалить';
  @override
  String get chatApproveAndRemove => 'Одобрить и удалить';
  @override
  String get chatThemeBerry => 'Berry';
  @override
  String get chatThemeDefault => 'По умолчанию';
  @override
  String get chatThemeOcean => 'Ocean';
  @override
  String get chatThemeSunset => 'Sunset';
  @override
  String get chatThemeForest => 'Forest';
  @override
  String get chatThemeGold => 'Gold';
  @override
  String get chatThemeLavender => 'Lavender';
  @override
  String get chatThemeMidnight => 'Midnight';
  @override
  String get chatMediaCamera => 'Камера';
  @override
  String get chatMediaPhoto => 'Фото';
  @override
  String get chatMediaVideo => 'Видео';
  @override
  String get chatMediaAudio => 'Аудио';
  @override
  String get chatMediaGif => 'GIF';
  @override
  String get chatSettingsProfile => 'Профиль';
  @override
  String get chatSettingsSearch => 'Поиск';
  @override
  String get chatSettingsTheme => 'Тема';
  @override
  String get chatSettingsNicknames => 'Прозвища';
  @override
  String get chatSettingsCustomNicknamesSet => 'Пользовательские прозвища установлены';
  @override
  String get chatSettingsSetNicknames => 'Установить прозвища';
  @override
  String get chatSettingsDisappearing => 'Исчезающие сообщения';
  @override
  String get chatSettingsDisappearingOff => 'Выключено';
  @override
  String get chatSettingsDisappearing24h => '24 часа';
  @override
  String get chatSettingsDisappearing7d => '7 дней';
  @override
  String get chatSettingsDisappearing90d => '90 дней';
  @override
  String get chatSettingsPrivacy => 'Конфиденциальность и безопасность';
  @override
  String get chatSettingsPrivacyDesc => 'Шифрование, данные';
  @override
  String get chatSettingsEncrypted => 'Зашифрованные сообщения';
  @override
  String get chatSettingsEncryptedDesc => 'Сообщения зашифрованы с помощью AES-256 и хранятся безопасно.';
  @override
  String get chatSettingsCreateGroup => 'Создать групповой чат';
  @override
  String get chatSettingsCreateGroupBtn => 'Создать группу';
  @override
  String chatSettingsBlockUser({required String name}) => 'Заблокировать $name?';
  @override
  String chatSettingsUserBlocked({required String name}) => '$name заблокирован';
  @override
  String chatSettingsUserRestricted({required String name}) => '$name ограничен';
  @override
  String get chatSettingsRestrictionDesc => 'Ограничение: они могут вам писать, но ответы идут в запросы сообщений';
  @override
  String chatSettingsHideOnline({required String name}) => 'Скрыть статус онлайн от $name';
  @override
  String chatSettingsCanSeeOnline({required String name}) => '$name может видеть, когда вы онлайн';
  @override
  String chatSettingsCannotSeeOnline({required String name}) => '$name не может видеть, когда вы активны';
  @override
  String get chatSettingsChatDeleted => 'Чат удален';
  @override
  String get chatSettingsChatMuted => 'Чат отключен';
  @override
  String get chatSettingsChatUnmuted => 'Чат включен';
  @override
  String get chatSettingsFailedDelete => 'Не удалось удалить чат';
  @override
  String get chatSettingsFailedOnline => 'Не удалось обновить статус онлайн';
  @override
  String get chatSettingsFailedBlock => 'Не удалось обновить статус блокировки';
  @override
  String get chatSettingsFailedRestriction => 'Не удалось обновить ограничение';
  @override
  String get chatSettingsFailedVisibility => 'Не удалось обновить видимость';
  @override
  String get chatSettingsReportFakeAccount => 'Поддельный аккаунт';
  @override
  String get chatSettingsReportHarassment => 'Преследование';
  @override
  String get chatSettingsReportInappropriate => 'Неуместный контент';
  @override
  String get chatSettingsFailedReport => 'Не удалось отправить отчет';
  @override
  String get profileTitle => 'Профиль';
  @override
  String get profilePosts => 'Посты';
  @override
  String get profileFollowers => 'Подписчики';
  @override
  String get profileFollowing => 'Подписки';
  @override
  String get profileAdminPanel => 'Панель администратора';
  @override
  String get profileAnalytics => 'Аналитика';
  @override
  String get profileEarnings => 'Панель доходов';
  @override
  String get profileGoPremium => 'Перейти на Premium';
  @override
  String get profileMyCircle => 'Мой круг';
  @override
  String get profileSavedPosts => 'Сохраненные посты';
  @override
  String get profileSavedReels => 'Сохраненные видео';
  @override
  String get profileSignOut => 'Выход';
  @override
  String get profileEditProfile => 'Редактировать профиль';
  @override
  String get profileNearfoScore => 'Nearfo Score';
  @override
  String get profileNearfoScoreDesc => 'Ваше локальное влияние и вовлечение';
  @override
  String get profilePro => 'PRO';
  @override
  String get profileOwner => 'Владелец';
  @override
  String get profilePremium => 'Premium';
  @override
  String get editProfileTitle => 'Редактировать профиль';
  @override
  String get editProfileDisplayName => 'Отображаемое имя';
  @override
  String get editProfileUsername => 'Имя пользователя';
  @override
  String get editProfileUsernameRequired => 'Имя пользователя требуется';
  @override
  String get editProfileUsernameMinLength => 'Имя пользователя должно быть не менее 3 символов';
  @override
  String get editProfileUsernameInvalid => 'Только буквы, цифры и подчеркивания';
  @override
  String get editProfileNameRequired => 'Имя требуется';
  @override
  String get editProfileNameMinLength => 'Имя должно быть не менее 2 символов';
  @override
  String get editProfileBio => 'О себе';
  @override
  String get editProfileBioHint => 'Расскажите о себе...';
  @override
  String get editProfileDob => 'Дата рождения';
  @override
  String get editProfileNotSet => 'Не установлено';
  @override
  String get editProfileLocation => 'Местоположение';
  @override
  String get editProfileLocationAutoUpdate => 'Местоположение обновляется автоматически на основе вашего GPS';
  @override
  String get editProfileChangePhoto => 'Изменить фото';
  @override
  String get editProfileTakePhoto => 'Сделать фото';
  @override
  String get editProfileChooseGallery => 'Выбрать из галереи';
  @override
  String get editProfileCreateAvatar => 'Создать цифровой аватар';
  @override
  String get editProfileAvatarDesc => 'Профиль в стиле мультфильма';
  @override
  String get editProfileTapToSelect => 'Нажмите, чтобы выбрать';
  @override
  String get editProfileUpdated => 'Профиль обновлен!';
  @override
  String get editProfilePhotoUpdated => 'Фото обновлено!';
  @override
  String get editProfileUploadFailed => 'Не удалось загрузить';
  @override
  String editProfileError({required String error}) => 'Ошибка: $error';
  @override
  String get editProfileFailed => 'Не удалось обновить профиль';
  @override
  String get userProfileNoPosts => 'Пока нет постов';
  @override
  String get userProfileBlockUser => 'Заблокировать пользователя';
  @override
  String get userProfileBlockConfirm => 'Заблокировать пользователя?';
  @override
  String get userProfileUnblockUser => 'Разблокировать пользователя';
  @override
  String get userProfileUnblockConfirm => 'Разблокировать пользователя?';
  @override
  String get userProfileLocalInfluence => 'Локальное влияние и вовлечение';
  @override
  String get userProfileBlocked => 'Вы заблокировали этого пользователя';
  @override
  String get userProfileBlockedByThem => 'Вы не можете взаимодействовать с этим профилем, потому что они вас заблокировали';
  @override
  String get userProfileUnblockDesc => 'Они смогут видеть ваш профиль и взаимодействовать с вами снова.';
  @override
  String get userProfileBlockDesc => 'Они не смогут видеть ваш профиль и взаимодействовать с вами.';
  @override
  String get userProfileBlockedSnack => 'Пользователь заблокирован';
  @override
  String get userProfileUnblockedSnack => 'Пользователь разблокирован';
  @override
  String get userProfileNotFound => 'Пользователь не найден';
  @override
  String get userProfileNoHandle => 'Не указано имя пользователя или ID';
  @override
  String get userProfileFollowFailed => 'Не удалось обновить статус подписки';
  @override
  String get userProfileReportUser => 'Пожаловаться на пользователя';
  @override
  String get userProfileReportSubmitted => 'Жалоба отправлена';
  @override
  String followersTitle({required String count}) => 'Подписчики $count';
  @override
  String followingTitle({required String count}) => 'Подписки $count';
  @override
  String get followersLoadMore => 'Загрузить ещё';
  @override
  String get followersNoFollowers => 'Пока нет подписчиков';
  @override
  String get followersNotFollowing => 'Пока ни на кого не подписаны';
  @override
  String get followersUserIdMissing => 'ID пользователя отсутствует';
  @override
  String get notificationsTitle => 'Уведомления';
  @override
  String get notificationsNone => 'Пока нет уведомлений';
  @override
  String get notificationsNoneDesc => 'Когда люди взаимодействуют с вашими постами,
вы увидите это здесь';
  @override
  String get notificationsMarkAllRead => 'Отметить все как прочитанные';
  @override
  String get reelsForYou => 'Для вас';
  @override
  String get reelsFollowing => 'Подписки';
  @override
  String get reelsNearby => 'Рядом';
  @override
  String get reelsNoReels => 'Пока нет видео';
  @override
  String get reelsBeFirst => 'Будьте первым, кто опубликует видео!';
  @override
  String get reelsLoading => 'Загрузка видео...';
  @override
  String get reelsShare => 'Поделиться видео';
  @override
  String reelsShareText({required String url}) => 'Смотри это видео в Nearfo! $url';
  @override
  String get reelsDeleteReel => 'Удалить видео';
  @override
  String get reelsDeleteConfirm => 'Удалить видео?';
  @override
  String get reelsDeleteWarning => 'Это действие невозможно отменить.';
  @override
  String get reelsReportReel => 'Пожаловаться на видео';
  @override
  String get reelsReportSubmitted => 'Жалоба отправлена';
  @override
  String reelsOriginalAudio({required String name}) => 'Оригинальный звук - $name';
  @override
  String get createReelTitle => 'Создать новое видео';
  @override
  String get createReelRecord => 'Записать видео';
  @override
  String get createReelRecordDesc => 'Используйте камеру для записи нового видео';
  @override
  String get createReelSelect => 'Выбрать существующее видео';
  @override
  String get createReelUploadPhoto => 'Загрузить фото';
  @override
  String get createReelPhotoDesc => 'Создать видео из фото из галереи';
  @override
  String get createReelSettings => 'Настройки';
  @override
  String get createReelWhoCanSee => 'Кто может видеть';
  @override
  String get createReelEveryone => 'Все';
  @override
  String get createReelNearby => 'Рядом';
  @override
  String get createReelCircle => 'Круг';
  @override
  String get createReelSpecs => 'Видео: макс 90с • 720p | Фото: макс 20МБ';
  @override
  String get createReelCameraPermission => 'Требуется разрешение камеры';
  @override
  String get createReelGalleryPermission => 'Требуется разрешение галереи';
  @override
  String get createReelPreparingVideo => 'Подготовка видео...';
  @override
  String get createReelConverting => 'Преобразование в 720p для лучшего качества...';
  @override
  String get createReelOptimizing => 'Оптимизация видео';
  @override
  String get createReelVideoTooLarge => 'Видео слишком большое (макс 1ГБ). Пожалуйста, выберите более короткое видео.';
  @override
  String get createReelImageTooLarge => 'Изображение слишком большое (макс 20МБ). Пожалуйста, выберите меньшее изображение.';
  @override
  String createReelCompressedTooLarge({required String mb}) => 'Видео слишком большое после сжатия ($mbМБ). Макс 75МБ.';
  @override
  String createReelCompressionFailed({required String error}) => 'Ошибка сжатия: $error';
  @override
  String createReelPickVideoFailed({required String error}) => 'Не удалось выбрать видео: $error';
  @override
  String createReelPickImageFailed({required String error}) => 'Не удалось выбрать изображение: $error';
  @override
  String get storyLabel => 'ИСТОРИЯ';
  @override
  String get reelLabel => 'ВИДЕО';
  @override
  String get liveLabel => 'ПРЯМОЙ ЭФИР';
  @override
  String get postLabel => 'ПОСТ';
  @override
  String get storyMulti => 'Множество';
  @override
  String get storyBoomerang => 'Бумеранг';
  @override
  String get storyTapInstruction => 'Нажмите кнопку, чтобы сделать фото
Держите 30 сек для видео
или выберите из галереи ниже';
  @override
  String get storyTapShort => 'Нажмите для фото • Удерживайте для 30с видео';
  @override
  String get storyTapReel => 'Нажмите для записи видео';
  @override
  String get storyPhotoPermission => 'Требуется разрешение библиотеки фото';
  @override
  String get storyCameraPermission => 'Требуется разрешение камеры';
  @override
  String get storyGalleryPermission => 'Требуется разрешение галереи';
  @override
  String get storyMaxDuration => '30с';
  @override
  String get storyLayout => 'Макет';
  @override
  String get storySettings => 'Настройки';
  @override
  String get storyAddAnother => 'Добавить ещё';
  @override
  String storyProgress({required String current, required String total}) => 'История $current из $total';
  @override
  String get storyEditEach => 'Редактируйте каждую историю перед загрузкой';
  @override
  String get storyUploaded => 'История загружена!';
  @override
  String get storyAddAnotherQuestion => 'Хотите добавить ещё историю?';
  @override
  String get storyContinueUploading => 'Продолжить загрузку?';
  @override
  String storyUploadedCount({required String uploaded, required String max}) => '$uploaded из $max историй добавлено';
  @override
  String get storyMaxReached => 'Максимум 10 историй одновременно';
  @override
  String storyMaxReachedCount({required String count}) => '$count историй загружено! (максимум достигнут)';
  @override
  String storyAllUploaded({required String count}) => '$count историй загружено!';
  @override
  String storyContinueRemaining({required String done, required String total}) => '$done из $total историй готово.
Вы хотите продолжить с оставшимися историями?';
  @override
  String get storyEditorText => 'Текст';
  @override
  String get storyEditorStickers => 'Стикеры';
  @override
  String get storyEditorEffects => 'Эффекты';
  @override
  String get storyEditorDraw => 'Рисовать';
  @override
  String get storyEditorMusic => 'Музыка';
  @override
  String get storyEditorAddMusic => 'Добавить музыку';
  @override
  String get storyEditorAddPoll => 'Добавить опрос';
  @override
  String get storyEditorAddQuestion => 'Добавить вопрос';
  @override
  String get storyEditorAddLink => 'Добавить ссылку';
  @override
  String get storyEditorAddCountdown => 'Добавить обратный отсчет';
  @override
  String get storyEditorAddMention => 'Добавить упоминание';
  @override
  String get storyEditorMusicRemoved => 'Музыка удалена';
  @override
  String get storyEditorSearchMusic => 'Поиск музыки...';
  @override
  String get storyEditorNoMusic => 'Музыка не найдена';
  @override
  String storyEditorMusicError({required String name}) => 'Не удалось воспроизвести "$name"';
  @override
  String get storyEditorCaption => 'Добавить заголовок...';
  @override
  String get storyEditorTypeQuestion => 'Введите ваш вопрос';
  @override
  String get storyEditorYourQuestion => 'Ваш вопрос';
  @override
  String get storyEditorAskQuestion => 'Задайте вопрос...';
  @override
  String get storyEditorTypeSomething => 'Напишите что-нибудь...';
  @override
  String get storyEditorSearchUser => 'Поиск пользователя для упоминания';
  @override
  String get storyEditorSearchUsers => 'Поиск пользователей...';
  @override
  String get storyEditorMentionSomeone => 'Упомянуть кого-нибудь';
  @override
  String get storyEditorMention => 'Упоминание';
  @override
  String get storyEditorLinkLabel => 'Подпись ссылки';
  @override
  String get storyEditorLink => 'Ссылка';
  @override
  String get storyEditorLinkHint => 'https://...';
  @override
  String get storyEditorCountdownTitle => 'Добавить обратный отсчет';
  @override
  String get storyEditorCountdown => 'Обратный отсчет';
  @override
  String get storyEditorAiLabels => 'AI теги';
  @override
  String get storyEditorAiSuggested => 'AI предложил теги';
  @override
  String get storyEditorHashtag => 'Хэштег';
  @override
  String get storyEditorPoll => 'ОПРОС';
  @override
  String get storyEditorQuestion => 'ВОПРОС';
  @override
  String get storyEditorLinkTag => 'ССЫЛКА';
  @override
  String get storyEditorMentionTag => 'УПОМИНАНИЕ';
  @override
  String get storyEditorLocationTag => 'МЕСТОПОЛОЖЕНИЕ';
  @override
  String get storyEditorMusicTag => 'МУЗЫКА';
  @override
  String get storyEditorHashtagTag => 'ХЭШТЕГ';
  @override
  String get storyEditorOption1 => 'Вариант 1';
  @override
  String get storyEditorOption2 => 'Вариант 2';
  @override
  String get storyEditorPollLabel => 'Опрос';
  @override
  String get storyEditorCreatePoll => 'Создать опрос';
  @override
  String get storyEditorShares => 'Поделилось';
  @override
  String storyEditorLikes({required String count}) => 'Лайки: $count';
  @override
  String get storyEditorViewers => 'Зрители';
  @override
  String storyEditorCountdownEnd({required String date}) => 'Конец: $date';
  @override
  String get storyEditorEventName => 'Название события';
  @override
  String get storyEditorCountdownTag => 'ОБРАТНЫЙ ОТСЧЕТ';
  @override
  String get storyEditorDays => 'ДНИ';
  @override
  String get storyEditorHours => 'ЧАС.';
  @override
  String get storyEditorCountdownTimer => 'Таймер обратного отсчета';
  @override
  String get storyEditorRemoveElement => 'Удалить этот элемент?';
  @override
  String get storyEditorPermanentMarker => 'Постоянный маркер';
  @override
  String get storyEditorNormal => 'Обычный';
  @override
  String get storyEditorFilterDefault => 'По умолчанию';
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
  String get storyEditorTurnOffCommenting => 'Выключить комментарии';
  @override
  String get storyEditorVisibilityEveryone => 'Все';
  @override
  String get storyEditorVisibilityCloseFriends => 'Близкие друзья';
  @override
  String get storyEditorVisibilityMyCircle => 'Мой круг';
  @override
  String get storyEditorVisibilityNearby => 'Рядом';
  @override
  String get storyEditorVisibilityTrending => 'Тренды';
  @override
  String get storyEditorSaveToGallery => 'Сохранить в галерею';
  @override
  String get storyEditorSaved => 'Сохранено в галерею!';
  @override
  String get storyEditorPostReel => 'Опубликовать видео';
  @override
  String get storyEditorPostingReel => 'Публикация вашего видео...';
  @override
  String get storyEditorSharingStory => 'Поделение вашей историей...';
  @override
  String get storyEditorReelFailed => 'Не удалось создать видео';
  @override
  String get storyEditorStoryFailed => 'Не удалось создать историю';
  @override
  String get storyEditorImageUploadFailed => 'Не удалось загрузить изображение';
  @override
  String get storyEditorVideoUploadFailed => 'Не удалось загрузить видео';
  @override
  String get storyEditorUploadEmptyUrl => 'Загрузка вернула пустой URL';
  @override
  String get storyEditorCouldNotSave => 'Не удалось сохранить';
  @override
  String get storiesDeleteStory => 'Удалить историю';
  @override
  String get storiesDeleteConfirm => 'Удалить историю?';
  @override
  String get storiesDeleteWarning => 'Эта история будет навсегда удалена. Это действие невозможно отменить.';
  @override
  String get storiesReportStory => 'Пожаловаться на историю';
  @override
  String get storiesDeleted => 'История удалена';
  @override
  String get storiesReported => 'История сообщена';
  @override
  String get storiesReplySent => 'Ответ отправлен!';
  @override
  String get storiesDeleteFailed => 'Не удалось удалить';
  @override
  String get storiesNetworkError => 'Ошибка сети, попробуйте ещё раз';
  @override
  String get storiesSendMessage => 'Отправить сообщение...';
  @override
  String storiesViewers({required String count}) => 'Зрители ($count)';
  @override
  String storiesLikes({required String count}) => 'Лайки ($count)';
  @override
  String get storiesNoViewers => 'Пока нет зрителей';
  @override
  String get storiesNoLikes => 'Пока нет лайков';
  @override
  String get storiesUnknown => 'Неизвестно';
  @override
  String get storiesCouldntLoad => 'Не удалось загрузить';
  @override
  String get storiesMediaNotAvailable => 'Медиа недоступно';
  @override
  String get collectionsTitle => 'Коллекции';
  @override
  String get collectionsNone => 'Пока нет коллекций';
  @override
  String get collectionsNoneDesc => 'Сохраняйте посты в коллекции, чтобы организовать их';
  @override
  String get collectionsCreate => 'Создать коллекцию';
  @override
  String get collectionsNew => 'Новая коллекция';
  @override
  String get collectionsNameHint => 'Название коллекции';
  @override
  String get collectionsUntitled => 'Без названия';
  @override
  String collectionsPostCount({required String count}) => '$count постов';
  @override
  String get collectionsNoPosts => 'Нет постов в этой коллекции';
  @override
  String get collectionsDeleteConfirm => 'Удалить коллекцию?';
  @override
  String get collectionsDeleteWarning => 'Это невозможно отменить.';
  @override
  String get savedPostsTitle => 'Сохраненные посты';
  @override
  String get savedPostsNone => 'Нет сохраненных постов';
  @override
  String get savedPostsNoneDesc => 'Посты, которые вы сохраняете, появятся здесь';
  @override
  String get savedReelsTitle => 'Сохраненные видео';
  @override
  String get savedReelsNone => 'Нет сохраненных видео';
  @override
  String get savedReelsNoneDesc => 'Видео, которые вы сохраняете, появятся здесь';
  @override
  String get savedReelsRemoveConfirm => 'Удалить из сохраненного?';
  @override
  String get savedReelsRemoveDesc => 'Это видео будет удалено из вашего списка сохраненного.';
  @override
  String get liveStartTitle => 'Начать прямой эфир';
  @override
  String get liveStartDesc => 'Начните прямой эфир и общайтесь
с людьми рядом с вами!';
  @override
  String get liveYouAreLive => 'Вы в прямом эфире!';
  @override
  String get liveYouAreLiveDesc => 'Вы теперь в прямом эфире! Зрители могут присоединиться в любой момент.';
  @override
  String get liveStreaming => 'Трансляция для вашей аудитории';
  @override
  String get liveStartStreaming => 'Начать трансляцию для вашей аудитории';
  @override
  String get liveGoLiveNow => 'Начать прямой эфир сейчас';
  @override
  String get liveGoLive => 'Начать прямой эфир';
  @override
  String get liveTitleHint => 'Дайте название вашему прямому эфиру...';
  @override
  String get liveCategoryGeneral => 'Общее';
  @override
  String get liveCategoryGaming => 'Игры';
  @override
  String get liveCategoryMusic => 'Музыка';
  @override
  String get liveCategoryEducation => 'Образование';
  @override
  String get liveCategoryFitness => 'Фитнес';
  @override
  String get liveCategoryCooking => 'Кулинария';
  @override
  String get liveCategoryOther => 'Другое';
  @override
  String get liveCategory => 'Категория';
  @override
  String liveDuration({required String duration}) => 'Длительность: $duration';
  @override
  String get liveEndConfirm => 'Завершить прямой эфир?';
  @override
  String get liveEndStream => 'Завершить трансляцию';
  @override
  String get liveEnd => 'Завершить';
  @override
  String get liveEndWarning => 'Ваш прямой эфир завершится и зрители будут отключены.';
  @override
  String get liveStreamEnded => 'Трансляция завершена';
  @override
  String get liveStreamEndedDesc => 'Этот прямой эфир завершен';
  @override
  String get liveNoOneIsLive => 'Никто не в прямом эфире';
  @override
  String get liveWatch => 'Смотреть';
  @override
  String get liveViewer => 'Зритель';
  @override
  String liveViewers({required String count}) => 'Зрители: $count';
  @override
  String liveLikes({required String count}) => 'Лайки: $count';
  @override
  String get liveSaySomething => 'Напишите что-нибудь...';
  @override
  String get liveChat => 'Чат';
  @override
  String get liveChats => 'Чаты';
  @override
  String get liveLikesTab => 'Лайки';
  @override
  String get liveViewersTab => 'Зрители';
  @override
  String get liveSystem => 'Система';
  @override
  String get liveWelcome => 'Добро пожаловать на прямой эфир!';
  @override
  String get liveYou => 'Вы';
  @override
  String get liveStartFailed => 'Не удалось начать прямой эфир';
  @override
  String get liveJustStarted => 'Только что начался';
  @override
  String liveShareText({required String name, required String title}) => '$name начал прямой эфир на Nearfo! "$title" — Присоединяйтесь и смотрите!';
  @override
  String get hashtagRecent => 'Недавнее';
  @override
  String get hashtagTop => 'Топ';
  @override
  String hashtagPostCount({required String count}) => '$count постов';
  @override
  String hashtagNoPosts({required String tag}) => 'Нет постов с #$tag';
  @override
  String get myCircleTitle => 'Мой круг';
  @override
  String get myCircleNone => 'Пока никого в круге';
  @override
  String get myCircleNoneDesc => 'Люди, которые следят за вами, и вы следите за ними';
  @override
  String get myCircleNoneDetail => 'Ваш круг показывает взаимных последователей — людей, за которыми вы следите, и которые тоже следят за вами. Начните следить за людьми рядом!';
  @override
  String get myCircleDiscover => 'Открыть людей';
  @override
  String get myCircleMutual => 'Взаимные';
  @override
  String myCircleCount({required String count, required String label}) => '$count взаимный(е) $label';
  @override
  String get myCircleConnection => 'связь';
  @override
  String get myCircleConnections => 'связи';
  @override
  String get messageRequestsTitle => 'Запросы сообщений';
  @override
  String get messageRequestsNone => 'Нет запросов сообщений';
  @override
  String get messageRequestsNoneDesc => 'Когда люди, которые не в вашем списке подписчиков, отправляют вам сообщения, они сначала появятся здесь.';
  @override
  String get messageRequestsNoNotify => 'Вы не будете получать уведомления об этих сообщениях.';
  @override
  String get messageRequestsSentMessage => 'Отправил вам сообщение';
  @override
  String get messageRequestsUser => 'Пользователь';
  @override
  String get messageRequestsKeep => 'Сохранить';
  @override
  String get messageRequestsDecline => 'Отклонить';
  @override
  String get messageRequestsDeclineConfirm => 'Отклонить запрос?';
  @override
  String get messageRequestsDeclined => 'Запрос отклонен';
  @override
  String get messageRequestsAcceptFailed => 'Не удалось принять запрос';
  @override
  String get messageRequestsDeclineFailed => 'Не удалось отклонить запрос';
  @override
  String get settingsTitle => 'Настройки';
  @override
  String get settingsAccount => 'Аккаунт';
  @override
  String settingsEmail({required String email}) => 'Email: $email';
  @override
  String settingsPhone({required String phone}) => 'Телефон: $phone';
  @override
  String get settingsNotSetValue => 'Не установлено';
  @override
  String get settingsUpdateEmail => 'Обновить email';
  @override
  String get settingsUpdatePhone => 'Обновить телефон';
  @override
  String get settingsEnterEmail => 'Введите новый адрес email';
  @override
  String get settingsEnterPhone => 'Введите номер телефона';
  @override
  String get settingsValidEmail => 'Пожалуйста, введите корректный email';
  @override
  String get settingsValidPhone => 'Пожалуйста, введите номер телефона';
  @override
  String get settingsSaveEmail => 'Сохранить email';
  @override
  String get settingsSavePhone => 'Сохранить телефон';
  @override
  String get settingsEmailUpdated => 'Email обновлен!';
  @override
  String get settingsPhoneUpdated => 'Телефон обновлен!';
  @override
  String get settingsPreferences => 'Предпочтения';
  @override
  String get settingsFeedPreference => 'Предпочтение ленты';
  @override
  String settingsFeedPreferenceValue({required String value}) => 'Предпочтение ленты: $value';
  @override
  String get settingsFeedDesc => 'Выберите, как организована ваша лента';
  @override
  String get settingsFeedNearby => 'Сначала рядом';
  @override
  String get settingsFeedTrending => 'Тренды';
  @override
  String get settingsFeedMixed => 'Смешанное';
  @override
  String get settingsFeedMixedDesc => 'Смешивание постов рядом и трендовых';
  @override
  String get settingsFeedNearbyDesc => 'Приоритет постам от людей рядом';
  @override
  String get settingsFeedTrendingDesc => 'Показать трендовые посты первыми';
  @override
  String get settingsProfileVisibility => 'Видимость профиля';
  @override
  String settingsProfileVisibilityValue({required String value}) => 'Видимость профиля: $value';
  @override
  String get settingsProfileVisibilityDesc => 'Кто может видеть ваш профиль';
  @override
  String get settingsPublic => 'Публичный';
  @override
  String get settingsPublicDesc => 'Все могут видеть ваш профиль';
  @override
  String get settingsPrivate => 'Приватный';
  @override
  String get settingsPrivateDesc => 'Только вы можете видеть детали вашего профиля';
  @override
  String get settingsFollowersOnly => 'Только подписчикам';
  @override
  String get settingsFollowersOnlyDesc => 'Только ваши подписчики могут видеть ваш полный профиль';
  @override
  String get settingsActivityFriends => 'Активность во вкладке друзей';
  @override
  String get settingsActivityFriendsDesc => 'Управляйте видимостью вашей активности';
  @override
  String get settingsShowNewFollows => 'Показывать новые подписки';
  @override
  String get settingsShowNewFollowsDesc => 'Друзья могут видеть, на кого вы подписались';
  @override
  String get settingsShowComments => 'Показывать комментарии';
  @override
  String get settingsShowCommentsDesc => 'Друзья могут видеть ваши комментарии';
  @override
  String get settingsShowLikedPosts => 'Показывать отмеченные посты';
  @override
  String get settingsShowLikedPostsDesc => 'Друзья могут видеть посты, которые вам нравятся';
  @override
  String get settingsShowOnline => 'Показывать статус онлайн';
  @override
  String get settingsOnlineVisible => 'Статус онлайн виден. Другие могут видеть, когда вы активны.';
  @override
  String get settingsOnlineHidden => 'Статус онлайн скрыт. Для всех вы будете отображаться как офлайн.';
  @override
  String get settingsShowBirthday => 'Показывать дату рождения в профиле';
  @override
  String get settingsVisibilityPublic => 'Видимость установлена на публичную';
  @override
  String get settingsVisibilityPrivate => 'Видимость установлена на приватную';
  @override
  String get settingsVisibilityFollowers => 'Видимость установлена на только для подписчиков';
  @override
  String get settingsStoryLiveLocation => 'История, прямой эфир и местоположение';
  @override
  String get settingsStoryLiveLocationDesc => 'Управляйте тем, кто видит ваши истории и местоположение';
  @override
  String get settingsAllowStoryReplies => 'Разрешить ответы на истории';
  @override
  String get settingsAllowStoryRepliesDesc => 'Все могут отвечать на ваши истории';
  @override
  String get settingsShowLocationStories => 'Показывать местоположение в историях';
  @override
  String get settingsShowLocationStoriesDesc => 'Ваш город видим на ваших историях';
  @override
  String get settingsLiveNotifications => 'Уведомления о прямом эфире';
  @override
  String get settingsLiveNotificationsDesc => 'Получайте уведомления, когда друзья начинают трансляцию';
  @override
  String get settingsLocation => 'Местоположение';
  @override
  String settingsRadius({required String radius}) => 'Радиус: $radiusкм (регулируется в Открыть)';
  @override
  String get settingsLocationUpdated => 'Местоположение обновлено!';
  @override
  String get settingsLocationError => 'Не удалось получить местоположение. Проверьте GPS и разрешения.';
  @override
  String settingsLocationErrorDetail({required String error}) => 'Ошибка местоположения: $error';
  @override
  String get settingsNotifications => 'Уведомления';
  @override
  String get settingsNotificationsEnabled => 'Уведомления включены';
  @override
  String get settingsNotificationsDisabled => 'Уведомления отключены';
  @override
  String get settingsTheme => 'Тема';
  @override
  String settingsThemeValue({required String name}) => 'Тема: $name';
  @override
  String get settingsChooseTheme => 'Выберите тему';
  @override
  String get settingsApp => 'Приложение';
  @override
  String get settingsHelpImprove => 'Помогите нам улучшить Nearfo';
  @override
  String get settingsReportBug => 'Сообщить об ошибке';
  @override
  String get settingsReportBugHint => 'Опишите найденную ошибку...';
  @override
  String get settingsSubmitReport => 'Отправить отчет';
  @override
  String get settingsBugReportSubmitted => 'Отчет об ошибке отправлен! Спасибо.';
  @override
  String get settingsCouldNotOpenLink => 'Не удалось открыть ссылку';
  @override
  String get settingsPrivacyPolicy => 'Политика конфиденциальности';
  @override
  String get settingsTermsOfService => 'Условия использования';
  @override
  String get settingsAbout => 'О Nearfo';
  @override
  String get settingsVersion => 'Nearfo v1.0.0';
  @override
  String get settingsAccountPrivacy => 'Приватность аккаунта';
  @override
  String get settingsAccountPrivacyDesc => 'Приватность аккаунта';
  @override
  String get settingsBlocked => 'Заблокировано';
  @override
  String get settingsBlockedUsers => 'Заблокированные пользователи';
  @override
  String get settingsHideFollowersList => 'Скрыть список подписчиков/подписок';
  @override
  String get settingsFollowersVisible => 'Список подписчиков/подписок виден всем.';
  @override
  String get settingsFollowersHidden => 'Список подписчиков/подписок скрыт. Видно будет только количество.';
  @override
  String get settingsAdmin => 'Администратор';
  @override
  String get settingsModeration => 'Модерация (Блокировка/DMCA)';
  @override
  String get settingsMonetization => 'Монетизация';
  @override
  String get settingsCopyrightReport => 'Сообщить о нарушении авторских прав';
  @override
  String get settingsDeleteAccount => 'Удалить аккаунт';
  @override
  String get settingsDeleteAccountConfirm => 'Вы уверены? Это навсегда удалит ваш аккаунт, посты и все данные. Это действие невозможно отменить.';
  @override
  String get settingsDeleteAccountSent => 'Запрос на удаление аккаунта отправлен. Мы обработаем это в течение 24 часов.';
  @override
  String get settingsFailedOnlineStatus => 'Не удалось обновить статус онлайн';
  @override
  String get settingsFeedSetMixed => 'Лента установлена на смешанное';
  @override
  String get settingsFeedSetNearby => 'Лента установлена на сначала рядом';
  @override
  String get settingsFeedSetTrending => 'Лента установлена на тренды';
  @override
  String get accountPrivacyTitle => 'Приватность аккаунта';
  @override
  String get accountPrivacyPublicSet => 'Аккаунт установлен на публичный';
  @override
  String get accountPrivacyPrivateSet => 'Аккаунт установлен на приватный';
  @override
  String get accountPrivacyPublicTitle => 'Публичный аккаунт';
  @override
  String get accountPrivacyPrivateTitle => 'Приватный аккаунт';
  @override
  String get accountPrivacyPublicShort => 'Все могут видеть ваши посты и профиль';
  @override
  String get accountPrivacyPublicDesc => 'Все могут видеть ваши посты, истории и профиль. Люди могут вас следить без одобрения.';
  @override
  String get accountPrivacyPrivateShort => 'Только одобренные подписчики могут видеть ваши посты';
  @override
  String get accountPrivacyPrivateDesc => 'Только подписчики, которых вы одобрили, могут видеть ваши посты и истории. Информация профиля скрыта от не-подписчиков.';
  @override
  String get accountPrivacyWhenPublic => 'Когда ваш аккаунт публичный';
  @override
  String get accountPrivacyWhenPrivate => 'Когда ваш аккаунт приватный';
  @override
  String get accountPrivacySwitchNote => 'Переключение на приватное не повлияет на текущих подписчиков.';
  @override
  String get accountPrivacyNote => 'Примечание';
  @override
  String get premiumTitle => 'Перейти на Premium';
  @override
  String get premiumSubtitle => 'Nearfo Premium';
  @override
  String get premiumDesc => 'Разблокируйте полный опыт Nearfo';
  @override
  String get premiumChoosePlan => 'Выберите свой план';
  @override
  String get premiumChoosePlanBtn => 'Выбрать план';
  @override
  String get premiumMonthly => 'Ежемесячно';
  @override
  String get premiumYearly => 'Ежегодно';
  @override
  String get premiumLifetime => 'На всю жизнь';
  @override
  String get premiumPopular => 'ПОПУЛЯРНО';
  @override
  String get premiumVerifiedBadge => 'Проверенный значок';
  @override
  String get premiumVerifiedBadgeDesc => 'Выделитесь с проверенным профилем';
  @override
  String get premiumAdFree => 'Без рекламы';
  @override
  String get premiumAdFreeDesc => 'Просматривайте без перерывов';
  @override
  String get premiumPriorityFeed => 'Приоритетная лента';
  @override
  String get premiumPriorityFeedDesc => 'Ваши посты получают местный бустер';
  @override
  String get premiumCustomThemes => 'Пользовательские темы';
  @override
  String get premiumCustomThemesDesc => 'Персонализируйте внешний вид вашего профиля';
  @override
  String get premiumUnlockChatTheme => 'Разблокировать пользовательскую тему чата';
  @override
  String get premiumAdvancedAnalytics => 'Продвинутая аналитика';
  @override
  String get premiumAdvancedAnalyticsDesc => 'Глубокие знания о вашем охвате';
  @override
  String get premiumPrioritySupport => 'Приоритетная поддержка';
  @override
  String get premiumPrioritySupportDesc => 'Получайте помощь быстрее, когда она вам нужна';
  @override
  String get premiumSeeProfileViews => 'Смотрите, кто просматривал ваш профиль';
  @override
  String get premiumEverythingMonthly => 'Всё в ежемесячном плане';
  @override
  String get premiumEverythingForever => 'Всё на всегда';
  @override
  String get premiumFoundingBadge => 'Значок основателя';
  @override
  String get premiumEarlyAccess => 'Ранний доступ к функциям';
  @override
  String get premiumGetStarted => 'Начать';
  @override
  String premiumRewardUnlocked({required String label}) => 'Награда разблокирована! $label';
  @override
  String get premiumWatchAdsDesc => 'Получайте бесплатные функции premium, просматривая короткие объявления';
  @override
  String get premiumWatchAdsTitle => 'Смотрите объявления, получайте награды!';
  @override
  String get premiumWatchAdToUnlock => 'Смотрите объявление, чтобы разблокировать';
  @override
  String get premiumWatchAdToBoost => 'Смотрите объявление, чтобы бустить';
  @override
  String get premiumBoostPost => 'Бустить ваш пост на 1 час';
  @override
  String get premiumSaveYearly => 'Сэкономьте ₹389!';
  @override
  String get premiumPaymentComingSoon => 'Интеграция платежей скоро. Смотрите объявления, чтобы разблокировать функции сейчас!';
  @override
  String get premiumAdLoading => 'Объявление загружается, пожалуйста, попробуйте через минуту...';
  @override
  String get premiumPriceMonthly => '₹99';
  @override
  String get premiumPriceYearly => '₹799';
  @override
  String get premiumPriceLifetime => '₹1,999';
  @override
  String get premiumPerMonth => '/месяц';
  @override
  String get premiumPerYear => '/год';
  @override
  String get premiumOneTime => 'одноразово';
  @override
  String get analyticsTitle => 'Аналитика';
  @override
  String get analyticsOverview => 'Обзор';
  @override
  String get analyticsPosts => 'Посты';
  @override
  String get analyticsReels => 'Видео';
  @override
  String get analyticsThisWeek => 'На этой неделе';
  @override
  String get analyticsPostsCreated => 'Посты созданы';
  @override
  String get analyticsReelsUploaded => 'Видео загружены';
  @override
  String get analyticsTotalLikes => 'Всего лайков';
  @override
  String get analyticsComments => 'Комментарии';
  @override
  String get analyticsEngagement => 'Вовлечение';
  @override
  String get analyticsFollowers => 'Подписчики';
  @override
  String get analyticsFollowing => 'Подписки';
  @override
  String get analyticsNewFollowers => 'Новые подписчики';
  @override
  String get analyticsReelViews => 'Просмотры видео';
  @override
  String get analyticsLegend => 'Легенда';
  @override
  String get analyticsNewcomer => 'Новичок';
  @override
  String get analyticsRising => 'Растущий';
  @override
  String get analyticsStar => 'Звезда';
  @override
  String get analyticsActive => 'Активный';
  @override
  String get analyticsCouldNotLoad => 'Не удалось загрузить аналитику';
  @override
  String get analyticsTipToGrow => 'Советы для роста';
  @override
  String get analyticsGreatStart => 'Вы хорошо начали!';
  @override
  String get analyticsNewcomerTip => 'Отличное начало! Попробуйте опубликовать видео — они получают больше просмотров и помогают повысить ваше вовлечение.';
  @override
  String get analyticsAlmostThere => 'Почти готово! Ваш контент работает хорошо. Продолжайте развивать успех!';
  @override
  String get analyticsKeepPosting => 'Продолжайте публиковать и взаимодействовать с вашим сообществом, чтобы растить ваш счет!';
  @override
  String get analyticsRisingCreator => 'Вы растущий создатель!';
  @override
  String get nearfoScoreTitle => 'Nearfo Score';
  @override
  String get nearfoScoreDesc => 'Ваш счет локального влияния и вовлечения';
  @override
  String get nearfoScoreOutOf => '/100';
  @override
  String get nearfoScoreBreakdown => 'Разбор счета';
  @override
  String get nearfoScoreTipToImprove => 'Совет для улучшения';
  @override
  String get nearfoScoreActivity => 'Активность';
  @override
  String get nearfoScoreActivityTip => 'Будьте активны каждый день — ставьте лайки, комментируйте и делитесь постами, чтобы повысить счет активности.';
  @override
  String get nearfoScorePosts => 'Посты';
  @override
  String get nearfoScoreReels => 'Видео';
  @override
  String get nearfoScoreFollowers => 'Подписчики';
  @override
  String get nearfoScoreEngagement => 'Вовлечение';
  @override
  String get nearfoScoreFollowersTip => 'Следите за людьми в вашем районе и взаимодействуйте с их контентом — они последуют за вами!';
  @override
  String get nearfoScorePostsTip => 'Попробуйте публиковать чаще! Делитесь фото, мыслями и обновлениями со своим местным сообществом.';
  @override
  String get nearfoScoreReelsTip => 'Создавайте короткие видеоролики, чтобы повысить видимость и охватить больше людей рядом.';
  @override
  String get nearfoScoreEngagementTip => 'Пишите привлекательные подписи и отвечайте на комментарии, чтобы повысить вовлечение.';
  @override
  String get nearfoScoreWelcome => 'Добро пожаловать! Начните публиковать, чтобы расти';
  @override
  String get nearfoScoreGettingStarted => 'Начинаем! Опубликуйте больше';
  @override
  String get nearfoScoreGoodStart => 'Хорошее начало! Продолжайте взаимодействовать';
  @override
  String get nearfoScoreGreat => 'Отлично! Вы развиваете импульс';
  @override
  String get nearfoScoreExcellent => 'Отлично! Вы местный влиятельный';
  @override
  String get blockedUsersTitle => 'Заблокированные пользователи';
  @override
  String get blockedUsersNone => 'Нет заблокированных пользователей';
  @override
  String get blockedUsersNoneDesc => 'Пользователи, которых вы заблокировали, появятся здесь';
  @override
  String blockedUsersUnblocked({required String name}) => '$name был разблокирован';
  @override
  String get blockedUsersUnblockTitle => 'Разблокировать пользователя';
  @override
  String blockedUsersUnblockConfirm({required String name}) => 'Вы уверены, что хотите разблокировать $name? Они смогут видеть ваш профиль и взаимодействовать с вами снова.';
  @override
  String get createGroupTitle => 'Создать группу';
  @override
  String get createGroupNameHint => 'Название группы';
  @override
  String get createGroupNameRequired => 'Название группы требуется';
  @override
  String get createGroupDescHint => 'Описание (опционально)';
  @override
  String get createGroupSearchHint => 'Поиск людей для добавления...';
  @override
  String get createGroupMinMembers => 'Выберите не менее 2 участников';
  @override
  String get createGroupFailed => 'Ошибка';
  @override
  String get groupInfoEditGroup => 'Редактировать группу';
  @override
  String get groupInfoMembers => 'Участники';
  @override
  String groupInfoMemberCount({required String count}) => '$count участников';
  @override
  String get groupInfoAddMembers => 'Добавить участников';
  @override
  String get groupInfoAdd => 'Добавить';
  @override
  String get groupInfoSearchHint => 'Поиск людей...';
  @override
  String get groupInfoAdmin => 'Администратор';
  @override
  String get groupInfoViewProfile => 'Просмотр профиля';
  @override
  String get groupInfoRemoveFromGroup => 'Удалить из группы';
  @override
  String groupInfoMemberRemoved({required String name}) => '$name удален';
  @override
  String groupInfoRemoveConfirm({required String name}) => 'Удалить $name?';
  @override
  String get groupInfoRemoveDesc => 'Они больше не смогут отправлять и получать сообщения в этой группе.';
  @override
  String get groupInfoMuteToggled => 'Отключение переключено';
  @override
  String get groupInfoLeaveGroup => 'Покинуть группу';
  @override
  String get groupInfoLeaveConfirm => 'Покинуть группу?';
  @override
  String get groupInfoLeaveDesc => 'Вы больше не будете получать сообщения из этой группы. Это действие невозможно отменить.';
  @override
  String get groupInfoLeaveShort => 'Вы больше не будете получать сообщения';
  @override
  String get groupInfoLeave => 'Покинуть';
  @override
  String get groupInfoLeaveFailed => 'Не удалось покинуть группу';
  @override
  String groupInfoUserAdded({required String name}) => '$name добавлен';
  @override
  String groupInfoYou({required String name}) => '$name (Вы)';
  @override
  String get copyrightTitle => 'Сообщить об авторских правах';
  @override
  String get copyrightDesc => 'Если кто-то опубликовал ваш контент с авторскими правами без разрешения, заполните эту форму, чтобы запросить его удаление.';
  @override
  String get copyrightYourName => 'Ваше имя';
  @override
  String get copyrightNameHint => 'Введите ваше полное имя';
  @override
  String get copyrightYourEmail => 'Ваш email';
  @override
  String get copyrightEmailHint => 'Введите ваш email';
  @override
  String get copyrightContentType => 'Тип контента';
  @override
  String get copyrightTypePost => 'пост';
  @override
  String get copyrightTypeReel => 'видео';
  @override
  String get copyrightTypeStory => 'история';
  @override
  String get copyrightTypeComment => 'комментарий';
  @override
  String get copyrightContentId => 'ID контента';
  @override
  String get copyrightContentIdHint => 'ID нарушающего авторские права поста/видео';
  @override
  String get copyrightDescription => 'Описание';
  @override
  String get copyrightDescHint => 'Опишите, как было нарушено ваше авторское право';
  @override
  String get copyrightOriginalUrl => 'URL оригинального произведения';
  @override
  String get copyrightOriginalUrlHint => 'Ссылка на ваше оригинальное произведение (опционально)';
  @override
  String get copyrightSwornStatement => 'Я клянусь, под угрозой лжесвидетельства, что информация в этом уведомлении является точной и что я являюсь владельцем авторских прав или уполномочен действовать от их имени.';
  @override
  String get copyrightMustConfirm => 'Вы должны подтвердить присягнутое заявление';
  @override
  String get copyrightSubmit => 'Отправить DMCA отчет';
  @override
  String get copyrightRequired => 'Требуется';
  @override
  String get copyrightSubmitted => 'DMCA отчет отправлен. Мы рассмотрим это в течение 48 часов.';
  @override
  String get copyrightFailed => 'Не удалось отправить';
  @override
  String get moderationTitle => 'Модерация';
  @override
  String moderationTakedowns({required String count}) => 'Удаления ($count)';
  @override
  String moderationBanned({required String count}) => 'Заблокированы ($count)';
  @override
  String get moderationNoPendingTakedowns => 'Нет ожидающих удалений';
  @override
  String get moderationNoBannedUsers => 'Нет заблокированных пользователей';
  @override
  String get moderationReason => 'Причина';
  @override
  String moderationType({required String type}) => 'Тип: $type';
  @override
  String get moderationDuration => 'Длительность';
  @override
  String get moderationDuration24h => '24 часа';
  @override
  String get moderationDuration3d => '3 дня';
  @override
  String get moderationDuration7d => '7 дней';
  @override
  String get moderationDuration30d => '30 дней';
  @override
  String get moderationSuspend => 'Приостановить';
  @override
  String get moderationSuspendUser => 'Приостановить пользователя';
  @override
  String get moderationBan => 'Заблокировать';
  @override
  String get moderationBanUser => 'Заблокировать пользователя';
  @override
  String get moderationReject => 'Отклонить';
  @override
  String get moderationUnban => 'Разблокировать';
  @override
  String get moderationTakedownApproved => 'Удаление одобрено. Контент удален.';
  @override
  String get moderationTakedownRejected => 'Удаление отклонено';
  @override
  String get moderationUserBanned => 'Пользователь заблокирован';
  @override
  String get moderationUserSuspended => 'Пользователь приостановлен';
  @override
  String get moderationUserUnbanned => 'Пользователь разблокирован';
  @override
  String get moderationUnknown => 'Неизвестно';
  @override
  String get moderationUserId => 'ID пользователя';
  @override
  String get adminTitle => 'Панель администратора';
  @override
  String get adminDashboard => 'Панель';
  @override
  String get adminTotalUsers => 'Всего пользователей';
  @override
  String get adminPostsToday => 'Постов сегодня';
  @override
  String get adminReelsToday => 'Видео сегодня';
  @override
  String get adminOnlineUsers => 'Пользователи онлайн';
  @override
  String get adminPendingReports => 'Ожидающие отчеты';
  @override
  String get adminReports => 'Отчеты';
  @override
  String get adminActiveStories => 'Активные истории';
  @override
  String get adminAiAgents => 'AI агенты';
  @override
  String get adminSearchUsers => 'Поиск пользователей по имени или email...';
  @override
  String get adminUsers => 'Пользователи';
  @override
  String get adminVerified => 'Проверено';
  @override
  String get adminUnverified => 'Не проверено';
  @override
  String get adminVerify => 'Проверить';
  @override
  String get adminUnverify => 'Отменить проверку';
  @override
  String adminReportFrom({required String name}) => 'Отчет от $name';
  @override
  String get adminNoReason => 'Причина не указана';
  @override
  String get adminDismiss => 'Отклонить';
  @override
  String get adminReportDismissed => 'Отчет отклонен';
  @override
  String get adminTakeAction => 'Принять действие';
  @override
  String get adminContentType => 'Тип контента';
  @override
  String get adminContentHidden => 'Контент скрыт успешно';
  @override
  String get adminNoDescription => 'Нет описания';
  @override
  String get adminNoPendingReports => 'Нет ожидающих отчетов';
  @override
  String adminErrorLoadingReports({required String error}) => 'Ошибка загрузки отчетов: $error';
  @override
  String adminErrorLoadingDashboard({required String error}) => 'Ошибка загрузки панели: $error';
  @override
  String adminErrorLoadingUsers({required String error}) => 'Ошибка загрузки пользователей: $error';
  @override
  String adminErrorTakingAction({required String error}) => 'Ошибка выполнения действия: $error';
  @override
  String adminErrorDismissing({required String error}) => 'Ошибка отклонения отчета: $error';
  @override
  String adminErrorUpdatingUser({required String error}) => 'Ошибка обновления пользователя: $error';
  @override
  String get adminNoData => 'Нет доступных данных';
  @override
  String get adminNoEmail => 'Нет email';
  @override
  String get adminNoUsers => 'Пользователи не найдены';
  @override
  String get adminTotalMessages => 'Всего сообщений';
  @override
  String get adminTotalFollows => 'Всего подписок';
  @override
  String get adminAnonymous => 'Анонимный';
  @override
  String get bossAllAgents => 'Все агенты';
  @override
  String get bossQuickCommands => 'Быстрые команды';
  @override
  String get bossOrders => 'Заказы';
  @override
  String get bossFirstCommand => 'Дайте вашу первую команду выше!';
  @override
  String get bossNoOrders => 'Нет заказов';
  @override
  String get bossOrderNotFound => 'Заказ не найден';
  @override
  String get bossOrderSent => 'Заказ отправлен! Агенты работают...';
  @override
  String get bossCommand => 'Команда';
  @override
  String get bossAgent => 'Агент';
  @override
  String get bossProcessing => 'Обработка';
  @override
  String get bossCompleted => 'Завершено';
  @override
  String get bossFailed => 'Ошибка';
  @override
  String get bossQueued => 'В очереди';
  @override
  String get bossAvgTime => 'Среднее время';
  @override
  String get bossJustNow => 'Только что';
  @override
  String get bossDone => 'Готово';
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
  String get bossFullAudit => 'Полный аудит';
  @override
  String get bossSecurityCheck => 'Проверка безопасности';
  @override
  String get bossCompetitorAnalysis => 'Анализ конкурентов';
  @override
  String get bossGrowthIdeas => 'Идеи роста';
  @override
  String get bossFindBugs => 'Найти ошибки';
  @override
  String get bossInvestorPrep => 'Подготовка инвесторов';
  @override
  String get bossSendEmailReport => 'Отправить отчет по email';
  @override
  String get bossSelectAgent => 'Выбрать агента';
  @override
  String bossCommandInitiated({required String command}) => '$command инициирована!';
  @override
  String bossTokenCount({required String tokens}) => '$tokens токе';
  @override
  String bossTotalTokens({required String total}) => '$total токенов';
  @override
  String get monetizationTitle => 'Панель доходов';
  @override
  String commentsTitle({required String count}) => 'Комментарии ($count)';
  @override
  String get commentsNone => 'Пока нет комментариев';
  @override
  String get commentsBeFirst => 'Будьте первым, кто прокомментирует!';
  @override
  String get commentsAddHint => 'Добавить комментарий...';
  @override
  String commentsReplyTo({required String name}) => 'Ответить $name...';
  @override
  String commentsReplyingTo({required String name}) => 'Ответ для $name';
  @override
  String get commentsReply => 'Ответить';
  @override
  String get commentsLike => 'Лайк';
  @override
  String commentsViewReplies({required String count, required String label}) => 'Просмотреть $count $label';
  @override
  String get commentsReplyLabel => 'ответ';
  @override
  String get commentsRepliesLabel => 'ответы';
  @override
  String get commentsHideReplies => 'Скрыть ответы';
  @override
  String get postCardReportPost => 'Пожаловаться на пост';
  @override
  String get postCardEditPost => 'Редактировать пост';
  @override
  String get postCardDeletePost => 'Удалить пост';
  @override
  String get postCardDeleteConfirm => 'Удалить пост?';
  @override
  String get postCardDeleteWarning => 'Это действие невозможно отменить.';
  @override
  String get postCardSharePost => 'Поделиться постом';
  @override
  String get postCardShareToStory => 'Поделиться с историей';
  @override
  String postCardFeeling({required String mood}) => 'Чувствую $mood';
  @override
  String get postCardGlobal => 'Глобально';
  @override
  String get postCardVideoUnavailable => 'Видео недоступно';
  @override
  String get postCardVideoFailed => 'Не удалось загрузить видео';
  @override
  String get reportTitle => 'Сообщить о контенте';
  @override
  String reportWhy({required String type}) => 'Почему вы сообщаете об этом $type?';
  @override
  String get reportFalseInfo => 'Ложная информация';
  @override
  String get reportHarassment => 'Преследование или издевательство';
  @override
  String get reportHateSpeech => 'Речь ненависти';
  @override
  String get reportNudity => 'Наготье или сексуальный контент';
  @override
  String get reportSpam => 'Спам';
  @override
  String get reportScam => 'Мошенничество';
  @override
  String get reportViolence => 'Насилие или угрозы';
  @override
  String get reportOther => 'Другое';
  @override
  String get reportDetailsHint => 'Добавить детали (опционально)...';
  @override
  String get reportSubmit => 'Отправить отчет';
  @override
  String get reportSubmitted => 'Отчет отправлен. Спасибо!';
  @override
  String get reportFailed => 'Не удалось отправить отчет';
  @override
  String get storyRowYourStory => 'Ваша история';
  @override
  String get storyRowAddStory => 'Добавить историю';
  @override
  String get gifSearchHint => 'Поиск GIF';
  @override
  String get gifNoResults => 'GIF не найдены';
  @override
  String get gifPoweredBy => 'Работает на GIPHY';
  @override
  String get unreadCount99Plus => '99+';
  @override
  String get incomingCallAudio => 'Входящий аудиовызов...';
  @override
  String get incomingCallVideo => 'Входящий видеовызов...';
  @override
  String get highlightsNew => 'Новое';
  @override
  String get highlightsNewHighlight => 'Новое выделение';
  @override
  String get highlightsNameHint => 'Название выделения';
  @override
  String get callMissed => 'Пропущенный вызов';
  @override
  String get callBack => 'Перезвонить';
  @override
  String pushNewMessages({required String count}) => '$count новых сообщений';
  @override
  String get pushTypeMessage => 'Введите сообщение...';
  @override
  String get pushNearfoMessage => 'Сообщение Nearfo';
  @override
  String get pushView => 'Просмотр';
  @override
  String get languageTitle => 'Язык';
  @override
  String get languageSubtitle => 'Выберите предпочитаемый язык';
  @override
  String get languageEnglish => 'English';
  @override
  String get languageHindi => 'हिन्दी (Hindi)';
  @override
  String languageChanged({required String language}) => 'Язык изменен на $language';
  @override
  String get digitalAvatarTitle => 'Цифровой аватар';
  @override
  String get digitalAvatarDesc => 'Создайте свой уникальный аватар в стиле мультфильма';
  @override
  String get callScreenConnecting => 'Подключение...';
  @override
  String get callScreenRinging => 'Звонит...';
  @override
  String get callScreenReconnecting => 'Переподключение...';
  @override
  String get callScreenCallEnded => 'Вызов завершен';
  @override
  String percentage({required String value}) => '$value%';
  @override
  String get settingsEditProfile => 'Редактировать профиль';
  @override
  String get settingsWhoCanSee => 'Кто может видеть ваш контент';
  @override
  String get settingsLanguage => 'Язык';
  @override
  String get settingsSignOut => 'Выйти';
  @override
  String get settingsEarningsDashboard => 'Панель доходов';
  @override
  String get settingsAdminPanel => 'Панель администратора';
  @override
  String get settingsPersonalizeExperience => 'Персонализируйте свой опыт Nearfo';
  @override
  String get settingsOnlineFailed => 'Не удалось обновить статус онлайн';
}
