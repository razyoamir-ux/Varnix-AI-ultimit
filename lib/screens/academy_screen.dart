import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AcademyScreen extends StatefulWidget {
  const AcademyScreen({super.key});
  @override
  State<AcademyScreen> createState() => _AcademyScreenState();
}

class _AcademyScreenState extends State<AcademyScreen> {
  Set<String> completed = <String>{};
  bool loading = true;

  final List<Map<String, dynamic>> courses = [
    {
      'id': 'ai-basics', 'title': 'مبانی هوش مصنوعی', 'subtitle': 'از مفاهیم پایه تا کاربردهای روزمره',
      'icon': Icons.psychology_alt, 'color': Color(0xFF8B5CF6),
      'lessons': [
        {'title': 'هوش مصنوعی چیست؟', 'body': 'هوش مصنوعی شاخه‌ای از علوم رایانه است که سیستم‌هایی برای انجام کارهایی می‌سازد که معمولاً به توانایی‌های شناختی انسان نیاز دارند؛ مانند فهم زبان، تشخیص الگو و تصمیم‌گیری.\n\nمدل‌های زبانی با بررسی حجم بزرگی از متن، الگوهای زبان را یاد می‌گیرند و می‌توانند پاسخ‌های تازه تولید کنند.'},
        {'title': 'یادگیری ماشین', 'body': 'یادگیری ماشین روشی است که در آن سیستم از داده‌ها الگو می‌آموزد. به‌جای نوشتن تمام قوانین به‌صورت دستی، نمونه‌هایی در اختیار مدل قرار می‌گیرد تا رابطه‌ها را یاد بگیرد.\n\nسه رویکرد رایج عبارت‌اند از یادگیری نظارت‌شده، بدون نظارت و تقویتی.'},
        {'title': 'پرامپت‌نویسی مؤثر', 'body': 'برای گرفتن پاسخ بهتر، هدف، زمینه، محدودیت‌ها و قالب خروجی را روشن بیان کن.\n\nنمونه: «این متن را برای دانش‌آموز پایه دهم، در پنج نکته ساده خلاصه کن و سه سؤال تمرینی بساز.»'}
      ],
      'quiz': [
        {'q': 'یادگیری ماشین بر چه چیزی تکیه دارد؟', 'a': ['داده و الگوها', 'فقط قوانین ثابت', 'افزایش سرعت اینترنت'], 'correct': 0},
        {'q': 'کدام مورد پرامپت دقیق‌تری است؟', 'a': ['کمک کن', 'موضوع را توضیح بده', 'مبحث را در ۵ نکته برای پایه دهم توضیح بده'], 'correct': 2}
      ]
    },
    {
      'id': 'study-skills', 'title': 'مهارت‌های مطالعه', 'subtitle': 'یادگیری عمیق، مرور و برنامه‌ریزی',
      'icon': Icons.school, 'color': Color(0xFF0EA5E9),
      'lessons': [
        {'title': 'یادگیری فعال', 'body': 'به‌جای چندبار خواندن منفعلانه، کتاب را ببند و تلاش کن مفهوم را با زبان خودت توضیح بدهی. سپس پاسخ را با منبع مقایسه کن و جاهای ناقص را اصلاح کن.'},
        {'title': 'مرور فاصله‌دار', 'body': 'مرور را در فاصله‌های زمانی انجام بده؛ مثلاً همان روز، روز بعد، سه روز بعد و یک هفته بعد. فاصله‌ها را با میزان دشواری مطلب تنظیم کن.'},
        {'title': 'تقسیم زمان', 'body': 'یک هدف کوچک و قابل‌اندازه‌گیری تعیین کن. برای نمونه ۲۵ دقیقه مطالعه متمرکز و ۵ دقیقه استراحت. در پایان هر نوبت، نتیجه را ثبت کن.'}
      ],
      'quiz': [
        {'q': 'در یادگیری فعال چه کاری مفیدتر است؟', 'a': ['فقط دوباره‌خوانی', 'توضیح مطلب بدون نگاه به کتاب', 'حفظ ظاهر صفحه'], 'correct': 1},
        {'q': 'هدف مرور فاصله‌دار چیست؟', 'a': ['حذف استراحت', 'تقویت یادآوری در زمان‌های مختلف', 'خواندن سریع‌تر بدون فهم'], 'correct': 1}
      ]
    },
    {
      'id': 'programming', 'title': 'شروع برنامه‌نویسی', 'subtitle': 'منطق، متغیر و شرط‌ها',
      'icon': Icons.code, 'color': Color(0xFF10B981),
      'lessons': [
        {'title': 'الگوریتم چیست؟', 'body': 'الگوریتم مجموعه‌ای از گام‌های روشن و مرتب برای حل یک مسئله است. قبل از نوشتن کد، ورودی، خروجی و مراحل حل را مشخص کن.'},
        {'title': 'متغیرها', 'body': 'متغیر نامی برای نگهداری یک مقدار در برنامه است. مقدار می‌تواند عدد، متن یا نوع دیگری از داده باشد. نام متغیر را معنادار انتخاب کن.'},
        {'title': 'شرط‌ها', 'body': 'دستور شرطی مسیر اجرای برنامه را بر اساس درست یا نادرست بودن یک عبارت انتخاب می‌کند. در بسیاری از زبان‌ها از ساختار if و else استفاده می‌شود.'}
      ],
      'quiz': [
        {'q': 'الگوریتم چیست؟', 'a': ['مجموعه گام‌های حل مسئله', 'نام یک زبان برنامه‌نویسی', 'نوعی سخت‌افزار'], 'correct': 0},
        {'q': 'دستور if برای چیست؟', 'a': ['ذخیره تصویر', 'تصمیم‌گیری بر اساس شرط', 'خاموش‌کردن رایانه'], 'correct': 1}
      ]
    }
  ];

  final List<Map<String, String>> flashcards = [
    {'front': 'الگوریتم', 'back': 'مراحل مرتب و روشن برای حل یک مسئله'},
    {'front': 'یادگیری ماشین', 'back': 'یادگیری الگوها از داده‌ها برای پیش‌بینی یا تصمیم‌گیری'},
    {'front': 'مرور فاصله‌دار', 'back': 'مرور مطالب در چند نوبت با فاصله زمانی'},
    {'front': 'پرامپت', 'back': 'دستور یا درخواستی که به مدل هوش مصنوعی می‌دهیم'}
  ];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      completed = (prefs.getStringList('academy_completed') ?? <String>{}.toList()).toSet();
      loading = false;
    });
  }

  Future<void> _markComplete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => completed.add(id));
    await prefs.setStringList('academy_completed', completed.toList());
  }

  int _courseDone(Map<String, dynamic> course) {
    final lessons = course['lessons'] as List;
    return lessons.where((lesson) => completed.contains('${course['id']}:${lesson['title']}')).length;
  }

  void _openCourse(Map<String, dynamic> course) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _CourseScreen(
      course: course, completed: completed, onComplete: _markComplete,
    ))).then((_) { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    final totalLessons = courses.fold<int>(0, (sum, c) => sum + (c['lessons'] as List).length);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('آکادمی وارنیکس'), actions: [
          IconButton(tooltip: 'فلش‌کارت‌ها', icon: const Icon(Icons.style_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _FlashcardsScreen(cards: flashcards)))),
        ]),
        body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(colors: [Color(0xFF31205F), Color(0xFF164E63)]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('یاد بگیر، تمرین کن، پیشرفت کن', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('دوره‌های کوتاه، درس‌های مرحله‌ای و آزمون‌های تمرینی'),
                const SizedBox(height: 14),
                LinearProgressIndicator(value: totalLessons == 0 ? 0 : completed.length / totalLessons, minHeight: 8),
                const SizedBox(height: 7),
                Text('${completed.length} از $totalLessons درس تکمیل شده'),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('دوره‌های آموزشی', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...courses.map((course) {
              final lessons = course['lessons'] as List;
              final done = _courseDone(course);
              final color = course['color'] as Color;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(backgroundColor: color.withOpacity(.18), child: Icon(course['icon'] as IconData, color: color)),
                  title: Text(course['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(course['subtitle'] as String),
                    const SizedBox(height: 9),
                    LinearProgressIndicator(value: lessons.isEmpty ? 0 : done / lessons.length),
                    const SizedBox(height: 4),
                    Text('$done از ${lessons.length} درس'),
                  ])),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => _openCourse(course),
                ),
              );
            }),
            const SizedBox(height: 12),
            Card(child: ListTile(
              leading: const Icon(Icons.style, color: Color(0xFFA78BFA)),
              title: const Text('مرور با فلش‌کارت'),
              subtitle: const Text('تعریف‌ها را به خاطر بسپار و خودت را امتحان کن'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _FlashcardsScreen(cards: flashcards))),
            )),
          ],
        ),
      ),
    );
  }
}

class _CourseScreen extends StatelessWidget {
  final Map<String, dynamic> course;
  final Set<String> completed;
  final Future<void> Function(String) onComplete;
  const _CourseScreen({required this.course, required this.completed, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final lessons = course['lessons'] as List;
    final quiz = course['quiz'] as List;
    final id = course['id'] as String;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(course['title'] as String)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(course['subtitle'] as String),
          const SizedBox(height: 14),
          ...List.generate(lessons.length, (i) {
            final lesson = lessons[i] as Map;
            final key = '$id:${lesson['title']}';
            final done = completed.contains(key);
            return Card(child: ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(lesson['title'] as String),
              subtitle: Text(done ? 'تکمیل‌شده' : 'برای مطالعه باز کن'),
              trailing: Icon(done ? Icons.check_circle : Icons.play_circle_outline, color: done ? Colors.green : null),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _LessonScreen(
                title: lesson['title'] as String,
                body: lesson['body'] as String,
                isDone: done,
                onComplete: () => onComplete(key),
              ))),
            ));
          }),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _QuizScreen(questions: quiz))),
            icon: const Icon(Icons.quiz_outlined), label: const Text('شروع آزمون دوره'),
          ),
        ]),
      ),
    );
  }
}

class _LessonScreen extends StatefulWidget {
  final String title, body;
  final bool isDone;
  final Future<void> Function() onComplete;
  const _LessonScreen({required this.title, required this.body, required this.isDone, required this.onComplete});
  @override
  State<_LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<_LessonScreen> {
  bool done = false;
  @override
  void initState() { super.initState(); done = widget.isDone; }
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(widget.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        SelectableText(widget.body, style: const TextStyle(fontSize: 17, height: 1.9)),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: done ? null : () async { await widget.onComplete(); if (mounted) setState(() => done = true); },
          icon: Icon(done ? Icons.check_circle : Icons.task_alt),
          label: Text(done ? 'این درس تکمیل شده' : 'علامت‌گذاری به‌عنوان تکمیل‌شده'),
        ),
      ]),
    ),
  );
}

class _QuizScreen extends StatefulWidget {
  final List questions;
  const _QuizScreen({required this.questions});
  @override
  State<_QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<_QuizScreen> {
  int index = 0, score = 0;
  int? selected;
  bool answered = false;

  @override
  Widget build(BuildContext context) {
    final finished = index >= widget.questions.length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('آزمون تمرینی')),
        body: finished ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
          const SizedBox(height: 12),
          Text('نتیجه: $score از ${widget.questions.length}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('بازگشت به دوره')),
        ])) : ListView(padding: const EdgeInsets.all(18), children: [
          Text('سؤال ${index + 1} از ${widget.questions.length}'),
          const SizedBox(height: 12),
          Text(widget.questions[index]['q'] as String, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ...List.generate((widget.questions[index]['a'] as List).length, (i) => Card(
            child: RadioListTile<int>(
              value: i, groupValue: selected, title: Text(widget.questions[index]['a'][i] as String),
              onChanged: answered ? null : (v) => setState(() => selected = v),
            ),
          )),
          if (answered) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(
            selected == widget.questions[index]['correct'] ? 'آفرین! پاسخ درست بود.' : 'پاسخ درست: ${(widget.questions[index]['a'] as List)[widget.questions[index]['correct']]}',
            style: TextStyle(color: selected == widget.questions[index]['correct'] ? Colors.green : Colors.orange),
          )),
          FilledButton(
            onPressed: selected == null ? null : () {
              if (!answered) {
                setState(() { answered = true; if (selected == widget.questions[index]['correct']) score++; });
              } else {
                setState(() { index++; selected = null; answered = false; });
              }
            },
            child: Text(answered ? 'سؤال بعدی' : 'بررسی پاسخ'),
          ),
        ]),
      ),
    );
  }
}

class _FlashcardsScreen extends StatefulWidget {
  final List<Map<String, String>> cards;
  const _FlashcardsScreen({required this.cards});
  @override
  State<_FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<_FlashcardsScreen> {
  int index = 0;
  bool showBack = false;
  @override
  Widget build(BuildContext context) {
    final card = widget.cards[index];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('فلش‌کارت‌ها')),
        body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Text('کارت ${index + 1} از ${widget.cards.length}'),
          const SizedBox(height: 20),
          Expanded(child: InkWell(
            onTap: () => setState(() => showBack = !showBack),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: [Color(0xFF31205F), Color(0xFF164E63)]),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(showBack ? Icons.lightbulb : Icons.help_outline, size: 42),
                const SizedBox(height: 20),
                Text(showBack ? card['back']! : card['front']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('برای برگرداندن کارت لمس کن'),
              ]),
            ),
          )),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: index == 0 ? null : () => setState(() { index--; showBack = false; }), child: const Text('قبلی'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: index == widget.cards.length - 1 ? null : () => setState(() { index++; showBack = false; }), child: const Text('بعدی'))),
          ]),
        ])),
      ),
    );
  }
}
