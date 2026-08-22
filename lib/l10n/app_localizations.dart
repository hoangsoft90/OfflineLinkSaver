import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;



/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by [AppLocalizations.of(context)].
///
/// Applications need to include [AppLocalizations.delegate()] in their app's
/// [localizationsDelegates] list, and the locales they support in the
/// [supportedLocales] list.
class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
    Locale('zh'),
  ];

  // ── App ──

  String get appTitle => _resolve('appTitle');

  // ── Home tabs ──

  String get homeTabAll => _resolve('homeTabAll');
  String get homeTabUnread => _resolve('homeTabUnread');
  String get homeTabDownloaded => _resolve('homeTabDownloaded');

  // ── Home screen ──

  String get searchHint => _resolve('searchHint');
  String get emptyStateTitle => _resolve('emptyStateTitle');
  String get emptyStateBody => _resolve('emptyStateBody');
  String get pasteUrl => _resolve('pasteUrl');

  // ── Add URL dialog ──

  String get addUrlTitle => _resolve('addUrlTitle');
  String get addUrlHint => _resolve('addUrlHint');
  String get save => _resolve('save');
  String get cancel => _resolve('cancel');
  String get delete => _resolve('delete');
  String get urlAlreadySaved => _resolve('urlAlreadySaved');
  String get savedSuccess => _resolve('savedSuccess');

  String errorSavingUrl(String error) => _resolve('errorSavingUrl', error: error);
  String errorLoadingArticles(String error) => _resolve('errorLoadingArticles', error: error);

  // ── Delete dialog ──

  String get deleteArticleTitle => _resolve('deleteArticleTitle');
  String deleteArticleConfirm(String title) => _resolve('deleteArticleConfirm', title: title);

  // ── Download ──

  String get noUnreadToDownload => _resolve('noUnreadToDownload');
  String queuedCount(int count) => _resolve('queuedCount', count: count.toString());
  String get downloadQueued => _resolve('downloadQueued');
  String get download => _resolve('download');

  // ── Category ──

  String get category => _resolve('category');
  String get none => _resolve('none');
  String get addCategory => _resolve('addCategory');
  String get editCategory => _resolve('editCategory');
  String get manageCategories => _resolve('manageCategories');
  String get deleteCategory => _resolve('deleteCategory');
  String deleteCategoryConfirm(String name) => _resolve('deleteCategoryConfirm', name: name);
  String get noCategories => _resolve('noCategories');
  String get categoryNameHint => _resolve('categoryNameHint');
  String get manage => _resolve('manage');
  String get noCategory => _resolve('noCategory');

  // ── Filter ──

  String get filterFavorites => _resolve('filterFavorites');
  String get clearFilters => _resolve('clearFilters');

  // ── Reader ──

  String get readerContentNotAvailable => _resolve('readerContentNotAvailable');
  String get readerContentFileMissing => _resolve('readerContentFileMissing');
  String readerFailedToLoad(String error) => _resolve('readerFailedToLoad', error: error);
  String get readerOpenInBrowser => _resolve('readerOpenInBrowser');
  String get readerNoContent => _resolve('readerNoContent');
  String get readerFooter => _resolve('readerFooter');

  // ── Settings ──

  String get settingsTitle => _resolve('settingsTitle');
  String get settingsStorage => _resolve('settingsStorage');
  String get settingsTotalArticles => _resolve('settingsTotalArticles');
  String get settingsStorageUsed => _resolve('settingsStorageUsed');
  String get settingsAbout => _resolve('settingsAbout');
  String settingsVersion(String version) => _resolve('settingsVersion', version: version);
  String get settingsPrivacy => _resolve('settingsPrivacy');
  String get settingsPrivacyText => _resolve('settingsPrivacyText');
  String get settingsSupport => _resolve('settingsSupport');
  String get settingsHelp => _resolve('settingsHelp');
  String get settingsReportBug => _resolve('settingsReportBug');
  String get settingsLanguage => _resolve('settingsLanguage');

  // ── Article card ──

  String articleAuthor(String author) => _resolve('articleAuthor', author: author);
  String articlePercentRead(int percent) => _resolve('articlePercentRead', percent: percent.toString());

  // ── Disabled state ──

  String get disabledFeatureLocked => _resolve('disabledFeatureLocked');
  String get disabledGotIt => _resolve('disabledGotIt');

  // ── Onboarding ──

  String get onboardingSearchTitle => _resolve('onboardingSearchTitle');
  String get onboardingSearchMessage => _resolve('onboardingSearchMessage');
  String get onboardingDownloadAllTitle => _resolve('onboardingDownloadAllTitle');
  String get onboardingDownloadAllMessage => _resolve('onboardingDownloadAllMessage');
  String get onboardingAddUrlTitle => _resolve('onboardingAddUrlTitle');
  String get onboardingAddUrlMessage => _resolve('onboardingAddUrlMessage');
  String get onboardingNext => _resolve('onboardingNext');
  String get onboardingSkip => _resolve('onboardingSkip');
  String get onboardingDone => _resolve('onboardingDone');

  // ── Badge ──

  String get badgeNew => _resolve('badgeNew');

  // ── Status ──

  String get statusQueued => _resolve('statusQueued');
  String get statusDownloading => _resolve('statusDownloading');
  String get statusProcessing => _resolve('statusProcessing');
  String get statusReady => _resolve('statusReady');
  String get statusFailed => _resolve('statusFailed');
  String get statusOnlineOnly => _resolve('statusOnlineOnly');
  String get statusRetry => _resolve('statusRetry');

  // ── Internal ──

  String _resolve(String key, {String? error, String? title, String? version, String? author, String? percent, String? count, String? name}) {
    final map = _localeMap;
    final value = map[key];
    if (value == null) return '[$key]';

    String result = value;
    if (error != null) result = result.replaceAll('{error}', error);
    if (title != null) result = result.replaceAll('{title}', title);
    if (version != null) result = result.replaceAll('{version}', version);
    if (author != null) result = result.replaceAll('{author}', author);
    if (percent != null) result = result.replaceAll('{percent}', percent);
    if (count != null) result = result.replaceAll('{count}', count);
    if (name != null) result = result.replaceAll('{name}', name);
    return result;
  }

  Map<String, String> get _localeMap {
    switch (localeName) {
      case 'vi':
        return _vi;
      case 'zh':
        return _zh;
      default:
        return _en;
    }
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale.toString()));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'vi', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// ── English strings ──

const Map<String, String> _en = {
  'appTitle': 'ThinkSave',
  'homeTabAll': 'All',
  'homeTabUnread': 'Unread',
  'homeTabDownloaded': 'Downloaded',
  'searchHint': 'Search articles...',
  'emptyStateTitle': 'No articles yet',
  'emptyStateBody': 'Share a link from Chrome, Facebook, or Telegram\nto save it for offline reading.',
  'pasteUrl': 'Paste URL',
  'addUrlTitle': 'Add URL',
  'addUrlHint': 'Paste URL here...',
  'save': 'Save',
  'cancel': 'Cancel',
  'delete': 'Delete',
  'urlAlreadySaved': 'URL already saved',
  'savedSuccess': '✓ Saved',
  'errorSavingUrl': 'Error saving URL: {error}',
  'errorLoadingArticles': 'Error loading articles: {error}',
  'deleteArticleTitle': 'Delete Article',
  'deleteArticleConfirm': 'Delete "{title}"? This cannot be undone.',
  'noUnreadToDownload': 'No unread articles to download',
  'queuedCount': 'Queued {count} articles for download',
  'downloadQueued': 'Queued for download',
  'download': 'Download',
  'category': 'Category',
  'none': 'None',
  'addCategory': 'Add Category',
  'editCategory': 'Edit Category',
  'manageCategories': 'Manage Categories',
  'deleteCategory': 'Delete Category',
  'deleteCategoryConfirm': 'Delete "{name}" category? Articles will be uncategorized.',
  'noCategories': 'No categories yet',
  'categoryNameHint': 'Category name...',
  'manage': 'Manage',
  'noCategory': 'No category',
  'filterFavorites': 'Favorites',
  'clearFilters': 'Clear',
  'readerContentNotAvailable': 'Content not available',
  'readerContentFileMissing': 'Content file missing',
  'readerFailedToLoad': 'Failed to load content: {error}',
  'readerOpenInBrowser': 'Open in Browser',
  'readerNoContent': 'No content available',
  'readerFooter': 'Saved with ThinkSave',
  'settingsTitle': 'Settings',
  'settingsStorage': 'Storage',
  'settingsTotalArticles': 'Total Articles',
  'settingsStorageUsed': 'Storage Used',
  'settingsAbout': 'About',
  'settingsVersion': 'Version {version}',
  'settingsPrivacy': 'Privacy Policy',
  'settingsPrivacyText': 'Saved content is stored locally on your device. The app does not upload your library to a cloud account. No account required.',
  'settingsSupport': 'Support',
  'settingsHelp': 'Help & FAQ',
  'settingsReportBug': 'Report a Bug',
  'settingsLanguage': 'Language',
  'articleAuthor': 'by {author}',
  'articlePercentRead': '{percent}% read',
  'disabledFeatureLocked': 'Feature Locked',
  'disabledGotIt': 'Got it',
  'onboardingSearchTitle': 'Search Your Library',
  'onboardingSearchMessage': 'Quickly find any article by title or domain using the search bar.',
  'onboardingDownloadAllTitle': 'Download All Unread',
  'onboardingDownloadAllMessage': 'Tap this button to queue all unread articles for offline download at once.',
  'onboardingAddUrlTitle': 'Add a Link',
  'onboardingAddUrlMessage': 'Tap here to paste any URL. The app will save it for offline reading.',
  'onboardingNext': 'Next',
  'onboardingSkip': 'Skip',
  'onboardingDone': 'Done',
  'badgeNew': 'New',
  'statusQueued': 'Queued',
  'statusDownloading': 'Downloading…',
  'statusProcessing': 'Processing…',
  'statusReady': 'Offline ready',
  'statusFailed': 'Failed',
  'statusOnlineOnly': 'Online only',
  'statusRetry': 'Retry',
};

// ── Vietnamese strings ──

const Map<String, String> _vi = {
  'appTitle': 'ThinkSave',
  'homeTabAll': 'Tất cả',
  'homeTabUnread': 'Chưa đọc',
  'homeTabDownloaded': 'Đã tải',
  'searchHint': 'Tìm kiếm bài viết...',
  'emptyStateTitle': 'Chưa có bài viết nào',
  'emptyStateBody': 'Chia sẻ liên kết từ Chrome, Facebook hoặc Telegram\nđể lưu đọc offline.',
  'pasteUrl': 'Dán URL',
  'addUrlTitle': 'Thêm URL',
  'addUrlHint': 'Dán URL vào đây...',
  'save': 'Lưu',
  'cancel': 'Hủy',
  'delete': 'Xóa',
  'urlAlreadySaved': 'URL đã được lưu',
  'savedSuccess': '✓ Đã lưu',
  'errorSavingUrl': 'Lỗi lưu URL: {error}',
  'errorLoadingArticles': 'Lỗi tải bài viết: {error}',
  'deleteArticleTitle': 'Xóa bài viết',
  'deleteArticleConfirm': 'Xóa "{title}"? Hành động này không thể hoàn tác.',
  'noUnreadToDownload': 'Không có bài viết chưa đọc để tải',
  'queuedCount': 'Đã thêm {count} bài viết vào hàng tải',
  'downloadQueued': 'Đã thêm vào hàng tải',
  'download': 'Tải',
  'category': 'Danh mục',
  'none': 'Không có',
  'addCategory': 'Thêm danh mục',
  'editCategory': 'Sửa danh mục',
  'manageCategories': 'Quản lý danh mục',
  'deleteCategory': 'Xóa danh mục',
  'deleteCategoryConfirm': 'Xóa danh mục "{name}"? Các bài viết sẽ được chuyển về không có danh mục.',
  'noCategories': 'Chưa có danh mục nào',
  'categoryNameHint': 'Tên danh mục...',
  'manage': 'Quản lý',
  'noCategory': 'Không có danh mục',
  'filterFavorites': 'Yêu thích',
  'clearFilters': 'Xóa bộ lọc',
  'readerContentNotAvailable': 'Nội dung không khả dụng',
  'readerContentFileMissing': 'File nội dung bị thiếu',
  'readerFailedToLoad': 'Không thể tải nội dung: {error}',
  'readerOpenInBrowser': 'Mở trong trình duyệt',
  'readerNoContent': 'Không có nội dung',
  'readerFooter': 'Đã lưu với ThinkSave',
  'settingsTitle': 'Cài đặt',
  'settingsStorage': 'Bộ nhớ',
  'settingsTotalArticles': 'Tổng số bài viết',
  'settingsStorageUsed': 'Dung lượng đã dùng',
  'settingsAbout': 'Thông tin',
  'settingsVersion': 'Phiên bản {version}',
  'settingsPrivacy': 'Chính sách bảo mật',
  'settingsPrivacyText': 'Nội dung đã lưu được lưu trữ cục bộ trên thiết bị. Ứng dụng không tải thư viện lên đám mây. Không yêu cầu tài khoản.',
  'settingsSupport': 'Hỗ trợ',
  'settingsHelp': 'Trợ giúp & FAQ',
  'settingsReportBug': 'Báo lỗi',
  'settingsLanguage': 'Ngôn ngữ',
  'articleAuthor': 'bởi {author}',
  'articlePercentRead': 'đã đọc {percent}%',
  'disabledFeatureLocked': 'Tính năng bị khóa',
  'disabledGotIt': 'Đã hiểu',
  'onboardingSearchTitle': 'Tìm trong thư viện',
  'onboardingSearchMessage': 'Tìm nhanh bất kỳ bài viết nào theo tiêu đề hoặc tên miền.',
  'onboardingDownloadAllTitle': 'Tải tất cả chưa đọc',
  'onboardingDownloadAllMessage': 'Nhấn nút này để thêm tất cả bài viết chưa đọc vào hàng tải offline.',
  'onboardingAddUrlTitle': 'Thêm liên kết',
  'onboardingAddUrlMessage': 'Nhấn đây để dán bất kỳ URL nào. Ứng dụng sẽ lưu để đọc offline.',
  'onboardingNext': 'Tiếp theo',
  'onboardingSkip': 'Bỏ qua',
  'onboardingDone': 'Xong',
  'badgeNew': 'Mới',
  'statusQueued': 'Đang chờ',
  'statusDownloading': 'Đang tải…',
  'statusProcessing': 'Đang xử lý…',
  'statusReady': 'Sẵn sàng offline',
  'statusFailed': 'Thất bại',
  'statusOnlineOnly': 'Chỉ online',
  'statusRetry': 'Thử lại',
};

// ── Chinese (Simplified) strings ──

const Map<String, String> _zh = {
  'appTitle': 'ThinkSave',
  'homeTabAll': '全部',
  'homeTabUnread': '未读',
  'homeTabDownloaded': '已下载',
  'searchHint': '搜索文章...',
  'emptyStateTitle': '暂无文章',
  'emptyStateBody': '从 Chrome、Facebook 或 Telegram 分享链接\n即可离线保存阅读。',
  'pasteUrl': '粘贴链接',
  'addUrlTitle': '添加 URL',
  'addUrlHint': '在此粘贴 URL...',
  'save': '保存',
  'cancel': '取消',
  'delete': '删除',
  'urlAlreadySaved': 'URL 已保存',
  'savedSuccess': '✓ 已保存',
  'errorSavingUrl': '保存 URL 失败：{error}',
  'errorLoadingArticles': '加载文章失败：{error}',
  'deleteArticleTitle': '删除文章',
  'deleteArticleConfirm': '删除「{title}」？此操作不可撤销。',
  'noUnreadToDownload': '没有未读文章可下载',
  'queuedCount': '已将 {count} 篇文章加入下载队列',
  'downloadQueued': '已加入下载队列',
  'download': '下载',
  'category': '分类',
  'none': '无',
  'addCategory': '添加分类',
  'editCategory': '编辑分类',
  'manageCategories': '管理分类',
  'deleteCategory': '删除分类',
  'deleteCategoryConfirm': '删除分类「{name}」？文章将变为未分类。',
  'noCategories': '暂无分类',
  'categoryNameHint': '分类名称...',
  'manage': '管理',
  'noCategory': '无分类',
  'filterFavorites': '收藏',
  'clearFilters': '清除',
  'readerContentNotAvailable': '内容不可用',
  'readerContentFileMissing': '内容文件缺失',
  'readerFailedToLoad': '加载内容失败：{error}',
  'readerOpenInBrowser': '在浏览器中打开',
  'readerNoContent': '没有可用内容',
  'readerFooter': '通过 ThinkSave 保存',
  'settingsTitle': '设置',
  'settingsStorage': '存储',
  'settingsTotalArticles': '文章总数',
  'settingsStorageUsed': '已用空间',
  'settingsAbout': '关于',
  'settingsVersion': '版本 {version}',
  'settingsPrivacy': '隐私政策',
  'settingsPrivacyText': '保存的内容仅存储在您的设备上。本应用不会将您的库上传到云端，无需账户。',
  'settingsSupport': '支持',
  'settingsHelp': '帮助与常见问题',
  'settingsReportBug': '报告错误',
  'settingsLanguage': '语言',
  'articleAuthor': '作者：{author}',
  'articlePercentRead': '已读 {percent}%',
  'disabledFeatureLocked': '功能已锁定',
  'disabledGotIt': '知道了',
  'onboardingSearchTitle': '搜索您的库',
  'onboardingSearchMessage': '使用搜索栏快速查找任何文章标题或域名。',
  'onboardingDownloadAllTitle': '下载全部未读',
  'onboardingDownloadAllMessage': '点击此按钮将所有未读文章加入离线下载队列。',
  'onboardingAddUrlTitle': '添加链接',
  'onboardingAddUrlMessage': '点击此处粘贴任意 URL，应用将保存以供离线阅读。',
  'onboardingNext': '下一步',
  'onboardingSkip': '跳过',
  'onboardingDone': '完成',
  'badgeNew': '新',
  'statusQueued': '排队中',
  'statusDownloading': '下载中…',
  'statusProcessing': '处理中…',
  'statusReady': '可离线阅读',
  'statusFailed': '失败',
  'statusOnlineOnly': '仅在线',
  'statusRetry': '重试',
};
