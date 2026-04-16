import 'app_localizations.dart';

class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([super.locale = 'zh']);

  @override
  String get appName => 'Nearfo';
  @override
  String get tagline => '了解你的圈子';
  @override
  String get somethingWentWrong => '出错了';
  @override
  String get signingIn => '正在登录...';
  @override
  String get loading => '正在加载...';
  @override
  String get cancel => '取消';
  @override
  String get save => '保存';
  @override
  String get delete => '删除';
  @override
  String get create => '创建';
  @override
  String get done => '完成';
  @override
  String get retry => '重试';
  @override
  String get ok => '确定';
  @override
  String get yes => '是';
  @override
  String get no => '否';
  @override
  String get or => '或';
  @override
  String get search => '搜索';
  @override
  String get submit => '提交';
  @override
  String get close => '关闭';
  @override
  String get back => '返回';
  @override
  String get next => '下一个';
  @override
  String get more => '更多';
  @override
  String get remove => '移除';
  @override
  String get block => '屏蔽';
  @override
  String get unblock => '取消屏蔽';
  @override
  String get mute => '静音';
  @override
  String get unmute => '取消静音';
  @override
  String get report => '举报';
  @override
  String get share => '分享';
  @override
  String get edit => '编辑';
  @override
  String get post => '发布';
  @override
  String get follow => '关注';
  @override
  String get unfollow => '取消关注';
  @override
  String get message => '消息';
  @override
  String get accept => '接受';
  @override
  String get decline => '拒绝';
  @override
  String get continue_ => '继续';
  @override
  String get stop => '停止';
  @override
  String get use => '使用';
  @override
  String get splashLogoLetter => 'N';
  @override
  String get splashAppName => 'nearfo';
  @override
  String get onboardingSkip => '跳过';
  @override
  String get onboardingTitle1 => '超本地化信息流';
  @override
  String get onboardingDesc1 => '80% 本地内容（100-500公里可调范围）。
发现你周围发生的事。';
  @override
  String get onboardingTitle2 => '了解你的圈子';
  @override
  String get onboardingDesc2 => '与你身边的真实人士联系。
建立你的本地社区。';
  @override
  String get onboardingTitle3 => '走向全球';
  @override
  String get onboardingDesc3 => '20% 来自世界各地的热门内容。
与世界保持联系。';
  @override
  String get onboardingGetStarted => '开始使用';
  @override
  String get loginWelcome => '欢迎来到 Nearfo';
  @override
  String get loginSubtitle => '登录以与你身边的人联系。';
  @override
  String get loginContinueWithGoogle => '使用 Google 继续';
  @override
  String get loginContinueWithPhone => '使用电话号码继续';
  @override
  String get loginEnterMobile => '输入手机号码';
  @override
  String get loginSendOtp => '发送 OTP';
  @override
  String get loginTermsAgreement => '继续即表示你同意我们的服务条款和隐私政策';
  @override
  String get loginTermsOfService => '服务条款';
  @override
  String get loginPrivacyPolicy => '隐私政策';
  @override
  String get loginInvalidPhone => '输入有效的10位电话号码';
  @override
  String get otpTitle => '验证 OTP';
  @override
  String otpSubtitle({required String phone}) => '输入通过短信发送到 $phone 的6位代码';
  @override
  String get otpVerify => '验证';
  @override
  String get otpIncomplete => '输入完整的6位 OTP';
  @override
  String get otpResent => 'OTP 已重新发送!';
  @override
  String get otpResend => '重新发送 OTP';
  @override
  String get otpPhoneMissing => '电话号码丢失。返回并重试。';
  @override
  String otpDevCode({required String otp}) => '开发 OTP: $otp';
  @override
  String get permissionsTitle => '启用权限';
  @override
  String get permissionsSubtitle => 'Nearfo 需要一些权限来为你提供最佳体验，包括基于位置的功能、通知和媒体分享。';
  @override
  String get permissionLocation => '位置';
  @override
  String get permissionLocationDesc => '查找你附近的人和帖子';
  @override
  String get permissionNotifications => '通知';
  @override
  String get permissionNotificationsDesc => '获取点赞、评论和消息的提醒';
  @override
  String get permissionCamera => '相机';
  @override
  String get permissionCameraDesc => '为帖子和个人资料拍照';
  @override
  String get permissionPhotos => '照片和媒体';
  @override
  String get permissionPhotosDesc => '在帖子中分享照片和视频';
  @override
  String get permissionsAllowAll => '允许所有权限';
  @override
  String get permissionsRequestingLocation => '正在请求位置...';
  @override
  String get permissionsRequestingNotifications => '正在请求通知...';
  @override
  String get permissionsRequestingCamera => '正在请求相机...';
  @override
  String get permissionsRequestingMedia => '正在请求媒体...';
  @override
  String get permissionsAllDone => '全部完成!';
  @override
  String get permissionsSettingUp => '正在设置...';
  @override
  String get permissionsSkip => '暂时跳过';
  @override
  String get setupTitle => '建立你的风格';
  @override
  String get setupSubtitle => '告诉我们关于你自己。这有助于附近的人找到你。';
  @override
  String get setupFullName => '全名';
  @override
  String get setupEnterName => '输入你的名字';
  @override
  String get setupUsername => '用户名';
  @override
  String get setupUsernamePlaceholder => 'your_username';
  @override
  String get setupUsernamePrefix => '@';
  @override
  String get setupBio => '个人简介（可选）';
  @override
  String get setupBioPlaceholder => '你的风格是什么？';
  @override
  String get setupDob => '出生日期';
  @override
  String get setupDobPlaceholder => '选择你的出生日期';
  @override
  String get setupShowBirthday => '在个人资料上显示生日';
  @override
  String get setupLocation => '位置';
  @override
  String get setupGettingLocation => '正在获取位置...';
  @override
  String get setupTapToEnable => '点击启用位置';
  @override
  String get setupEnable => '启用';
  @override
  String get setupLocationNote => '你的位置启用超本地化信息流（100-500公里可调）。它永远不会被公开共享。';
  @override
  String get setupStartVibing => '开始分享';
  @override
  String get setupNameRequired => '名字是必需的';
  @override
  String get setupHandleMinLength => '用户名必须至少为3个字符';
  @override
  String get setupLocationRequired => '请启用位置访问';
  @override
  String get navHome => '首页';
  @override
  String get navDiscover => '发现';
  @override
  String get navReels => '视频';
  @override
  String get navChat => '聊天';
  @override
  String get navProfile => '个人资料';
  @override
  String get homeAppName => 'Nearfo';
  @override
  String get homeFollowing => '关注中';
  @override
  String get homeLocal => '本地';
  @override
  String get homeGlobal => '全球';
  @override
  String get homeMixed => '混合';
  @override
  String homeRadiusActive({required String radius}) => '$radius公里范围内活跃';
  @override
  String get homeLive => '直播';
  @override
  String get homeNoVibes => '还没有分享!';
  @override
  String get homeBeFirst => '成为你所在地区的第一个发布者';
  @override
  String get homeEditPost => '编辑帖子';
  @override
  String get homeEditPostHint => '编辑你的帖子...';
  @override
  String get homePostDeleted => '帖子已删除';
  @override
  String get homeDeleteFailed => '删除帖子失败';
  @override
  String get homeSharedToStory => '已分享到你的故事!';
  @override
  String get composeTitle => '新分享';
  @override
  String get composeHint => '你今天的心情如何？';
  @override
  String get composePhoto => '照片';
  @override
  String composePhotoCount({required String count}) => '照片 ($count)';
  @override
  String get composeVideo => '视频';
  @override
  String get composeLocation => '位置';
  @override
  String get composeMood => '心情';
  @override
  String get composeMoodHappy => '开心';
  @override
  String get composeMoodCool => '酷';
  @override
  String get composeMoodFire => '火热';
  @override
  String get composeMoodSleepy => '困倦';
  @override
  String get composeMoodThinking => '思考';
  @override
  String get composeMoodAngry => '愤怒';
  @override
  String get composeMoodParty => '派对';
  @override
  String get composeMoodLove => '爱';
  @override
  String get composeWriteSomething => '写点什么或添加照片/视频!';
  @override
  String get composeRemovePhotosFirst => '先删除照片再添加视频';
  @override
  String get composeRemoveVideoFirst => '先删除视频再添加照片';
  @override
  String get composeVideoTooLarge => '视频太大。请选择更短的视频。';
  @override
  String get composeOptimizingVideo => '正在优化视频';
  @override
  String get composeConvertingTo720p => '正在转换为720p以获得最佳质量';
  @override
  String composeVideoOptimized({required String mb}) => '视频已优化! 已保存 $mbMB';
  @override
  String composeVideoStillLarge({required String mb}) => '压缩后视频仍为 $mbMB。最大75MB。请尝试更短的视频。';
  @override
  String get composeVideoTimeout => '视频上传超时。请尝试更短的视频或检查你的连接。';
  @override
  String get composeImageUploadFailed => '图像上传失败';
  @override
  String get composeUploadTimeout => '上传超时。检查你的连接并重试。';
  @override
  String get composePosted => '已发布!';
  @override
  String composeVideoPreviewError({required String error}) => '无法加载视频预览: $error';
  @override
  String get discoverTitle => '发现';
  @override
  String get discoverSearchHint => '按名字或@用户名搜索朋友...';
  @override
  String get discoverTabViral => '热门';
  @override
  String get discoverTabGlobal => '全球';
  @override
  String get discoverTabSuggested => '推荐';
  @override
  String get discoverTabMap => '地图';
  @override
  String get discoverTabTrending => '趋势';
  @override
  String get discoverTabPeople => '人物';
  @override
  String get discoverViralNow => '现在热门';
  @override
  String get discoverOneHour => '1小时';
  @override
  String get discoverSixHours => '6小时';
  @override
  String get discoverTwentyFourHours => '24小时';
  @override
  String get discoverSevenDays => '7天';
  @override
  String get discoverThirtyDays => '30天';
  @override
  String get discoverLocal => '本地';
  @override
  String get discoverGlobal => '全球';
  @override
  String get chatTitle => '聊天';
  @override
  String get chatNewMessage => '新消息';
  @override
  String get chatSearchConversations => '搜索会话';
  @override
  String get chatNoConversations => '还没有会话';
  @override
  String get chatStartChatting => '开始与你身边的人聊天!';
  @override
  String get chatSearchByName => '按名字或@用户名搜索';
  @override
  String get chatPinChat => '固定聊天';
  @override
  String get chatPinned => '聊天已固定';
  @override
  String get chatUnpinned => '聊天已取消固定';
  @override
  String get chatMuteNotifications => '静音通知';
  @override
  String get chatNotificationsMuted => '通知已静音';
  @override
  String get chatNotificationsUnmuted => '通知已取消静音';
  @override
  String get chatArchive => '存档聊天';
  @override
  String get chatArchived => '聊天已存档';
  @override
  String get chatDeleteConversation => '删除会话';
  @override
  String get chatDeleteConversationTitle => '删除会话？';
  @override
  String chatDeleteConversationMsg({required String name}) => '这将永久删除与 $name 的整个会话。此操作无法撤销。';
  @override
  String get chatUndo => '撤销';
  @override
  String get chatConversationDeleted => '会话已删除';
  @override
  String get chatOnline => '在线';
  @override
  String get chatJustNow => '刚才';
  @override
  String get chatTo => '至: ';
  @override
  String get chatActiveNow => '现在活跃';
  @override
  String get chatSaySomething => '说点什么...';
  @override
  String get chatCalling => '正在拨打...';
  @override
  String get chatNoAnswer => '无应答';
  @override
  String get chatCannotConnect => '无法连接到服务器。检查你的网络。';
  @override
  String chatScreenshotAlert({required String user}) => '$user 对此聊天进行了截图';
  @override
  String chatMessageRequests({required String count, required String plural}) => '$count 条消息请求$plural';
  @override
  String get chatAcceptAndRemove => '接受并移除';
  @override
  String get chatApproveAndRemove => '批准并移除';
  @override
  String get chatThemeBerry => '莓果';
  @override
  String get chatThemeDefault => '默认';
  @override
  String get chatThemeOcean => '海洋';
  @override
  String get chatThemeSunset => '日落';
  @override
  String get chatThemeForest => '森林';
  @override
  String get chatThemeGold => '黄金';
  @override
  String get chatThemeLavender => '薰衣草';
  @override
  String get chatThemeMidnight => '午夜';
  @override
  String get chatMediaCamera => '相机';
  @override
  String get chatMediaPhoto => '照片';
  @override
  String get chatMediaVideo => '视频';
  @override
  String get chatMediaAudio => '音频';
  @override
  String get chatMediaGif => 'GIF';
  @override
  String get chatSettingsProfile => '个人资料';
  @override
  String get chatSettingsSearch => '搜索';
  @override
  String get chatSettingsTheme => '主题';
  @override
  String get chatSettingsNicknames => '昵称';
  @override
  String get chatSettingsCustomNicknamesSet => '自定义昵称已设置';
  @override
  String get chatSettingsSetNicknames => '设置昵称';
  @override
  String get chatSettingsDisappearing => '消失消息';
  @override
  String get chatSettingsDisappearingOff => '关闭';
  @override
  String get chatSettingsDisappearing24h => '24小时';
  @override
  String get chatSettingsDisappearing7d => '7天';
  @override
  String get chatSettingsDisappearing90d => '90天';
  @override
  String get chatSettingsPrivacy => '隐私和安全';
  @override
  String get chatSettingsPrivacyDesc => '加密、数据';
  @override
  String get chatSettingsEncrypted => '加密消息';
  @override
  String get chatSettingsEncryptedDesc => '消息使用 AES-256 加密并安全存储。';
  @override
  String get chatSettingsCreateGroup => '创建群聊';
  @override
  String get chatSettingsCreateGroupBtn => '创建群组';
  @override
  String chatSettingsBlockUser({required String name}) => '屏蔽 $name？';
  @override
  String chatSettingsUserBlocked({required String name}) => '$name 已屏蔽';
  @override
  String chatSettingsUserRestricted({required String name}) => '$name 已受限';
  @override
  String get chatSettingsRestrictionDesc => '限制: 他们可以给你发消息，但回复会进入消息请求';
  @override
  String chatSettingsHideOnline({required String name}) => '对 $name 隐藏在线状态';
  @override
  String chatSettingsCanSeeOnline({required String name}) => '$name 可以看到你的在线状态';
  @override
  String chatSettingsCannotSeeOnline({required String name}) => '$name 看不到你何时活跃';
  @override
  String get chatSettingsChatDeleted => '聊天已删除';
  @override
  String get chatSettingsChatMuted => '聊天已静音';
  @override
  String get chatSettingsChatUnmuted => '聊天已取消静音';
  @override
  String get chatSettingsFailedDelete => '删除聊天失败';
  @override
  String get chatSettingsFailedOnline => '更新在线状态失败';
  @override
  String get chatSettingsFailedBlock => '更新屏蔽状态失败';
  @override
  String get chatSettingsFailedRestriction => '更新限制失败';
  @override
  String get chatSettingsFailedVisibility => '更新可见性失败';
  @override
  String get chatSettingsReportFakeAccount => '虚假账户';
  @override
  String get chatSettingsReportHarassment => '骚扰';
  @override
  String get chatSettingsReportInappropriate => '不当内容';
  @override
  String get chatSettingsFailedReport => '提交举报失败';
  @override
  String get profileTitle => '个人资料';
  @override
  String get profilePosts => '帖子';
  @override
  String get profileFollowers => '粉丝';
  @override
  String get profileFollowing => '关注中';
  @override
  String get profileAdminPanel => '管理面板';
  @override
  String get profileAnalytics => '分析';
  @override
  String get profileEarnings => '收益面板';
  @override
  String get profileGoPremium => '升级到 Premium';
  @override
  String get profileMyCircle => '我的圈子';
  @override
  String get profileSavedPosts => '保存的帖子';
  @override
  String get profileSavedReels => '保存的视频';
  @override
  String get profileSignOut => '登出';
  @override
  String get profileEditProfile => '编辑个人资料';
  @override
  String get profileNearfoScore => 'Nearfo 评分';
  @override
  String get profileNearfoScoreDesc => '你的本地影响力和参与度';
  @override
  String get profilePro => 'PRO';
  @override
  String get profileOwner => '所有者';
  @override
  String get profilePremium => 'Premium';
  @override
  String get editProfileTitle => '编辑个人资料';
  @override
  String get editProfileDisplayName => '显示名称';
  @override
  String get editProfileUsername => '用户名';
  @override
  String get editProfileUsernameRequired => '用户名是必需的';
  @override
  String get editProfileUsernameMinLength => '用户名必须至少为3个字符';
  @override
  String get editProfileUsernameInvalid => '仅限字母、数字和下划线';
  @override
  String get editProfileNameRequired => '名字是必需的';
  @override
  String get editProfileNameMinLength => '名字必须至少为2个字符';
  @override
  String get editProfileBio => '个人简介';
  @override
  String get editProfileBioHint => '告诉人们关于你...';
  @override
  String get editProfileDob => '出生日期';
  @override
  String get editProfileNotSet => '未设置';
  @override
  String get editProfileLocation => '位置';
  @override
  String get editProfileLocationAutoUpdate => '位置根据你的GPS自动更新';
  @override
  String get editProfileChangePhoto => '更改照片';
  @override
  String get editProfileTakePhoto => '拍照';
  @override
  String get editProfileChooseGallery => '从相册中选择';
  @override
  String get editProfileCreateAvatar => '创建数字化身';
  @override
  String get editProfileAvatarDesc => '卡通风格的个人资料图片';
  @override
  String get editProfileTapToSelect => '点击选择';
  @override
  String get editProfileUpdated => '个人资料已更新!';
  @override
  String get editProfilePhotoUpdated => '照片已更新!';
  @override
  String get editProfileUploadFailed => '上传失败';
  @override
  String editProfileError({required String error}) => '错误: $error';
  @override
  String get editProfileFailed => '更新个人资料失败';
  @override
  String get userProfileNoPosts => '还没有帖子';
  @override
  String get userProfileBlockUser => '屏蔽用户';
  @override
  String get userProfileBlockConfirm => '屏蔽用户？';
  @override
  String get userProfileUnblockUser => '取消屏蔽用户';
  @override
  String get userProfileUnblockConfirm => '取消屏蔽用户？';
  @override
  String get userProfileLocalInfluence => '本地影响力和参与度';
  @override
  String get userProfileBlocked => '你已屏蔽此用户';
  @override
  String get userProfileBlockedByThem => '你无法与此个人资料互动，因为他们已屏蔽你';
  @override
  String get userProfileUnblockDesc => '他们将能够看到你的个人资料并再次与你互动。';
  @override
  String get userProfileBlockDesc => '他们将无法看到你的个人资料并与你互动。';
  @override
  String get userProfileBlockedSnack => '用户已屏蔽';
  @override
  String get userProfileUnblockedSnack => '用户已取消屏蔽';
  @override
  String get userProfileNotFound => '用户未找到';
  @override
  String get userProfileNoHandle => '未提供句柄或用户ID';
  @override
  String get userProfileFollowFailed => '更新关注状态失败';
  @override
  String get userProfileReportUser => '举报用户';
  @override
  String get userProfileReportSubmitted => '举报已提交';
  @override
  String followersTitle({required String count}) => '粉丝 $count';
  @override
  String followingTitle({required String count}) => '关注中 $count';
  @override
  String get followersLoadMore => '加载更多';
  @override
  String get followersNoFollowers => '还没有粉丝';
  @override
  String get followersNotFollowing => '还未关注任何人';
  @override
  String get followersUserIdMissing => '用户ID丢失';
  @override
  String get notificationsTitle => '通知';
  @override
  String get notificationsNone => '还没有通知';
  @override
  String get notificationsNoneDesc => '当人们与你的分享互动时，
你会看到它在这里';
  @override
  String get notificationsMarkAllRead => '标记全部已读';
  @override
  String get reelsForYou => '为你推荐';
  @override
  String get reelsFollowing => '关注中';
  @override
  String get reelsNearby => '附近';
  @override
  String get reelsNoReels => '还没有视频';
  @override
  String get reelsBeFirst => '成为第一个发布视频的人!';
  @override
  String get reelsLoading => '正在加载视频...';
  @override
  String get reelsShare => '分享视频';
  @override
  String reelsShareText({required String url}) => '来看看 Nearfo 上的这个视频! $url';
  @override
  String get reelsDeleteReel => '删除视频';
  @override
  String get reelsDeleteConfirm => '删除视频？';
  @override
  String get reelsDeleteWarning => '此操作无法撤销。';
  @override
  String get reelsReportReel => '举报视频';
  @override
  String get reelsReportSubmitted => '举报已提交';
  @override
  String reelsOriginalAudio({required String name}) => '原始音频 - $name';
  @override
  String get createReelTitle => '创建新视频';
  @override
  String get createReelRecord => '录制视频';
  @override
  String get createReelRecordDesc => '使用相机录制新视频';
  @override
  String get createReelSelect => '选择现有视频';
  @override
  String get createReelUploadPhoto => '上传照片';
  @override
  String get createReelPhotoDesc => '从相册创建照片视频';
  @override
  String get createReelSettings => '设置';
  @override
  String get createReelWhoCanSee => '谁可以看到';
  @override
  String get createReelEveryone => '所有人';
  @override
  String get createReelNearby => '附近';
  @override
  String get createReelCircle => '圈子';
  @override
  String get createReelSpecs => '视频: 最长90秒 • 720p | 照片: 最大20MB';
  @override
  String get createReelCameraPermission => '需要相机权限';
  @override
  String get createReelGalleryPermission => '需要相册权限';
  @override
  String get createReelPreparingVideo => '正在准备视频...';
  @override
  String get createReelConverting => '正在转换为720p以获得最佳质量...';
  @override
  String get createReelOptimizing => '正在优化视频';
  @override
  String get createReelVideoTooLarge => '视频太大（最大1GB）。请选择更短的视频。';
  @override
  String get createReelImageTooLarge => '图像太大（最大20MB）。请选择更小的图像。';
  @override
  String createReelCompressedTooLarge({required String mb}) => '压缩后视频太大 ($mbMB)。最大75MB。';
  @override
  String createReelCompressionFailed({required String error}) => '压缩失败: $error';
  @override
  String createReelPickVideoFailed({required String error}) => '选择视频失败: $error';
  @override
  String createReelPickImageFailed({required String error}) => '选择图像失败: $error';
  @override
  String get storyLabel => '故事';
  @override
  String get reelLabel => '视频';
  @override
  String get liveLabel => '直播';
  @override
  String get postLabel => '帖子';
  @override
  String get storyMulti => '多张';
  @override
  String get storyBoomerang => '回旋镖';
  @override
  String get storyTapInstruction => '点击按钮拍照
长按30秒视频
或从下面选择相册';
  @override
  String get storyTapShort => '点击拍照 • 长按30秒视频';
  @override
  String get storyTapReel => '点击录制视频';
  @override
  String get storyPhotoPermission => '需要照片库权限';
  @override
  String get storyCameraPermission => '需要相机权限';
  @override
  String get storyGalleryPermission => '需要相册权限';
  @override
  String get storyMaxDuration => '30秒';
  @override
  String get storyLayout => '布局';
  @override
  String get storySettings => '设置';
  @override
  String get storyAddAnother => '再添加一个';
  @override
  String storyProgress({required String current, required String total}) => '故事 $current / $total';
  @override
  String get storyEditEach => '上传前编辑每个故事';
  @override
  String get storyUploaded => '故事已上传!';
  @override
  String get storyAddAnotherQuestion => '要添加另一个故事吗？';
  @override
  String get storyContinueUploading => '要继续上传吗？';
  @override
  String storyUploadedCount({required String uploaded, required String max}) => '已添加 $uploaded / $max 个故事';
  @override
  String get storyMaxReached => '一次最多10个故事';
  @override
  String storyMaxReachedCount({required String count}) => '已上传 $count 个故事! (已达最大值)';
  @override
  String storyAllUploaded({required String count}) => '已上传 $count 个故事!';
  @override
  String storyContinueRemaining({required String done, required String total}) => '已完成 $done / $total 个故事。
你要继续上传剩余的故事吗？';
  @override
  String get storyEditorText => '文本';
  @override
  String get storyEditorStickers => '贴纸';
  @override
  String get storyEditorEffects => '效果';
  @override
  String get storyEditorDraw => '绘制';
  @override
  String get storyEditorMusic => '音乐';
  @override
  String get storyEditorAddMusic => '添加音乐';
  @override
  String get storyEditorAddPoll => '添加投票';
  @override
  String get storyEditorAddQuestion => '添加问题';
  @override
  String get storyEditorAddLink => '添加链接';
  @override
  String get storyEditorAddCountdown => '添加倒计时';
  @override
  String get storyEditorAddMention => '添加提及';
  @override
  String get storyEditorMusicRemoved => '音乐已移除';
  @override
  String get storyEditorSearchMusic => '搜索音乐...';
  @override
  String get storyEditorNoMusic => '未找到音乐';
  @override
  String storyEditorMusicError({required String name}) => '无法播放 "$name"';
  @override
  String get storyEditorCaption => '添加标题...';
  @override
  String get storyEditorTypeQuestion => '输入你的问题';
  @override
  String get storyEditorYourQuestion => '你的问题';
  @override
  String get storyEditorAskQuestion => '提出问题...';
  @override
  String get storyEditorTypeSomething => '输入什么...';
  @override
  String get storyEditorSearchUser => '搜索用户进行提及';
  @override
  String get storyEditorSearchUsers => '搜索用户...';
  @override
  String get storyEditorMentionSomeone => '提及某人';
  @override
  String get storyEditorMention => '提及';
  @override
  String get storyEditorLinkLabel => '链接标签';
  @override
  String get storyEditorLink => '链接';
  @override
  String get storyEditorLinkHint => 'https://...';
  @override
  String get storyEditorCountdownTitle => '添加倒计时';
  @override
  String get storyEditorCountdown => '倒计时';
  @override
  String get storyEditorAiLabels => 'AI 标签';
  @override
  String get storyEditorAiSuggested => 'AI 建议的标签';
  @override
  String get storyEditorHashtag => '话题标签';
  @override
  String get storyEditorPoll => '投票';
  @override
  String get storyEditorQuestion => '问题';
  @override
  String get storyEditorLinkTag => '链接';
  @override
  String get storyEditorMentionTag => '提及';
  @override
  String get storyEditorLocationTag => '位置';
  @override
  String get storyEditorMusicTag => '音乐';
  @override
  String get storyEditorHashtagTag => '话题标签';
  @override
  String get storyEditorOption1 => '选项1';
  @override
  String get storyEditorOption2 => '选项2';
  @override
  String get storyEditorPollLabel => '投票';
  @override
  String get storyEditorCreatePoll => '创建投票';
  @override
  String get storyEditorShares => '分享';
  @override
  String storyEditorLikes({required String count}) => '点赞: $count';
  @override
  String get storyEditorViewers => '查看者';
  @override
  String storyEditorCountdownEnd({required String date}) => '结束: $date';
  @override
  String get storyEditorEventName => '事件名称';
  @override
  String get storyEditorCountdownTag => '倒计时';
  @override
  String get storyEditorDays => '天';
  @override
  String get storyEditorHours => '小时';
  @override
  String get storyEditorCountdownTimer => '倒计时计时器';
  @override
  String get storyEditorRemoveElement => '移除此元素？';
  @override
  String get storyEditorPermanentMarker => '永久标记笔';
  @override
  String get storyEditorNormal => '普通';
  @override
  String get storyEditorFilterDefault => '默认';
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
  String get storyEditorTurnOffCommenting => '关闭评论';
  @override
  String get storyEditorVisibilityEveryone => '所有人';
  @override
  String get storyEditorVisibilityCloseFriends => '亲密朋友';
  @override
  String get storyEditorVisibilityMyCircle => '我的圈子';
  @override
  String get storyEditorVisibilityNearby => '附近';
  @override
  String get storyEditorVisibilityTrending => '趋势';
  @override
  String get storyEditorSaveToGallery => '保存到相册';
  @override
  String get storyEditorSaved => '已保存到相册!';
  @override
  String get storyEditorPostReel => '发布视频';
  @override
  String get storyEditorPostingReel => '正在发布你的视频...';
  @override
  String get storyEditorSharingStory => '正在分享你的故事...';
  @override
  String get storyEditorReelFailed => '视频创建失败';
  @override
  String get storyEditorStoryFailed => '故事创建失败';
  @override
  String get storyEditorImageUploadFailed => '图像上传失败';
  @override
  String get storyEditorVideoUploadFailed => '视频上传失败';
  @override
  String get storyEditorUploadEmptyUrl => '上传返回空URL';
  @override
  String get storyEditorCouldNotSave => '无法保存';
  @override
  String get storiesDeleteStory => '删除故事';
  @override
  String get storiesDeleteConfirm => '删除故事？';
  @override
  String get storiesDeleteWarning => '此故事将永久删除。此操作无法撤销。';
  @override
  String get storiesReportStory => '举报故事';
  @override
  String get storiesDeleted => '故事已删除';
  @override
  String get storiesReported => '故事已举报';
  @override
  String get storiesReplySent => '回复已发送!';
  @override
  String get storiesDeleteFailed => '删除失败';
  @override
  String get storiesNetworkError => '网络错误，请重试';
  @override
  String get storiesSendMessage => '发送消息...';
  @override
  String storiesViewers({required String count}) => '查看者 ($count)';
  @override
  String storiesLikes({required String count}) => '点赞 ($count)';
  @override
  String get storiesNoViewers => '还没有查看者';
  @override
  String get storiesNoLikes => '还没有点赞';
  @override
  String get storiesUnknown => '未知';
  @override
  String get storiesCouldntLoad => '无法加载';
  @override
  String get storiesMediaNotAvailable => '媒体不可用';
  @override
  String get collectionsTitle => '收藏';
  @override
  String get collectionsNone => '还没有收藏';
  @override
  String get collectionsNoneDesc => '将帖子保存到收藏中以组织它们';
  @override
  String get collectionsCreate => '创建收藏';
  @override
  String get collectionsNew => '新收藏';
  @override
  String get collectionsNameHint => '收藏名称';
  @override
  String get collectionsUntitled => '无标题';
  @override
  String collectionsPostCount({required String count}) => '$count 篇帖子';
  @override
  String get collectionsNoPosts => '此收藏中没有帖子';
  @override
  String get collectionsDeleteConfirm => '删除收藏？';
  @override
  String get collectionsDeleteWarning => '此操作无法撤销。';
  @override
  String get savedPostsTitle => '保存的帖子';
  @override
  String get savedPostsNone => '还没有保存的帖子';
  @override
  String get savedPostsNoneDesc => '你保存的帖子会出现在这里';
  @override
  String get savedReelsTitle => '保存的视频';
  @override
  String get savedReelsNone => '还没有保存的视频';
  @override
  String get savedReelsNoneDesc => '你收藏的视频会出现在这里';
  @override
  String get savedReelsRemoveConfirm => '从保存中移除？';
  @override
  String get savedReelsRemoveDesc => '此视频将从你的保存列表中移除。';
  @override
  String get liveStartTitle => '开始直播';
  @override
  String get liveStartDesc => '开始直播并与
你身边的人联系!';
  @override
  String get liveYouAreLive => '你正在直播!';
  @override
  String get liveYouAreLiveDesc => '你现在在直播! 观众可以随时加入。';
  @override
  String get liveStreaming => '正在向你的观众直播';
  @override
  String get liveStartStreaming => '开始向你的观众直播';
  @override
  String get liveGoLiveNow => '现在直播';
  @override
  String get liveGoLive => '直播';
  @override
  String get liveTitleHint => '给你的直播起个标题...';
  @override
  String get liveCategoryGeneral => '一般';
  @override
  String get liveCategoryGaming => '游戏';
  @override
  String get liveCategoryMusic => '音乐';
  @override
  String get liveCategoryEducation => '教育';
  @override
  String get liveCategoryFitness => '健身';
  @override
  String get liveCategoryCooking => '烹饪';
  @override
  String get liveCategoryOther => '其他';
  @override
  String get liveCategory => '分类';
  @override
  String liveDuration({required String duration}) => '时长: $duration';
  @override
  String get liveEndConfirm => '结束直播？';
  @override
  String get liveEndStream => '结束直播';
  @override
  String get liveEnd => '结束';
  @override
  String get liveEndWarning => '你的直播将结束，观众将断开连接。';
  @override
  String get liveStreamEnded => '直播已结束';
  @override
  String get liveStreamEndedDesc => '此直播已结束';
  @override
  String get liveNoOneIsLive => '现在没有人在直播';
  @override
  String get liveWatch => '观看';
  @override
  String get liveViewer => '观众';
  @override
  String liveViewers({required String count}) => '观众: $count';
  @override
  String liveLikes({required String count}) => '点赞: $count';
  @override
  String get liveSaySomething => '说点什么...';
  @override
  String get liveChat => '聊天';
  @override
  String get liveChats => '聊天';
  @override
  String get liveLikesTab => '点赞';
  @override
  String get liveViewersTab => '观众';
  @override
  String get liveSystem => '系统';
  @override
  String get liveWelcome => '欢迎来到直播!';
  @override
  String get liveYou => '你';
  @override
  String get liveStartFailed => '启动直播失败';
  @override
  String get liveJustStarted => '刚刚开始';
  @override
  String liveShareText({required String name, required String title}) => '$name 在 Nearfo 上直播! "$title" — 现在加入并观看!';
  @override
  String get hashtagRecent => '最近';
  @override
  String get hashtagTop => '热门';
  @override
  String hashtagPostCount({required String count}) => '$count 篇帖子';
  @override
  String hashtagNoPosts({required String tag}) => '没有包含 #$tag 的帖子';
  @override
  String get myCircleTitle => '我的圈子';
  @override
  String get myCircleNone => '你的圈子中还没有人';
  @override
  String get myCircleNoneDesc => '关注你且你也关注的人';
  @override
  String get myCircleNoneDetail => '你的圈子显示相互追随者 — 你关注且他们也关注你的人。开始关注你身边的人吧!';
  @override
  String get myCircleDiscover => '发现人物';
  @override
  String get myCircleMutual => '相互的';
  @override
  String myCircleCount({required String count, required String label}) => '$count 个相互 $label';
  @override
  String get myCircleConnection => '连接';
  @override
  String get myCircleConnections => '连接';
  @override
  String get messageRequestsTitle => '消息请求';
  @override
  String get messageRequestsNone => '没有消息请求';
  @override
  String get messageRequestsNoneDesc => '当你的关注者列表中没有的人向你发送消息时，它们会先出现在这里。';
  @override
  String get messageRequestsNoNotify => '你不会收到这些消息的通知。';
  @override
  String get messageRequestsSentMessage => '向你发送了消息';
  @override
  String get messageRequestsUser => '用户';
  @override
  String get messageRequestsKeep => '保留';
  @override
  String get messageRequestsDecline => '拒绝';
  @override
  String get messageRequestsDeclineConfirm => '拒绝请求？';
  @override
  String get messageRequestsDeclined => '请求已拒绝';
  @override
  String get messageRequestsAcceptFailed => '接受请求失败';
  @override
  String get messageRequestsDeclineFailed => '拒绝请求失败';
  @override
  String get settingsTitle => '设置';
  @override
  String get settingsAccount => '账户';
  @override
  String settingsEmail({required String email}) => '电子邮件: $email';
  @override
  String settingsPhone({required String phone}) => '电话: $phone';
  @override
  String get settingsNotSetValue => '未设置';
  @override
  String get settingsUpdateEmail => '更新电子邮件';
  @override
  String get settingsUpdatePhone => '更新电话号码';
  @override
  String get settingsEnterEmail => '输入你的新电子邮件地址';
  @override
  String get settingsEnterPhone => '输入你的电话号码';
  @override
  String get settingsValidEmail => '请输入有效的电子邮件';
  @override
  String get settingsValidPhone => '请输入电话号码';
  @override
  String get settingsSaveEmail => '保存电子邮件';
  @override
  String get settingsSavePhone => '保存电话号码';
  @override
  String get settingsEmailUpdated => '电子邮件已更新!';
  @override
  String get settingsPhoneUpdated => '电话号码已更新!';
  @override
  String get settingsPreferences => '偏好';
  @override
  String get settingsFeedPreference => '信息流偏好';
  @override
  String settingsFeedPreferenceValue({required String value}) => '信息流偏好: $value';
  @override
  String get settingsFeedDesc => '选择你的信息流组织方式';
  @override
  String get settingsFeedNearby => '本地优先';
  @override
  String get settingsFeedTrending => '趋势';
  @override
  String get settingsFeedMixed => '混合';
  @override
  String get settingsFeedMixedDesc => '本地和趋势帖子的混合';
  @override
  String get settingsFeedNearbyDesc => '优先显示你身边的人的帖子';
  @override
  String get settingsFeedTrendingDesc => '首先显示趋势帖子';
  @override
  String get settingsProfileVisibility => '个人资料可见性';
  @override
  String settingsProfileVisibilityValue({required String value}) => '个人资料可见性: $value';
  @override
  String get settingsProfileVisibilityDesc => '谁可以看到你的个人资料';
  @override
  String get settingsPublic => '公开';
  @override
  String get settingsPublicDesc => '所有人都可以看到你的个人资料';
  @override
  String get settingsPrivate => '私密';
  @override
  String get settingsPrivateDesc => '只有你可以看到你的个人资料详情';
  @override
  String get settingsFollowersOnly => '仅粉丝';
  @override
  String get settingsFollowersOnlyDesc => '只有你的粉丝可以看到你的完整个人资料';
  @override
  String get settingsActivityFriends => '好友标签页中的活动';
  @override
  String get settingsActivityFriendsDesc => '控制你的活动可见性';
  @override
  String get settingsShowNewFollows => '显示新关注';
  @override
  String get settingsShowNewFollowsDesc => '好友可以看到你关注了谁';
  @override
  String get settingsShowComments => '显示评论';
  @override
  String get settingsShowCommentsDesc => '好友可以看到你的评论';
  @override
  String get settingsShowLikedPosts => '显示点赞的帖子';
  @override
  String get settingsShowLikedPostsDesc => '好友可以看到你点赞过的帖子';
  @override
  String get settingsShowOnline => '显示在线状态';
  @override
  String get settingsOnlineVisible => '在线状态可见。其他人可以看到你何时活跃。';
  @override
  String get settingsOnlineHidden => '在线状态隐藏。你将对所有人显示为离线。';
  @override
  String get settingsShowBirthday => '在个人资料上显示生日';
  @override
  String get settingsVisibilityPublic => '可见性设置为公开';
  @override
  String get settingsVisibilityPrivate => '可见性设置为私密';
  @override
  String get settingsVisibilityFollowers => '可见性设置为仅粉丝';
  @override
  String get settingsStoryLiveLocation => '故事、直播和位置';
  @override
  String get settingsStoryLiveLocationDesc => '控制谁可以看到你的故事和位置';
  @override
  String get settingsAllowStoryReplies => '允许故事回复';
  @override
  String get settingsAllowStoryRepliesDesc => '所有人都可以回复你的故事';
  @override
  String get settingsShowLocationStories => '在故事中显示位置';
  @override
  String get settingsShowLocationStoriesDesc => '你的城市在你的故事中可见';
  @override
  String get settingsLiveNotifications => '直播通知';
  @override
  String get settingsLiveNotificationsDesc => '当朋友开始直播时获取通知';
  @override
  String get settingsLocation => '位置';
  @override
  String settingsRadius({required String radius}) => '范围: $radius公里 (在发现中可调)';
  @override
  String get settingsLocationUpdated => '位置已更新!';
  @override
  String get settingsLocationError => '无法获取位置。检查GPS和权限。';
  @override
  String settingsLocationErrorDetail({required String error}) => '位置错误: $error';
  @override
  String get settingsNotifications => '通知';
  @override
  String get settingsNotificationsEnabled => '通知已启用';
  @override
  String get settingsNotificationsDisabled => '通知已禁用';
  @override
  String get settingsTheme => '主题';
  @override
  String settingsThemeValue({required String name}) => '主题: $name';
  @override
  String get settingsChooseTheme => '选择主题';
  @override
  String get settingsApp => '应用';
  @override
  String get settingsHelpImprove => '帮助我们改进 Nearfo';
  @override
  String get settingsReportBug => '报告错误';
  @override
  String get settingsReportBugHint => '描述你找到的错误...';
  @override
  String get settingsSubmitReport => '提交报告';
  @override
  String get settingsBugReportSubmitted => '错误报告已提交! 谢谢。';
  @override
  String get settingsCouldNotOpenLink => '无法打开链接';
  @override
  String get settingsPrivacyPolicy => '隐私政策';
  @override
  String get settingsTermsOfService => '服务条款';
  @override
  String get settingsAbout => '关于 Nearfo';
  @override
  String get settingsVersion => 'Nearfo v1.0.0';
  @override
  String get settingsAccountPrivacy => '账户隐私';
  @override
  String get settingsAccountPrivacyDesc => '账户隐私';
  @override
  String get settingsBlocked => '已屏蔽';
  @override
  String get settingsBlockedUsers => '已屏蔽用户';
  @override
  String get settingsHideFollowersList => '隐藏粉丝/关注列表';
  @override
  String get settingsFollowersVisible => '粉丝/关注列表对所有人可见。';
  @override
  String get settingsFollowersHidden => '粉丝/关注列表已隐藏。仅显示数字。';
  @override
  String get settingsAdmin => '管理';
  @override
  String get settingsModeration => '审核 (屏蔽/DMCA)';
  @override
  String get settingsMonetization => '变现';
  @override
  String get settingsCopyrightReport => '举报版权侵犯';
  @override
  String get settingsDeleteAccount => '删除账户';
  @override
  String get settingsDeleteAccountConfirm => '确定吗? 这将永久删除你的账户、帖子和所有数据。此操作无法撤销。';
  @override
  String get settingsDeleteAccountSent => '账户删除请求已发送。我们将在24小时内处理。';
  @override
  String get settingsFailedOnlineStatus => '更新在线状态失败';
  @override
  String get settingsFeedSetMixed => '信息流设置为混合';
  @override
  String get settingsFeedSetNearby => '信息流设置为本地优先';
  @override
  String get settingsFeedSetTrending => '信息流设置为趋势';
  @override
  String get accountPrivacyTitle => '账户隐私';
  @override
  String get accountPrivacyPublicSet => '账户设置为公开';
  @override
  String get accountPrivacyPrivateSet => '账户设置为私密';
  @override
  String get accountPrivacyPublicTitle => '公开账户';
  @override
  String get accountPrivacyPrivateTitle => '私密账户';
  @override
  String get accountPrivacyPublicShort => '所有人都可以看到你的帖子和个人资料';
  @override
  String get accountPrivacyPublicDesc => '所有人都可以看到你的帖子、故事和个人资料。人们可以在不需要批准的情况下关注你。';
  @override
  String get accountPrivacyPrivateShort => '只有获得批准的粉丝可以看到你的帖子';
  @override
  String get accountPrivacyPrivateDesc => '只有你批准的粉丝可以看到你的帖子和故事。你的个人资料信息对非粉丝隐藏。';
  @override
  String get accountPrivacyWhenPublic => '当你的账户为公开时';
  @override
  String get accountPrivacyWhenPrivate => '当你的账户为私密时';
  @override
  String get accountPrivacySwitchNote => '切换到私密不会影响现有粉丝。';
  @override
  String get accountPrivacyNote => '注意';
  @override
  String get premiumTitle => '升级到 Premium';
  @override
  String get premiumSubtitle => 'Nearfo Premium';
  @override
  String get premiumDesc => '解锁完整的 Nearfo 体验';
  @override
  String get premiumChoosePlan => '选择你的计划';
  @override
  String get premiumChoosePlanBtn => '选择计划';
  @override
  String get premiumMonthly => '月度';
  @override
  String get premiumYearly => '年度';
  @override
  String get premiumLifetime => '终身';
  @override
  String get premiumPopular => '热门';
  @override
  String get premiumVerifiedBadge => '认证徽章';
  @override
  String get premiumVerifiedBadgeDesc => '用认证资料脱颖而出';
  @override
  String get premiumAdFree => '无广告体验';
  @override
  String get premiumAdFreeDesc => '无中断地浏览';
  @override
  String get premiumPriorityFeed => '优先级信息流';
  @override
  String get premiumPriorityFeedDesc => '你的帖子在本地获得提升';
  @override
  String get premiumCustomThemes => '自定义主题';
  @override
  String get premiumCustomThemesDesc => '个性化你的个人资料外观';
  @override
  String get premiumUnlockChatTheme => '解锁自定义聊天主题';
  @override
  String get premiumAdvancedAnalytics => '高级分析';
  @override
  String get premiumAdvancedAnalyticsDesc => '深入了解你的覆盖范围';
  @override
  String get premiumPrioritySupport => '优先支持';
  @override
  String get premiumPrioritySupportDesc => '需要时更快地获得帮助';
  @override
  String get premiumSeeProfileViews => '查看谁查看了你的个人资料';
  @override
  String get premiumEverythingMonthly => '月度中的所有内容';
  @override
  String get premiumEverythingForever => '永远的所有内容';
  @override
  String get premiumFoundingBadge => '创始人徽章';
  @override
  String get premiumEarlyAccess => '提前访问功能';
  @override
  String get premiumGetStarted => '开始使用';
  @override
  String premiumRewardUnlocked({required String label}) => '奖励已解锁! $label';
  @override
  String get premiumWatchAdsDesc => '通过观看短广告获得免费的高级功能';
  @override
  String get premiumWatchAdsTitle => '观看广告，赚取奖励!';
  @override
  String get premiumWatchAdToUnlock => '观看广告以解锁';
  @override
  String get premiumWatchAdToBoost => '观看广告以提升';
  @override
  String get premiumBoostPost => '提升你的帖子1小时';
  @override
  String get premiumSaveYearly => '节省 ₹389!';
  @override
  String get premiumPaymentComingSoon => '支付集成即将推出。现在观看广告以解锁功能!';
  @override
  String get premiumAdLoading => '广告正在加载，请稍后重试...';
  @override
  String get premiumPriceMonthly => '₹99';
  @override
  String get premiumPriceYearly => '₹799';
  @override
  String get premiumPriceLifetime => '₹1,999';
  @override
  String get premiumPerMonth => '/月';
  @override
  String get premiumPerYear => '/年';
  @override
  String get premiumOneTime => '一次性';
  @override
  String get analyticsTitle => '分析';
  @override
  String get analyticsOverview => '概览';
  @override
  String get analyticsPosts => '帖子';
  @override
  String get analyticsReels => '视频';
  @override
  String get analyticsThisWeek => '本周';
  @override
  String get analyticsPostsCreated => '创建的帖子';
  @override
  String get analyticsReelsUploaded => '上传的视频';
  @override
  String get analyticsTotalLikes => '总点赞数';
  @override
  String get analyticsComments => '评论';
  @override
  String get analyticsEngagement => '参与度';
  @override
  String get analyticsFollowers => '粉丝';
  @override
  String get analyticsFollowing => '关注中';
  @override
  String get analyticsNewFollowers => '新粉丝';
  @override
  String get analyticsReelViews => '视频浏览量';
  @override
  String get analyticsLegend => '图例';
  @override
  String get analyticsNewcomer => '新手';
  @override
  String get analyticsRising => '上升中';
  @override
  String get analyticsStar => '明星';
  @override
  String get analyticsActive => '活跃';
  @override
  String get analyticsCouldNotLoad => '无法加载分析';
  @override
  String get analyticsTipToGrow => '增长提示';
  @override
  String get analyticsGreatStart => '你开局很棒!';
  @override
  String get analyticsNewcomerTip => '开局很好! 尝试发布视频 — 它们获得更多浏览量并帮助增加参与度。';
  @override
  String get analyticsAlmostThere => '差不多了! 你的内容表现很好。保持势头!';
  @override
  String get analyticsKeepPosting => '继续发布和与社区互动以提高你的评分!';
  @override
  String get analyticsRisingCreator => '你是一位冉冉升起的创作者!';
  @override
  String get nearfoScoreTitle => 'Nearfo 评分';
  @override
  String get nearfoScoreDesc => '你的本地影响力和参与度评分';
  @override
  String get nearfoScoreOutOf => '/100';
  @override
  String get nearfoScoreBreakdown => '评分明细';
  @override
  String get nearfoScoreTipToImprove => '改进提示';
  @override
  String get nearfoScoreActivity => '活动';
  @override
  String get nearfoScoreActivityTip => '每天保持活跃 — 点赞、评论和分享帖子以增加你的活动评分。';
  @override
  String get nearfoScorePosts => '帖子';
  @override
  String get nearfoScoreReels => '视频';
  @override
  String get nearfoScoreFollowers => '粉丝';
  @override
  String get nearfoScoreEngagement => '参与度';
  @override
  String get nearfoScoreFollowersTip => '关注你所在地区的人并与他们的内容互动 — 他们会回关你!';
  @override
  String get nearfoScorePostsTip => '尝试更频繁地发布! 与你的本地社区分享照片、想法和更新。';
  @override
  String get nearfoScoreReelsTip => '创建短视频以提高你的知名度并接触你身边的更多人。';
  @override
  String get nearfoScoreEngagementTip => '编写引人入胜的标题并回复评论以提高你的参与率。';
  @override
  String get nearfoScoreWelcome => '欢迎! 开始发布以增长';
  @override
  String get nearfoScoreGettingStarted => '开始使用! 发布更多';
  @override
  String get nearfoScoreGoodStart => '很好的开始! 继续互动';
  @override
  String get nearfoScoreGreat => '很棒! 你正在建立动力';
  @override
  String get nearfoScoreExcellent => '优秀! 你是本地影响者';
  @override
  String get blockedUsersTitle => '已屏蔽用户';
  @override
  String get blockedUsersNone => '没有已屏蔽的用户';
  @override
  String get blockedUsersNoneDesc => '你屏蔽的用户会出现在这里';
  @override
  String blockedUsersUnblocked({required String name}) => '$name 已取消屏蔽';
  @override
  String get blockedUsersUnblockTitle => '取消屏蔽用户';
  @override
  String blockedUsersUnblockConfirm({required String name}) => '你确定要取消屏蔽 $name 吗? 他们将能够看到你的个人资料并再次与你互动。';
  @override
  String get createGroupTitle => '创建群组';
  @override
  String get createGroupNameHint => '群组名称';
  @override
  String get createGroupNameRequired => '需要群组名称';
  @override
  String get createGroupDescHint => '描述 (可选)';
  @override
  String get createGroupSearchHint => '搜索人员以添加...';
  @override
  String get createGroupMinMembers => '至少选择2个成员';
  @override
  String get createGroupFailed => '失败';
  @override
  String get groupInfoEditGroup => '编辑群组';
  @override
  String get groupInfoMembers => '成员';
  @override
  String groupInfoMemberCount({required String count}) => '$count 个成员';
  @override
  String get groupInfoAddMembers => '添加成员';
  @override
  String get groupInfoAdd => '添加';
  @override
  String get groupInfoSearchHint => '搜索人员...';
  @override
  String get groupInfoAdmin => '管理';
  @override
  String get groupInfoViewProfile => '查看个人资料';
  @override
  String get groupInfoRemoveFromGroup => '从群组中移除';
  @override
  String groupInfoMemberRemoved({required String name}) => '已移除 $name';
  @override
  String groupInfoRemoveConfirm({required String name}) => '移除 $name 吗?';
  @override
  String get groupInfoRemoveDesc => '他们将无法在此群组中发送或接收消息。';
  @override
  String get groupInfoMuteToggled => '已切换静音';
  @override
  String get groupInfoLeaveGroup => '离开群组';
  @override
  String get groupInfoLeaveConfirm => '离开群组？';
  @override
  String get groupInfoLeaveDesc => '你将不再收到来自此群组的消息。此操作无法撤销。';
  @override
  String get groupInfoLeaveShort => '你将不再收到消息';
  @override
  String get groupInfoLeave => '离开';
  @override
  String get groupInfoLeaveFailed => '离开群组失败';
  @override
  String groupInfoUserAdded({required String name}) => '已添加 $name';
  @override
  String groupInfoYou({required String name}) => '$name (你)';
  @override
  String get copyrightTitle => '举报版权';
  @override
  String get copyrightDesc => '如果有人在未获得许可的情况下发布了你的受版权保护的内容，请填写此表格以请求删除。';
  @override
  String get copyrightYourName => '你的名字';
  @override
  String get copyrightNameHint => '输入你的全名';
  @override
  String get copyrightYourEmail => '你的电子邮件';
  @override
  String get copyrightEmailHint => '输入你的电子邮件';
  @override
  String get copyrightContentType => '内容类型';
  @override
  String get copyrightTypePost => '帖子';
  @override
  String get copyrightTypeReel => '视频';
  @override
  String get copyrightTypeStory => '故事';
  @override
  String get copyrightTypeComment => '评论';
  @override
  String get copyrightContentId => '内容ID';
  @override
  String get copyrightContentIdHint => '侵犯帖子/视频的ID';
  @override
  String get copyrightDescription => '描述';
  @override
  String get copyrightDescHint => '描述你的版权是如何被侵犯的';
  @override
  String get copyrightOriginalUrl => '原始作品URL';
  @override
  String get copyrightOriginalUrlHint => '链接到你的原始作品 (可选)';
  @override
  String get copyrightSwornStatement => '我在作伪证的处罚下宣誓，本通知中的信息是准确的，我是版权所有者或被授权代表他们行动。';
  @override
  String get copyrightMustConfirm => '你必须确认宣誓声明';
  @override
  String get copyrightSubmit => '提交 DMCA 报告';
  @override
  String get copyrightRequired => '必需';
  @override
  String get copyrightSubmitted => 'DMCA 报告已提交。我们将在48小时内审核。';
  @override
  String get copyrightFailed => '提交失败';
  @override
  String get moderationTitle => '审核';
  @override
  String moderationTakedowns({required String count}) => '移除 ($count)';
  @override
  String moderationBanned({required String count}) => '已屏蔽 ($count)';
  @override
  String get moderationNoPendingTakedowns => '没有待处理的移除';
  @override
  String get moderationNoBannedUsers => '没有已屏蔽的用户';
  @override
  String get moderationReason => '原因';
  @override
  String moderationType({required String type}) => '类型: $type';
  @override
  String get moderationDuration => '时长';
  @override
  String get moderationDuration24h => '24小时';
  @override
  String get moderationDuration3d => '3天';
  @override
  String get moderationDuration7d => '7天';
  @override
  String get moderationDuration30d => '30天';
  @override
  String get moderationSuspend => '暂停';
  @override
  String get moderationSuspendUser => '暂停用户';
  @override
  String get moderationBan => '屏蔽';
  @override
  String get moderationBanUser => '屏蔽用户';
  @override
  String get moderationReject => '拒绝';
  @override
  String get moderationUnban => '取消屏蔽';
  @override
  String get moderationTakedownApproved => '移除已批准。内容已删除。';
  @override
  String get moderationTakedownRejected => '移除已拒绝';
  @override
  String get moderationUserBanned => '用户已屏蔽';
  @override
  String get moderationUserSuspended => '用户已暂停';
  @override
  String get moderationUserUnbanned => '用户已取消屏蔽';
  @override
  String get moderationUnknown => '未知';
  @override
  String get moderationUserId => '用户ID';
  @override
  String get adminTitle => '管理面板';
  @override
  String get adminDashboard => '仪表板';
  @override
  String get adminTotalUsers => '总用户数';
  @override
  String get adminPostsToday => '今日帖子数';
  @override
  String get adminReelsToday => '今日视频数';
  @override
  String get adminOnlineUsers => '在线用户';
  @override
  String get adminPendingReports => '待处理举报';
  @override
  String get adminReports => '举报';
  @override
  String get adminActiveStories => '活跃故事';
  @override
  String get adminAiAgents => 'AI 代理';
  @override
  String get adminSearchUsers => '按名字或电子邮件搜索用户...';
  @override
  String get adminUsers => '用户';
  @override
  String get adminVerified => '已验证';
  @override
  String get adminUnverified => '未验证';
  @override
  String get adminVerify => '验证';
  @override
  String get adminUnverify => '取消验证';
  @override
  String adminReportFrom({required String name}) => '来自 $name 的报告';
  @override
  String get adminNoReason => '未提供原因';
  @override
  String get adminDismiss => '关闭';
  @override
  String get adminReportDismissed => '报告已关闭';
  @override
  String get adminTakeAction => '采取行动';
  @override
  String get adminContentType => '内容类型';
  @override
  String get adminContentHidden => '内容已成功隐藏';
  @override
  String get adminNoDescription => '没有描述';
  @override
  String get adminNoPendingReports => '没有待处理的报告';
  @override
  String adminErrorLoadingReports({required String error}) => '加载报告错误: $error';
  @override
  String adminErrorLoadingDashboard({required String error}) => '加载仪表板错误: $error';
  @override
  String adminErrorLoadingUsers({required String error}) => '加载用户错误: $error';
  @override
  String adminErrorTakingAction({required String error}) => '采取行动错误: $error';
  @override
  String adminErrorDismissing({required String error}) => '关闭报告错误: $error';
  @override
  String adminErrorUpdatingUser({required String error}) => '更新用户错误: $error';
  @override
  String get adminNoData => '没有可用数据';
  @override
  String get adminNoEmail => '无电子邮件';
  @override
  String get adminNoUsers => '未找到用户';
  @override
  String get adminTotalMessages => '总消息数';
  @override
  String get adminTotalFollows => '总关注数';
  @override
  String get adminAnonymous => '匿名';
  @override
  String get bossAllAgents => '所有代理';
  @override
  String get bossQuickCommands => '快速命令';
  @override
  String get bossOrders => '订单';
  @override
  String get bossFirstCommand => '在上面给出你的第一条命令!';
  @override
  String get bossNoOrders => '还没有订单';
  @override
  String get bossOrderNotFound => '订单未找到';
  @override
  String get bossOrderSent => '订单已发送! 代理正在工作...';
  @override
  String get bossCommand => '命令';
  @override
  String get bossAgent => '代理';
  @override
  String get bossProcessing => '处理中';
  @override
  String get bossCompleted => '已完成';
  @override
  String get bossFailed => '失败';
  @override
  String get bossQueued => '队列中';
  @override
  String get bossAvgTime => '平均时间';
  @override
  String get bossJustNow => '刚才';
  @override
  String get bossDone => '完成';
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
  String get bossFullAudit => '完整审计';
  @override
  String get bossSecurityCheck => '安全检查';
  @override
  String get bossCompetitorAnalysis => '竞争对手分析';
  @override
  String get bossGrowthIdeas => '增长创意';
  @override
  String get bossFindBugs => '查找错误';
  @override
  String get bossInvestorPrep => '投资者准备';
  @override
  String get bossSendEmailReport => '发送电子邮件报告';
  @override
  String get bossSelectAgent => '选择代理';
  @override
  String bossCommandInitiated({required String command}) => '$command 已启动!';
  @override
  String bossTokenCount({required String tokens}) => '$tokens 个令牌';
  @override
  String bossTotalTokens({required String total}) => '$total 个令牌';
  @override
  String get monetizationTitle => '收益面板';
  @override
  String commentsTitle({required String count}) => '评论 ($count)';
  @override
  String get commentsNone => '还没有评论';
  @override
  String get commentsBeFirst => '成为第一个评论的人!';
  @override
  String get commentsAddHint => '添加评论...';
  @override
  String commentsReplyTo({required String name}) => '回复 $name...';
  @override
  String commentsReplyingTo({required String name}) => '回复给 $name';
  @override
  String get commentsReply => '回复';
  @override
  String get commentsLike => '点赞';
  @override
  String commentsViewReplies({required String count, required String label}) => '查看 $count 条 $label';
  @override
  String get commentsReplyLabel => '回复';
  @override
  String get commentsRepliesLabel => '回复';
  @override
  String get commentsHideReplies => '隐藏回复';
  @override
  String get postCardReportPost => '举报帖子';
  @override
  String get postCardEditPost => '编辑帖子';
  @override
  String get postCardDeletePost => '删除帖子';
  @override
  String get postCardDeleteConfirm => '删除帖子？';
  @override
  String get postCardDeleteWarning => '此操作无法撤销。';
  @override
  String get postCardSharePost => '分享帖子';
  @override
  String get postCardShareToStory => '分享到故事';
  @override
  String postCardFeeling({required String mood}) => '感觉 $mood';
  @override
  String get postCardGlobal => '全球';
  @override
  String get postCardVideoUnavailable => '视频不可用';
  @override
  String get postCardVideoFailed => '视频加载失败';
  @override
  String get reportTitle => '举报内容';
  @override
  String reportWhy({required String type}) => '你为什么举报这个 $type？';
  @override
  String get reportFalseInfo => '虚假信息';
  @override
  String get reportHarassment => '骚扰或欺凌';
  @override
  String get reportHateSpeech => '仇恨言论';
  @override
  String get reportNudity => '裸露或性内容';
  @override
  String get reportSpam => '垃圾邮件';
  @override
  String get reportScam => '诈骗或欺诈';
  @override
  String get reportViolence => '暴力或威胁';
  @override
  String get reportOther => '其他';
  @override
  String get reportDetailsHint => '添加详情 (可选)...';
  @override
  String get reportSubmit => '提交举报';
  @override
  String get reportSubmitted => '举报已提交。谢谢!';
  @override
  String get reportFailed => '举报失败';
  @override
  String get storyRowYourStory => '你的故事';
  @override
  String get storyRowAddStory => '添加故事';
  @override
  String get gifSearchHint => '搜索 GIF';
  @override
  String get gifNoResults => '未找到 GIF';
  @override
  String get gifPoweredBy => '由 GIPHY 提供支持';
  @override
  String get unreadCount99Plus => '99+';
  @override
  String get incomingCallAudio => '来电语音通话...';
  @override
  String get incomingCallVideo => '来电视频通话...';
  @override
  String get highlightsNew => '新的';
  @override
  String get highlightsNewHighlight => '新亮点';
  @override
  String get highlightsNameHint => '亮点名称';
  @override
  String get callMissed => '未接来电';
  @override
  String get callBack => '回拨';
  @override
  String pushNewMessages({required String count}) => '$count 条新消息';
  @override
  String get pushTypeMessage => '输入消息...';
  @override
  String get pushNearfoMessage => 'Nearfo 消息';
  @override
  String get pushView => '查看';
  @override
  String get languageTitle => '语言';
  @override
  String get languageSubtitle => '选择你的首选语言';
  @override
  String get languageEnglish => 'English';
  @override
  String get languageHindi => 'हिन्दी (Hindi)';
  @override
  String languageChanged({required String language}) => '语言已更改为 $language';
  @override
  String get digitalAvatarTitle => '数字化身';
  @override
  String get digitalAvatarDesc => '创建你独特的卡通风格化身';
  @override
  String get callScreenConnecting => '正在连接...';
  @override
  String get callScreenRinging => '正在拨号...';
  @override
  String get callScreenReconnecting => '正在重新连接...';
  @override
  String get callScreenCallEnded => '通话已结束';
  @override
  String percentage({required String value}) => '$value%';
  @override
  String get settingsEditProfile => '编辑个人资料';
  @override
  String get settingsWhoCanSee => '谁可以看到你的内容';
  @override
  String get settingsLanguage => '语言';
  @override
  String get settingsSignOut => '登出';
  @override
  String get settingsEarningsDashboard => '收益仪表板';
  @override
  String get settingsAdminPanel => '管理面板';
  @override
  String get settingsPersonalizeExperience => '个性化你的Nearfo体验';
  @override
  String get settingsOnlineFailed => '无法更新在线状态';
}
