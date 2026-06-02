import 'package:flutter/material.dart';

class ChatTheme {
  /// Scaffold / screen background
  final Color scaffoldColor;

  /// App bar and bottom sheet background
  final Color appBarColor;

  /// Üst AppBar arka planı. Verilmezse [appBarColor] kullanılır.
  /// Host uygulama markasıyla eşleştirmek için override edilebilir.
  final Color appBarBackgroundColor;

  /// Üst AppBar üzerindeki başlık ve ikon rengi. Verilmezse [textColor].
  final Color appBarForegroundColor;

  /// Input field and secondary surface background
  final Color inputColor;

  /// Dividers, separators
  final Color dividerColor;

  /// Accent / primary color — send button, unread badge, reply accent
  final Color primaryColor;

  /// My message bubble background
  final Color myBubbleColor;

  /// Other person's message bubble background
  final Color otherBubbleColor;

  /// Primary text (on dark surfaces)
  final Color textColor;

  /// Secondary / muted text
  final Color textMutedColor;

  /// Icon tint on surfaces
  final Color iconColor;

  const ChatTheme({
    required this.scaffoldColor,
    required this.appBarColor,
    required this.inputColor,
    required this.dividerColor,
    required this.primaryColor,
    required this.myBubbleColor,
    required this.otherBubbleColor,
    required this.textColor,
    required this.textMutedColor,
    required this.iconColor,
    required this.appBarBackgroundColor,
    required this.appBarForegroundColor,
  });

  /// Default dark theme — matches the original design
  const ChatTheme.dark()
      : scaffoldColor = const Color(0xFF0F0F0F),
        appBarColor = const Color(0xFF1A1A1A),
        appBarBackgroundColor = const Color(0xFF1A1A1A),
        appBarForegroundColor = Colors.white,
        inputColor = const Color(0xFF2A2A2A),
        dividerColor = const Color(0xFF2A2A2A),
        primaryColor = const Color(0xFF4CAF50),
        myBubbleColor = const Color(0xFF2A5C3F),
        otherBubbleColor = const Color(0xFF1E1E1E),
        textColor = Colors.white,
        textMutedColor = Colors.white54,
        iconColor = Colors.white70;

  /// Light theme preset
  const ChatTheme.light()
      : scaffoldColor = const Color(0xFFEEEEEE),
        appBarColor = const Color(0xFFFFFFFF),
        appBarBackgroundColor = const Color(0xFFFFFFFF),
        appBarForegroundColor = const Color(0xFF202020),
        inputColor = const Color(0xFFF0F0F0),
        dividerColor = const Color(0xFFE8E8E8),
        primaryColor = const Color(0xFF4CAF50),
        myBubbleColor = const Color(0xFFDCF8C6),
        otherBubbleColor = const Color(0xFFFFFFFF),
        textColor = const Color(0xFF202020),
        textMutedColor = const Color(0xFF757575),
        iconColor = const Color(0xFF424242);

  ChatTheme copyWith({
    Color? scaffoldColor,
    Color? appBarColor,
    Color? appBarBackgroundColor,
    Color? appBarForegroundColor,
    Color? inputColor,
    Color? dividerColor,
    Color? primaryColor,
    Color? myBubbleColor,
    Color? otherBubbleColor,
    Color? textColor,
    Color? textMutedColor,
    Color? iconColor,
  }) =>
      ChatTheme(
        scaffoldColor: scaffoldColor ?? this.scaffoldColor,
        appBarColor: appBarColor ?? this.appBarColor,
        appBarBackgroundColor: appBarBackgroundColor ?? this.appBarBackgroundColor,
        appBarForegroundColor: appBarForegroundColor ?? this.appBarForegroundColor,
        inputColor: inputColor ?? this.inputColor,
        dividerColor: dividerColor ?? this.dividerColor,
        primaryColor: primaryColor ?? this.primaryColor,
        myBubbleColor: myBubbleColor ?? this.myBubbleColor,
        otherBubbleColor: otherBubbleColor ?? this.otherBubbleColor,
        textColor: textColor ?? this.textColor,
        textMutedColor: textMutedColor ?? this.textMutedColor,
        iconColor: iconColor ?? this.iconColor,
      );
}

class _ChatThemeScope extends InheritedWidget {
  final ChatTheme theme;
  const _ChatThemeScope({required this.theme, required super.child});

  @override
  bool updateShouldNotify(_ChatThemeScope old) => theme != old.theme;
}

extension ChatThemeContext on BuildContext {
  ChatTheme get chatTheme {
    final scope =
        dependOnInheritedWidgetOfExactType<_ChatThemeScope>();
    assert(scope != null,
        'ChatTheme.of() called outside ChatApp.initialize() scope');
    return scope!.theme;
  }
}

class ChatThemeProvider extends StatelessWidget {
  final ChatTheme theme;
  final Widget child;
  const ChatThemeProvider({
    super.key,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) =>
      _ChatThemeScope(theme: theme, child: child);
}
