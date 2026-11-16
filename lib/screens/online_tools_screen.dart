import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';
const _toolsBg=Color(0xFF0F0F1A),_toolsPanel=Color(0xFF211936),_toolsAccent=Color(0xFFA78BFA);
class OnlineToolsScreen extends StatefulWidget {
 const OnlineToolsScreen({super.key});
 @override State<OnlineToolsScreen> createState()=>_OnlineToolsScreenState();
}
class _OnlineToolsScreenState extends State<OnlineToolsScreen> with SingleTickerProviderStateMixin{
 late final TabController _tabs;
 @override void initState(){super.initState();_tabs=TabController(length:3,vsync:this);}
 @override void dispose(){_tabs.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(backgroundColor:_toolsBg,
  appBar:AppBar(title:const Text('آموزش‌ها و امکانات آنلاین'),backgroundColor:const Color(0xFF1A1030),foregroundColor:Colors.white,bottom:TabBar(controller:_tabs,isScrollable:true,indicatorColor:_toolsAccent,tabs:const [Tab(text:'آموزش‌ها'),Tab(text:'قالب‌های هوشمند'),Tab(text:'افزونه‌ها')])),
  body:TabBarView(controller:_tabs,children:const [_TutorialsTab(),_PromptsTab(),_AddonsTab()])));
}
class _TutorialsTab extends StatelessWidget{
 const _TutorialsTab();
 Future<List<Map<String,dynamic>>> _load()async{final rows=await Supabase.instance.client.from('tutorials').select('id,title,category,body,image_url,video_url').eq('is_published',true).order('sort_order');return List<Map<String,dynamic>>.from(rows);}
 @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:_load(),builder:(context,s){
  if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
  if(s.hasError)return const _OnlineError(message:'آموزش‌ها دریافت نشدند. دیتابیس باید به‌روزرسانی شده باشد.');
  final rows=s.data??[];
  if(rows.isEmpty)return const _EmptyOnline(message:'هنوز آموزشی منتشر نشده است. آموزش‌ها پس از انتشار از پنل مالک اینجا نمایش داده می‌شوند.');
  return RefreshIndicator(onRefresh:() async { await _load(); },child:ListView(padding:const EdgeInsets.all(14),children:rows.map((r)=>Card(color:_toolsPanel,child:ExpansionTile(iconColor:_toolsAccent,collapsedIconColor:_toolsAccent,
   title:Text(r['title']?.toString()??'آموزش',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),subtitle:Text(r['category']?.toString()??'عمومی',style:const TextStyle(color:Colors.white54)),
   children:[Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    SelectableText(r['body']?.toString()??'',style:const TextStyle(color:Colors.white,height:1.8)),
    if((r['image_url']??'').toString().startsWith('https://'))TextButton.icon(onPressed:()=>_open(r['image_url'].toString()),icon:const Icon(Icons.image_outlined),label:const Text('مشاهده تصویر آموزشی')),
    if((r['video_url']??'').toString().startsWith('https://'))TextButton.icon(onPressed:()=>_open(r['video_url'].toString()),icon:const Icon(Icons.play_circle_outline),label:const Text('مشاهده ویدئوی آموزشی')),
   ]))])).toList()));
 });
}
class _PromptsTab extends StatefulWidget{const _PromptsTab();@override State<_PromptsTab> createState()=>_PromptsTabState();}
class _PromptsTabState extends State<_PromptsTab>{
 String _query='',_category='همه';late Future<List<Map<String,dynamic>>> _future;
 @override void initState(){super.initState();_future=_load();}
 Future<List<Map<String,dynamic>>> _load()async{final rows=await Supabase.instance.client.from('prompt_templates').select('id,title,category,prompt').eq('is_published',true).order('sort_order');return List<Map<String,dynamic>>.from(rows);}
 void _use(Map<String,dynamic> item){Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatScreen(initialPrompt:item['prompt']?.toString()??'')));}
 @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:_future,builder:(context,s){
  if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
  if(s.hasError)return const _OnlineError(message:'قالب‌ها دریافت نشدند. اتصال اینترنت و تنظیمات دیتابیس را بررسی کن.');
  final all=s.data??[];final categories=['همه',...{for(final item in all)(item['category']??'عمومی').toString()}];
  final rows=all.where((item){final cat=_category=='همه'||(item['category']??'عمومی').toString()==_category;final txt=(''+item['title'].toString()+' '+item['prompt'].toString()).toLowerCase().contains(_query.toLowerCase());return cat&&txt;}).toList();
  return Column(children:[
   Padding(padding:const EdgeInsets.fromLTRB(12,12,12,4),child:TextField(onChanged:(v)=>setState(()=>_query=v),style:const TextStyle(color:Colors.white),decoration:InputDecoration(hintText:'جست‌وجوی قالب...',prefixIcon:const Icon(Icons.search),filled:true,fillColor:_toolsPanel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none)))),
   if(categories.length>1)SizedBox(height:48,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:10),children:categories.map((v)=>Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:ChoiceChip(label:Text(v),selected:_category==v,onSelected:(_)=>setState(()=>_category=v)))).toList())),
   Expanded(child:rows.isEmpty?const _EmptyOnline(message:'قالبی با این مشخصات پیدا نشد.'):ListView(padding:const EdgeInsets.all(12),children:rows.map((item)=>Card(color:_toolsPanel,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(item['title']?.toString()??'قالب',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:16)),const SizedBox(height:5),Text(item['category']?.toString()??'عمومی',style:const TextStyle(color:_toolsAccent,fontSize:12)),const SizedBox(height:8),
    Text(item['prompt']?.toString()??'',maxLines:4,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white70,height:1.5)),
    Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:()=>_use(item),icon:const Icon(Icons.chat),label:const Text('استفاده در گفتگو'),style:FilledButton.styleFrom(backgroundColor:const Color(0xFF6D4CE8))))
   ]))).toList()))
  ]);
 });
}
class _AddonsTab extends StatelessWidget{
 const _AddonsTab();
 Future<List<Map<String,dynamic>>> _load()async{final rows=await Supabase.instance.client.from('addons').select('id,slug,name,description,icon,capability_type,config,requires_pro,min_app_version').eq('is_enabled',true).order('sort_order');return List<Map<String,dynamic>>.from(rows);}
 Future<void> _activate(BuildContext context,Map<String,dynamic> item)async{
  if(item['requires_pro']==true){
   try{
    final user=Supabase.instance.client.auth.currentUser;
    if(user==null){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('برای استفاده از این افزونه وارد حساب شو.')));return;}
    final profile=await Supabase.instance.client.from('profiles').select('role,plan_code,plan_expires_at').eq('id',user.id).maybeSingle();
    final role=(profile?['role']??'').toString().toLowerCase();
    final plan=(profile?['plan_code']??'free').toString().toLowerCase();
    final expiry=profile?['plan_expires_at'];
    final pro=role=='admin'||plan=='owner'||(plan=='pro'&&(expiry==null||DateTime.tryParse(expiry.toString())?.isAfter(DateTime.now())==true));
    if(!pro){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('این افزونه مخصوص اشتراک حرفه‌ای است.')));return;}
   }catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('وضعیت اشتراک بررسی نشد؛ دوباره تلاش کن.')));return;}
  }
  final type=item['capability_type']?.toString()??'';final config=item['config'] is Map?Map<String,dynamic>.from(item['config'] as Map):<String,dynamic>{};
  if(type=='external_link'){final url=config['url']?.toString()??'';if(url.startsWith('https://')){await _open(url);}else if(context.mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('پیوند امن برای این افزونه ثبت نشده است.')));}return;}
  final body=config['body']?.toString()??config['content']?.toString()??'';
  if(type=='remote_content'&&body.isNotEmpty){if(context.mounted)showDialog<void>(context:context,builder:(ctx)=>AlertDialog(backgroundColor:_toolsPanel,title:Text(item['name']?.toString()??'محتوای افزونه'),content:SingleChildScrollView(child:SelectableText(body,style:const TextStyle(color:Colors.white,height:1.7))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('بستن'))]));return;}
  if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('این افزونه فقط تنظیمات امن را نمایش می‌دهد و کد اجرایی خارجی دریافت نمی‌کند.')));
 }
 @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:_load(),builder:(context,s){
  if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
  if(s.hasError)return const _OnlineError(message:'افزونه‌ها بارگذاری نشدند. دیتابیس باید به‌روزرسانی شده باشد.');
  final rows=s.data??[];if(rows.isEmpty)return const _EmptyOnline(message:'هنوز افزونه‌ای از پنل مالک فعال و منتشر نشده است.');
  return RefreshIndicator(onRefresh:() async { await _load(); },child:ListView(padding:const EdgeInsets.all(14),children:rows.map((item){
   final pro=item['requires_pro']==true;final type=item['capability_type']?.toString()??'';
   final kind=type=='external_link'?'پیوند خارجی امن':type=='remote_content'?'محتوای آنلاین':'قابلیت تنظیمی';
   return Card(color:_toolsPanel,child:ListTile(leading:const CircleAvatar(backgroundColor:Color(0x338B5CF6),child:Icon(Icons.extension,color:_toolsAccent)),
    title:Text(item['name']?.toString()??'افزونه',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
    subtitle:Text(item['description'].toString()+'\n'+(pro?'ویژه حرفه‌ای • ':'')+kind,style:const TextStyle(color:Colors.white60),maxLines:3,overflow:TextOverflow.ellipsis),isThreeLine:true,
    trailing:IconButton(onPressed:()=>_activate(context,item),icon:const Icon(Icons.open_in_new,color:_toolsAccent))));
  }).toList()));
 });
}
class _OnlineError extends StatelessWidget{final String message;const _OnlineError({required this.message});@override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(message,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70))));}
class _EmptyOnline extends StatelessWidget{final String message;const _EmptyOnline({required this.message});@override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(message,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white54,height:1.7))));}
Future<void> _open(String url)async{final uri=Uri.tryParse(url);if(uri!=null&&uri.scheme=='https')await launchUrl(uri,mode:LaunchMode.externalApplication);}
