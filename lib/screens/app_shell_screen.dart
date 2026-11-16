import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'chat_screen.dart';
import 'owner_panel_screen.dart';
import 'auth_screen.dart';
import 'code_lab_screen.dart';
import 'free_tools_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});
  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _index = 0;
  static const _purple = Color(0xFF8B5CF6);
  void _go(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomePage(onOpen: _go),
      const ChatScreen(),
      _ToolsPage(onOpen: _go),
      const ReferralPage(),
      _AccountPage(onOwner: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerPanelScreen())), onLogout: () async {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
      }),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          backgroundColor: const Color(0xFF1A1030),
          indicatorColor: _purple.withOpacity(.22),
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'خانه'),
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat), label: 'گفتگو'),
            NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view), label: 'ابزارها'),
            NavigationDestination(icon: Icon(Icons.card_giftcard), selectedIcon: Icon(Icons.redeem), label: 'دعوت'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حساب'),
          ],
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  final ValueChanged<int> onOpen;
  const _HomePage({required this.onOpen});
  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'Varnix AI',
    subtitle: 'دستیار هوشمند فارسی‌زبان شما',
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6D28D9), Color(0xFF4338CA)]), borderRadius: BorderRadius.circular(22)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.auto_awesome, size: 34, color: Colors.white),
          SizedBox(height: 12),
          Text('سلام! آماده‌ای؟', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Colors.white)),
          SizedBox(height: 6),
          Text('از گفتگو تا ابزارهای هوشمند، همه‌چیز در یک جا.', style: TextStyle(color: Colors.white70)),
        ]),
      ),
      const SizedBox(height: 20),
      const Text('دسترسی سریع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.55,
        children: [
          _QuickTile(icon: Icons.chat, title: 'گفتگوی هوشمند', onTap: () => onOpen(1)),
          _QuickTile(icon: Icons.auto_awesome, title: 'ابزارهای هوشمند', onTap: () => onOpen(2)),
          _QuickTile(icon: Icons.card_giftcard, title: 'دعوت دوستان', onTap: () => onOpen(3)),
          _QuickTile(icon: Icons.person, title: 'حساب کاربری', onTap: () => onOpen(4)),
        ],
      ),
      const SizedBox(height: 16),
      const Text('امکانات بیشتر از بخش ابزارها در دسترس هستند.', style: TextStyle(color: Colors.white54)),
    ]),
  );
}

class _QuickTile extends StatelessWidget {
  final IconData icon; final String title; final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF211936), borderRadius: BorderRadius.circular(16),
    child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Padding(
      padding: const EdgeInsets.all(14), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: const Color(0xFFA78BFA), size: 27), const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    )),
  );
}

class _ToolsPage extends StatelessWidget {
  final ValueChanged<int> onOpen;
  const _ToolsPage({required this.onOpen});
  @override
  Widget build(BuildContext context) => _PageFrame(title: 'ابزارهای هوشمند', subtitle: 'بخش‌های مختلف وارنیکس', child: Column(children: [
    _ToolRow(icon: Icons.smart_toy_outlined, title: 'دستیارهای هوشمند', subtitle: 'انتخاب و ساخت دستیارهای اختصاصی', status: 'در حال توسعه'),
    _ToolRow(icon: Icons.code, title: 'آزمایشگاه کدنویسی', subtitle: 'ویرایش، اجرا و مشاهده خروجی Python و Java', status: 'جدید', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CodeLabScreen()))),
    _ToolRow(icon: Icons.auto_fix_high, title: 'ابزارهای رایگان', subtitle: 'قالب‌های آماده، بررسی متن و یادداشت سریع', status: 'رایگان', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FreeToolsScreen()))),
    _ToolRow(icon: Icons.image_outlined, title: 'تولید تصویر', subtitle: 'ساخت تصویر با هوش مصنوعی', status: 'محدود'),
    _ToolRow(icon: Icons.video_library_outlined, title: 'ساخت ویدئو', subtitle: 'ابزار ویدئویی و ارسال فایل', status: 'به‌زودی'),
    _ToolRow(icon: Icons.folder_open, title: 'فایل‌ها و اسناد', subtitle: 'مدیریت فایل‌های ارسالی', status: 'در حال توسعه'),
    _ToolRow(icon: Icons.history, title: 'تاریخچه گفتگوها', subtitle: 'گفتگوهای ذخیره‌شده حساب', status: 'در گفتگو'),
    _ToolRow(icon: Icons.workspace_premium_outlined, title: 'اشتراک حرفه‌ای', subtitle: 'امکانات و شرایط نسخه حرفه‌ای', status: 'مشاهده از حساب'),
    const SizedBox(height: 12),
    OutlinedButton.icon(onPressed: () => onOpen(1), icon: const Icon(Icons.chat), label: const Text('رفتن به گفتگوی هوشمند')),
  ]));
}

class _ToolRow extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final String status;
  final VoidCallback? onTap;
  const _ToolRow({required this.icon, required this.title, required this.subtitle, required this.status, this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF211936), borderRadius: BorderRadius.circular(15)),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(15), child: Row(children: [
      CircleAvatar(backgroundColor: const Color(0xFF8B5CF6).withOpacity(.18), child: Icon(icon, color: const Color(0xFFA78BFA))),
      const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ])),
      Text(status, style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
    ])),
  );
}

class ReferralPage extends StatelessWidget {
  const ReferralPage({super.key});
  String _code(String id) => 'VARNIX-${id.replaceAll('-', '').toUpperCase().substring(0, 8)}';
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final code = user == null ? '---' : _code(user.id);
    final inviteText = 'به وارنیکس AI بپیوند! هنگام ثبت‌نام کد دعوت من را وارد کن: $code';
    return _PageFrame(title: 'دعوت دوستان', subtitle: 'وارنیکس را به دوستانت معرفی کن', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF312E81)]), borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.card_giftcard, color: Colors.white, size: 34), SizedBox(height: 12),
        Text('دعوت با کد اختصاصی', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 21)),
        SizedBox(height: 6), Text('کد خودت را برای دوستانت بفرست تا هنگام ثبت‌نام وارد کنند.', style: TextStyle(color: Colors.white70)),
      ])),
      const SizedBox(height: 20),
      const Text('کد دعوت شما', style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18), decoration: BoxDecoration(color: const Color(0xFF211936), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF6D28D9))), child: Row(children: [
        Expanded(child: SelectableText(code, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.3))),
        IconButton(onPressed: user == null ? null : () async { await Clipboard.setData(ClipboardData(text: code)); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کد دعوت کپی شد'))); }, icon: const Icon(Icons.copy, color: Color(0xFFA78BFA))),
      ])),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: user == null ? null : () => Share.share(inviteText), icon: const Icon(Icons.share), label: const Text('اشتراک‌گذاری کد دعوت')),
      const SizedBox(height: 18),
      FutureBuilder<dynamic>(
        future: Supabase.instance.client.rpc('get_my_referral_count'),
        builder: (context, snapshot) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF211936), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.people_alt_outlined, color: Color(0xFFA78BFA), size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('دعوت‌های موفق ثبت‌شده', style: TextStyle(color: Colors.white))),
            Text(snapshot.hasData ? snapshot.data.toString() : (snapshot.hasError ? '—' : '...'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF211936), borderRadius: BorderRadius.circular(14)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('نحوه استفاده', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        SizedBox(height: 8), Text('۱. کد بالا را برای دوستت بفرست.\\n۲. دوستت هنگام ثبت‌نام، کد را در کادر کد دعوت وارد می‌کند.\\n۳. پس از ساخت حساب، دعوت معتبر در آمار بالا ثبت می‌شود.', style: TextStyle(color: Colors.white70, height: 1.7)),
      ])),
    ]));
  }
}

class _AccountPage extends StatelessWidget {
  final VoidCallback onOwner; final VoidCallback onLogout;
  const _AccountPage({required this.onOwner, required this.onLogout});
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return _PageFrame(title: 'حساب کاربری', subtitle: 'مدیریت حساب و تنظیمات', child: Column(children: [
      CircleAvatar(radius: 34, backgroundColor: const Color(0xFF6D28D9), child: const Icon(Icons.person, size: 36, color: Colors.white)),
      const SizedBox(height: 12),
      Text(user?.email ?? 'کاربر وارنیکس', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      const SizedBox(height: 22),
      _AccountTile(icon: Icons.workspace_premium, title: 'اشتراک حرفه‌ای', onTap: () => _showInfo(context, 'اشتراک حرفه‌ای', 'اطلاعات و خرید اشتراک از طریق بخش پرداخت برنامه در دسترس قرار می‌گیرد.')),
      _AccountTile(icon: Icons.settings, title: 'تنظیمات برنامه', onTap: () => _showInfo(context, 'تنظیمات', 'تنظیمات مدل و اتصال API از منوی گفتگوی هوشمند قابل دسترسی است.')),
      _AccountTile(icon: Icons.admin_panel_settings, title: 'پنل مالک', onTap: onOwner),
      _AccountTile(icon: Icons.logout, title: 'خروج از حساب', color: Colors.orangeAccent, onTap: onLogout),
    ]));
  }
  void _showInfo(BuildContext context, String title, String body) => showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: Text(body), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('باشه'))]));
}

class _AccountTile extends StatelessWidget {
  final IconData icon; final String title; final Color color; final VoidCallback onTap;
  const _AccountTile({required this.icon, required this.title, required this.onTap, this.color = const Color(0xFFA78BFA)});
  @override
  Widget build(BuildContext context) => Card(color: const Color(0xFF211936), child: ListTile(leading: Icon(icon, color: color), title: Text(title, style: const TextStyle(color: Colors.white)), trailing: const Icon(Icons.chevron_left, color: Colors.white54), onTap: onTap));
}

class _PageFrame extends StatelessWidget {
  final String title; final String subtitle; final Widget child;
  const _PageFrame({required this.title, required this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) => SafeArea(child: CustomScrollView(slivers: [
    SliverAppBar(pinned: true, backgroundColor: const Color(0xFF1A1030), title: Text(title, style: const TextStyle(color: Colors.white)), automaticallyImplyLeading: false),
    SliverPadding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), sliver: SliverList(delegate: SliverChildListDelegate([
      Text(subtitle, style: const TextStyle(color: Colors.white54)), const SizedBox(height: 18), child,
    ]))),
  ]));
}
