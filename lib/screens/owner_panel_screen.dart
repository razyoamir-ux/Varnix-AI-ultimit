import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerPanelScreen extends StatefulWidget {
  const OwnerPanelScreen({super.key});
  @override
  State<OwnerPanelScreen> createState()=>_OwnerPanelScreenState();
}
class _OwnerPanelScreenState extends State<OwnerPanelScreen> with SingleTickerProviderStateMixin {
  final db=Supabase.instance.client;
  late TabController tabs;
  bool checking=true,allowed=false,busy=false;
  String? errorText;
  Map<String,dynamic> config={};
  final fields=<String,TextEditingController>{};
  final toggles=<String,bool>{};
  List<Map<String,dynamic>> users=[],models=[],assistants=[],plans=[],purchases=[];
  Map<String,int> stats={};
  static const purple=Color(0xFFA78BFA),panel=Color(0xFF1E1B32);
  static const boolKeys={'payment_enabled','ads_enabled','ad_banner_enabled','ad_interstitial_enabled','ad_rewarded_enabled'};
  static const intKeys={'pro_duration_days','pro_base_price','free_daily_message_limit','free_daily_image_limit','free_daily_file_limit','free_daily_video_limit','free_voice_economic_minutes','free_voice_advanced_minutes','pro_daily_image_generation_limit','pro_daily_video_generation_limit','pro_daily_image_input_limit','pro_daily_file_input_limit','free_max_attachment_mb','pro_max_attachment_mb'};
  static const keys=['app_name','default_model','api_base_url','system_prompt','rubika_url','myket_url','pro_price','pro_duration_days','announcement','payment_provider','payment_enabled','pro_base_price','free_daily_message_limit','free_daily_image_limit','free_daily_file_limit','free_daily_video_limit','free_voice_economic_minutes','free_voice_advanced_minutes','pro_daily_image_generation_limit','pro_daily_video_generation_limit','ads_enabled','ad_provider','ad_banner_enabled','ad_banner_placement','ad_banner_unit_id','ad_interstitial_enabled','ad_interstitial_unit_id','ad_rewarded_enabled','ad_rewarded_unit_id','pro_daily_image_input_limit','pro_daily_file_input_limit','free_max_attachment_mb','pro_max_attachment_mb'];
  @override void initState(){super.initState();tabs=TabController(length:7,vsync:this);authorize();}
  String err(Object e)=>e.toString().replaceFirst('Exception: ','');
  Future<void> authorize() async {
    try{
      final u=db.auth.currentUser;
      if(u==null||u.emailConfirmedAt==null)throw Exception('ابتدا با ایمیل تأییدشده وارد شوید.');
      final p=await db.from('profiles').select('role').eq('id',u.id).maybeSingle();
      if((p?['role']??'').toString()!='admin')throw Exception('این حساب دسترسی مالک ندارد.');
      if(!mounted)return;setState(()=>allowed=true);setState(()=>checking=false);await reload();
    }catch(e){if(mounted)setState((){checking=false;errorText=err(e);});}
  }
  Future<void> reload() async {
    if(!mounted)return;setState(()=>busy=true);
    try{
      final r=await Future.wait([
        db.from('app_config').select().eq('id',true).maybeSingle(),
        db.from('profiles').select('id,email,display_name,role,plan_code,plan_expires_at,created_at').order('created_at',ascending:false).limit(200),
        db.from('ai_models').select().order('sort_order'),db.from('assistants').select().order('sort_order'),
        db.from('subscription_plans').select().order('sort_order'),
        db.from('purchases').select('id,user_id,plan_code,amount,currency,provider,status,created_at').order('created_at',ascending:false).limit(100),
        db.from('conversations').select('id'),db.from('messages').select('id'),db.from('ai_usage').select('request_count')
      ]);
      config=Map<String,dynamic>.from((r[0] as Map<String,dynamic>?)??{});
      for(final k in keys){if(boolKeys.contains(k)){toggles[k]=config[k]==true;}else{fields.putIfAbsent(k,()=>TextEditingController());fields[k]!.text=config[k]?.toString()??'';}}
      users=List<Map<String,dynamic>>.from(r[1] as List);models=List<Map<String,dynamic>>.from(r[2] as List);
      assistants=List<Map<String,dynamic>>.from(r[3] as List);plans=List<Map<String,dynamic>>.from(r[4] as List);
      purchases=List<Map<String,dynamic>>.from(r[5] as List);
      final usage=List<Map<String,dynamic>>.from(r[8] as List);
      stats={'کاربران':users.length,'گفتگوها':(r[6] as List).length,'پیام‌ها':(r[7] as List).length,'درخواست‌ها':usage.fold<int>(0,(a,b)=>a+((b['request_count'] as num?)?.toInt()??0)),'خریدها':purchases.length,'مدل‌های فعال':models.where((m)=>m['is_active']==true).length};
      if(mounted)setState((){});
    }catch(e){toast('بارگذاری ناموفق: '+err(e),true);}finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> saveConfig() async {
    final row=<String,dynamic>{'updated_at':DateTime.now().toUtc().toIso8601String()};
    for(final k in keys){
      if(boolKeys.contains(k)){row[k]=toggles[k]??false;}
      else if(intKeys.contains(k)){final v=int.tryParse(fields[k]?.text.trim()??'');if(v==null||v<0){toast('مقدار عددی '+k+' معتبر نیست.',true);return;}row[k]=v;}
      else{row[k]=fields[k]?.text.trim()??'';}
    }
    final price=int.tryParse((row['pro_price']??'').toString().replaceAll(RegExp(r'[^0-9]'),''));
    if(price==null||price<1000){toast('قیمت حرفه‌ای باید حداقل ۱۰۰۰ تومان باشد.',true);return;}
    try{setState(()=>busy=true);await db.from('app_config').update(row).eq('id',true);await reload();toast('تنظیمات مرکزی ذخیره شد.');}
    catch(e){toast('ذخیره ناموفق: '+err(e),true);}finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> editModel([Map<String,dynamic>? old]) async {
    final p=TextEditingController(text:old?['provider']?.toString()??'openrouter'),id=TextEditingController(text:old?['model_id']?.toString()??''),n=TextEditingController(text:old?['display_name']?.toString()??''),d=TextEditingController(text:old?['description']?.toString()??''),o=TextEditingController(text:(old?['sort_order']??0).toString());
    bool pro=old?['requires_pro']==true,active=old?['is_active']!=false;
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,sd)=>AlertDialog(backgroundColor:panel,title:Text(old==null?'افزودن مدل':'ویرایش مدل'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      df('ارائه‌دهنده',p),df('شناسه مدل',id),df('نام نمایشی',n),df('توضیحات',d),df('ترتیب',o,num:true),
      SwitchListTile(value:pro,onChanged:(v)=>sd(()=>pro=v),title:const Text('فقط حرفه‌ای')),SwitchListTile(value:active,onChanged:(v)=>sd(()=>active=v),title:const Text('فعال'))
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))])));
    if(ok==true){try{if(p.text.trim().isEmpty||id.text.trim().isEmpty||n.text.trim().isEmpty)throw Exception('ارائه‌دهنده، شناسه و نام اجباری است.');
      final row={'provider':p.text.trim().toLowerCase(),'model_id':id.text.trim(),'display_name':n.text.trim(),'description':d.text.trim(),'sort_order':int.tryParse(o.text)??0,'requires_pro':pro,'is_active':active,'updated_at':DateTime.now().toUtc().toIso8601String()};
      if(old==null){await db.from('ai_models').insert(row);}else{await db.from('ai_models').update(row).eq('id',old['id']);}await reload();toast('مدل ذخیره شد.');
    }catch(e){toast(err(e),true);}}
    p.dispose();id.dispose();n.dispose();d.dispose();o.dispose();
  }
  Future<void> editAssistant([Map<String,dynamic>? old]) async {
    final n=TextEditingController(text:old?['name']?.toString()??''),d=TextEditingController(text:old?['description']?.toString()??''),ic=TextEditingController(text:old?['icon']?.toString()??'✨'),pr=TextEditingController(text:old?['system_prompt']?.toString()??''),m=TextEditingController(text:old?['model']?.toString()??'openrouter/free'),o=TextEditingController(text:(old?['sort_order']??0).toString());
    bool active=old?['is_active']!=false;
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,sd)=>AlertDialog(backgroundColor:panel,title:Text(old==null?'دستیار جدید':'ویرایش دستیار'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      df('نام',n),df('توضیحات',d),df('ایموجی',ic),df('مدل',m),df('دستورالعمل سیستم',pr,lines:4),df('ترتیب',o,num:true),SwitchListTile(value:active,onChanged:(v)=>sd(()=>active=v),title:const Text('فعال'))
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))])));
    if(ok==true){try{if(n.text.trim().isEmpty||pr.text.trim().isEmpty||m.text.trim().isEmpty)throw Exception('نام، دستورالعمل و مدل الزامی است.');
      final row={'name':n.text.trim(),'description':d.text.trim(),'icon':ic.text.trim().isEmpty?'✨':ic.text.trim(),'system_prompt':pr.text.trim(),'model':m.text.trim(),'sort_order':int.tryParse(o.text)??0,'is_active':active,'updated_at':DateTime.now().toUtc().toIso8601String()};
      if(old==null){await db.from('assistants').insert(row);}else{await db.from('assistants').update(row).eq('id',old['id']);}await reload();toast('دستیار ذخیره شد.');
    }catch(e){toast(err(e),true);}}
    n.dispose();d.dispose();ic.dispose();pr.dispose();m.dispose();o.dispose();
  }
  Future<void> editPlan(Map<String,dynamic> p) async {
    final n=TextEditingController(text:p['display_name'].toString()),r=TextEditingController(text:p['daily_request_limit'].toString()),t=TextEditingController(text:p['max_output_tokens'].toString()),price=TextEditingController(text:p['price_label'].toString()),days=TextEditingController(text:p['duration_days'].toString());
    bool active=p['is_active']==true;
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,sd)=>AlertDialog(backgroundColor:panel,title:Text('پلن '+p['plan_code'].toString()),content:Column(mainAxisSize:MainAxisSize.min,children:[
      df('نام نمایشی',n),df('درخواست روزانه',r,num:true),df('حداکثر توکن',t,num:true),df('برچسب قیمت',price),df('مدت روز',days,num:true),SwitchListTile(value:active,onChanged:(v)=>sd(()=>active=v),title:const Text('فعال'))
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('ذخیره'))])));
    if(ok==true){try{final rq=int.parse(r.text),tk=int.parse(t.text),dy=int.parse(days.text);if(rq<1||tk<1||dy<1)throw Exception('اعداد باید مثبت باشند.');
      await db.from('subscription_plans').update({'display_name':n.text.trim(),'daily_request_limit':rq,'max_output_tokens':tk,'price_label':price.text.trim(),'duration_days':dy,'is_active':active,'updated_at':DateTime.now().toUtc().toIso8601String()}).eq('plan_code',p['plan_code']);await reload();toast('پلن ذخیره شد.');
    }catch(e){toast(err(e),true);}}
    n.dispose();r.dispose();t.dispose();price.dispose();days.dispose();
  }
  Future<void> editUser(Map<String,dynamic> u) async {
    String plan=(u['plan_code']??'free').toString();
    final exp=TextEditingController(text:u['plan_expires_at']==null?'':DateTime.tryParse(u['plan_expires_at'].toString())?.toLocal().toString().substring(0,16)??'');
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,sd)=>AlertDialog(backgroundColor:panel,title:const Text('مدیریت اشتراک'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      Text(u['email']?.toString()??u['id'].toString()),DropdownButtonFormField<String>(value:plan=='pro'?'pro':'free',dropdownColor:panel,items:const [DropdownMenuItem(value:'free',child:Text('رایگان')),DropdownMenuItem(value:'pro',child:Text('حرفه‌ای'))],onChanged:(v)=>sd(()=>plan=v??'free')),
      df('انقضا YYYY-MM-DD HH:MM؛ خالی = بدون انقضا',exp)
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('اعمال'))])));
    if(ok==true){try{DateTime? dt;if(exp.text.trim().isNotEmpty){dt=DateTime.tryParse(exp.text.trim());if(dt==null)throw Exception('تاریخ معتبر نیست.');}
      await db.from('profiles').update({'plan_code':plan,'plan_expires_at':dt?.toUtc().toIso8601String(),'updated_at':DateTime.now().toUtc().toIso8601String()}).eq('id',u['id']);await reload();toast('اشتراک به‌روزرسانی شد.');
    }catch(e){toast(err(e),true);}}
    exp.dispose();
  }
  Widget df(String label,TextEditingController c,{int lines=1,bool num=false})=>Padding(padding:const EdgeInsets.only(bottom:9),child:TextField(controller:c,maxLines:lines,keyboardType:num?TextInputType.number:TextInputType.text,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));
  Widget field(String k,String label,{int lines=1})=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:fields[k],maxLines:lines,decoration:InputDecoration(labelText:label,filled:true,fillColor:panel,border:const OutlineInputBorder())));
  Widget sw(String k,String label)=>SwitchListTile(value:toggles[k]??false,onChanged:(v)=>setState(()=>toggles[k]=v),title:Text(label),activeColor:purple,contentPadding:EdgeInsets.zero);
  Widget section(String title,List<Widget> children)=>Card(color:panel,child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:purple,fontWeight:FontWeight.bold)),const SizedBox(height:10),...children])));
  Widget settingsPage()=>ListView(padding:const EdgeInsets.all(14),children:[
    section('تنظیمات هوش مصنوعی',[field('app_name','نام برنامه'),field('default_model','مدل پیش‌فرض'),field('api_base_url','آدرس API'),field('system_prompt','دستورالعمل سیستم',lines:5),field('announcement','پیام اطلاع‌رسانی',lines:3),field('rubika_url','لینک روبیکا'),field('myket_url','لینک مایکت')]),
    section('اشتراک و پرداخت',[field('pro_price','قیمت حرفه‌ای تومان'),field('pro_base_price','قیمت پایه'),field('pro_duration_days','مدت روز'),field('payment_provider','درگاه پرداخت'),sw('payment_enabled','فعال‌سازی پرداخت')]),
    section('سهمیه رایگان',[field('free_daily_message_limit','پیام روزانه'),field('free_daily_image_limit','تصویر روزانه'),field('free_daily_file_limit','فایل روزانه'),field('free_daily_video_limit','ویدئو روزانه'),field('free_voice_economic_minutes','دقیقه صدای اقتصادی'),field('free_voice_advanced_minutes','دقیقه صدای پیشرفته'),field('free_max_attachment_mb','حداکثر حجم فایل MB')]),
    section('سهمیه حرفه‌ای',[field('pro_daily_image_input_limit','ورودی تصویر'),field('pro_daily_file_input_limit','ورودی فایل'),field('pro_daily_image_generation_limit','تولید تصویر'),field('pro_daily_video_generation_limit','تولید ویدئو'),field('pro_max_attachment_mb','حداکثر حجم فایل MB')]),
    section('تبلیغات',[sw('ads_enabled','تبلیغات فعال'),field('ad_provider','شبکه تبلیغات'),sw('ad_banner_enabled','بنر فعال'),field('ad_banner_placement','محل بنر'),field('ad_banner_unit_id','شناسه بنر'),sw('ad_interstitial_enabled','تبلیغ بینابینی'),field('ad_interstitial_unit_id','شناسه بینابینی'),sw('ad_rewarded_enabled','تبلیغ جایزه‌ای'),field('ad_rewarded_unit_id','شناسه جایزه‌ای')]),
    FilledButton.icon(onPressed:busy?null:saveConfig,icon:const Icon(Icons.cloud_upload),label:const Text('ذخیره تنظیمات در دیتابیس'))
  ]);
  Widget stat(String k,int v)=>Card(color:panel,child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[Text(v.toString(),style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.bold)),Text(k,style:const TextStyle(color:Colors.white70))])));
  Widget overview()=>RefreshIndicator(onRefresh:reload,child:ListView(padding:const EdgeInsets.all(14),children:[
    GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,children:stats.entries.map((e)=>stat(e.key,e.value)).toList()),
    section('وضعیت',[Text('حساب مالک: '+(db.auth.currentUser?.email??'')),Text('پرداخت: '+(config['payment_enabled']==true?'فعال':'غیرفعال')),Text('آخرین تغییر: '+(config['updated_at']?.toString()??'نامشخص'))]),
    FilledButton.icon(onPressed:reload,icon:const Icon(Icons.refresh),label:const Text('به‌روزرسانی'))
  ]));
  Widget listPage(List<Map<String,dynamic>> rows,Widget Function(Map<String,dynamic>) build,String empty,{VoidCallback? add})=>Stack(children:[
    RefreshIndicator(onRefresh:reload,child:ListView(padding:const EdgeInsets.all(10),children:rows.isEmpty?[Padding(padding:const EdgeInsets.all(30),child:Text(empty,textAlign:TextAlign.center))]:rows.map(build).toList())),
    if(add!=null)Positioned(left:15,bottom:15,child:FloatingActionButton(onPressed:add,child:const Icon(Icons.add)))
  ]);
  Widget usersPage()=>listPage(users,(u)=>Card(color:panel,child:ListTile(title:Text(u['display_name']?.toString().isNotEmpty==true?u['display_name'].toString():(u['email']??'کاربر').toString()),subtitle:Text((u['email']??u['id']).toString()+' • '+(u['plan_code']??'free').toString()),trailing:const Icon(Icons.edit,color:purple),onTap:()=>editUser(u))),'کاربری ثبت نشده است.');
  Widget modelsPage()=>listPage(models,(m)=>Card(color:panel,child:ListTile(title:Text(m['display_name'].toString()),subtitle:Text(m['provider'].toString()+' / '+m['model_id'].toString()+' • '+(m['is_active']==true?'فعال':'غیرفعال')),trailing:const Icon(Icons.edit,color:purple),onTap:()=>editModel(m))),'مدلی ثبت نشده است.',add:()=>editModel());
  Widget assistantsPage()=>listPage(assistants,(a)=>Card(color:panel,child:ListTile(title:Text(a['icon'].toString()+' '+a['name'].toString()),subtitle:Text(a['model'].toString()+' • '+(a['is_active']==true?'فعال':'غیرفعال')),trailing:const Icon(Icons.edit,color:purple),onTap:()=>editAssistant(a))),'دستیار ثبت نشده است.',add:()=>editAssistant());
  Widget plansPage()=>listPage(plans,(p)=>Card(color:panel,child:ListTile(title:Text(p['display_name'].toString()+' ('+p['plan_code'].toString()+')'),subtitle:Text(p['daily_request_limit'].toString()+' درخواست • '+p['duration_days'].toString()+' روز'),trailing:const Icon(Icons.edit,color:purple),onTap:()=>editPlan(p))),'پلنی ثبت نشده است.');
  Widget purchasesPage()=>listPage(purchases,(p)=>Card(color:panel,child:ListTile(title:Text(p['amount'].toString()+' '+p['currency'].toString()+' • '+p['plan_code'].toString()),subtitle:Text(p['provider'].toString()+' • '+p['status'].toString()+' • '+p['created_at'].toString()))),'خریدی در دیتابیس ثبت نشده است.');
  void toast(String s,[bool bad=false]){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),backgroundColor:bad?Colors.red.shade800:Colors.green.shade800));}
  @override Widget build(BuildContext context){
    if(checking)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(!allowed)return Scaffold(appBar:AppBar(title:const Text('پنل مالک')),body:Center(child:Text(errorText??'دسترسی مجاز نیست.')));
    final pages=[overview(),settingsPage(),usersPage(),modelsPage(),assistantsPage(),plansPage(),purchasesPage()];
    return Directionality(textDirection:TextDirection.rtl,child:Scaffold(backgroundColor:const Color(0xFF0F0F1A),appBar:AppBar(title:const Text('پنل مدیریت وارنیکس'),actions:[IconButton(onPressed:busy?null:reload,icon:const Icon(Icons.refresh))],bottom:TabBar(controller:tabs,isScrollable:true,indicatorColor:purple,tabs:const [Tab(text:'نمای کلی'),Tab(text:'تنظیمات'),Tab(text:'کاربران'),Tab(text:'مدل‌ها'),Tab(text:'دستیارها'),Tab(text:'پلن‌ها'),Tab(text:'خریدها')])),body:Stack(children:[TabBarView(controller:tabs,children:pages),if(busy)const Align(alignment:Alignment.topCenter,child:LinearProgressIndicator())])));
  }
  @override void dispose(){tabs.dispose();for(final c in fields.values){c.dispose();}super.dispose();}
}
