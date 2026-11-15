class AppSettings {
  String aiName;
  String model;
  String apiBaseUrl;
  String systemPrompt;
  String rubikaChannelLink;
  String paymentLink;
  String myketLink;
  String paymentAmount;
  int proDurationDays;

  AppSettings({
    this.aiName = 'وارنیکس',
    this.model = 'openrouter/free',
    this.apiBaseUrl = 'https://openrouter.ai/api/v1',
    this.systemPrompt =
        'تو یک دستیار هوشمند فارسی‌زبان به نام وارنیکس هستی. پاسخ‌ها را به زبان فارسی، مفید، دقیق و دوستانه بده.',
    this.rubikaChannelLink = '',
    this.paymentLink = '',
    this.myketLink = '',
    this.paymentAmount = '۱۸۹٬۰۰۰ تومان',
    this.proDurationDays = 40,
  });

  Map<String, dynamic> toJson() => {
        'aiName': aiName,
        'model': model,
        'apiBaseUrl': apiBaseUrl,
        'systemPrompt': systemPrompt,
        'rubikaChannelLink': rubikaChannelLink,
        'paymentLink': paymentLink,
        'myketLink': myketLink,
        'paymentAmount': paymentAmount,
        'proDurationDays': proDurationDays,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        aiName: json['aiName'] as String? ?? 'وارنیکس',
        model: json['model'] as String? ?? 'openrouter/free',
        apiBaseUrl: json['apiBaseUrl'] as String? ?? 'https://openrouter.ai/api/v1',
        systemPrompt: json['systemPrompt'] as String? ??
            'تو یک دستیار هوشمند فارسی‌زبان به نام وارنیکس هستی. پاسخ‌ها را به زبان فارسی، مفید، دقیق و دوستانه بده.',
        rubikaChannelLink: json['rubikaChannelLink'] as String? ?? '',
        paymentLink: json['paymentLink'] as String? ?? '',
        myketLink: json['myketLink'] as String? ?? '',
        paymentAmount: json['paymentAmount'] as String? ?? '۱۸۹٬۰۰۰ تومان',
        proDurationDays: (json['proDurationDays'] as num?)?.toInt() ?? 40,
      );

  AppSettings copyWith({
    String? aiName,
    String? model,
    String? apiBaseUrl,
    String? systemPrompt,
    String? rubikaChannelLink,
    String? paymentLink,
    String? myketLink,
    String? paymentAmount,
    int? proDurationDays,
  }) {
    return AppSettings(
      aiName: aiName ?? this.aiName,
      model: model ?? this.model,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      rubikaChannelLink: rubikaChannelLink ?? this.rubikaChannelLink,
      paymentLink: paymentLink ?? this.paymentLink,
      myketLink: myketLink ?? this.myketLink,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      proDurationDays: proDurationDays ?? this.proDurationDays,
    );
  }
}
