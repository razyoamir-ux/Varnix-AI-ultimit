import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerContentManagerScreen extends StatefulWidget {
  const OwnerContentManagerScreen({super.key});
  @override State<OwnerContentManagerScreen> createState()=>_OwnerContentManagerScreenState();
}

class _OwnerContentManagerScreenState extends State<OwnerContentManagerScreen> {
  final db=Supabase.instance.client;
  static const panel=Color(0xFF211936), purple=Color(0xFFA78BFA);
  static const tables=<String,String>{
    'content_documents':'متن‌های برنامه','other_apps':'سایر برنامه‌ها','app_releases':'نسخه‌ها و اطلاعیه‌ها',
    'tutorials':'آموزش‌ها','prompt_templates':'قالب‌های آماده پرامپت','addons':'افزونه‌ها'
  };
  String selected='content_documents';
  bool loading=true,saving=false;
  List<Map<String,dynamic>> rows=[];
  String? error;
  @override void initState(){super.initState();load();}
  String err(Object e)=>e.toString().replaceFirst('Exception: ','');
  Future<void> load() async {
    setState(()=>loading=true);
    try { final result=await db.from(selected).select().order(selected=='app_releases'?'created_at':'updated_at',ascending:false).limit(250); rows=List<Map<String,dynamic>>.from(result); error=null; }
    catch(e) { rows=[]; error=err(e); }
    if(mounted)setState(()=>loading=false);
  }
  List<String> get textFields=>switch(selected){
    'content_documents'=>['slug','title','body','version'],
    'other_apps'=>['name','slug','description','store_url'],
    'app_releases'=>['version','title','notes','download_url','min_supported_version'],
    'tutorials'=>['title','category','body','image_url','video_url'],
    'prompt_templates'=>['title','category','prompt'],
    _=>['slug','name','description','icon','config','min_app_version']
  };
  List<String> get boolFields=>switch(selected){
    'content_documents'=>['is_published'],'other_apps'=>['is_active'],
    'app_releases'=>['is_mandatory','is_published'],'tutorials'=>['is_published'],
    'prompt_templates'=>['is_published'],'addons'=>['requires_pro','is_enabled'],_=>[]
  };
  List<String> get intFields=>switch(selected){
    'other_apps'=>['sort_order'],'app_releases'=>['build_number'],
    'tutorials'=>['sort_order'],'prompt_templates'=>['sort_order'],'addons'=>['sort_order'],_=>[]
  };
  String label(String k)=>const <String,String>{
    'slug':'شناسه یکتا','title':'عنوان','body':'متن کامل','version':'نسخه','name':'نام','description':'توضیحات',
    'store_url':'لینک فروشگاه','notes':'تغییرات این نسخه','download_url':'لینک دانلود','build_number':'شماره ساخت',
    'is_mandatory':'به‌روزرسانی اجباری','min_supported_version':'حداقل نسخه پشتیبانی‌شده','category':'دسته‌بندی',
    'image_url':'لینک تصویر','video_url':'لینک ویدئو','prompt':'متن پرامپت','icon':'نام آیکون','config':'تنظیمات JSON',
    'min_app_version':'حداقل نسخه اپ','sort_order':'ترتیب نمایش','is_published':'منتشر شده','is_active':'فعال',
    'requires_pro':'ویژه حرفه‌ای','is_enabled':'فعال‌سازی افزونه'
  }[k]??k;
  String initial(String k,Map<String,dynamic>? old){
    if(old!=null&&old[k]!=null)return k=='config'?const JsonEncoder.withIndent('  ').convert(old[k]):old[k].toString();
    if(k=='version')return '1.0'; if(k=='icon')return 'extension'; if(k=='config')return '{}';
    if(k=='category')return 'عمومی'; if(k=='slug')return selected=='content_documents'?'about':'';
    return '0';
  }
  Widget input(String k,TextEditingController c){
    final multi=['body','notes','prompt','description','config'].contains(k);
    return Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:c,maxLines:multi?5:1,
      keyboardType:k.endsWith('_url')?TextInputType.url:TextInputType.text,
      decoration:InputDecoration(labelText:label(k),border:const OutlineInputBorder(),helperText:k.endsWith('_url')?'لینک باید با https:// شروع شود.':null)));
  }
  Future<void> edit([Map<String,dynamic>? old]) async {
    final controllers=<String,TextEditingController>{for(final k in textFields) k:TextEditingController(text:initial(k,old))};
    final bools=<String,bool>{for(final k in boolFields) k:(old?[k]==true)||(old==null&&['is_published','is_active'].contains(k))};
    final nums=<String,TextEditingController>{for(final k in intFields) k:TextEditingController(text:initial(k,old))};
    final status=TextEditingController(text:old?['status']?.toString()??'coming_soon');
    final capability=TextEditingController(text:old?['capability_type']?.toString()??'feature_flag');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
      backgroundColor:panel,title:Text((old==null?'افزودن ':'ویرایش ')+tables[selected]!),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        if(selected=='content_documents') DropdownButtonFormField<String>(
          value:['about','terms','privacy'].contains(controllers['slug']!.text)?controllers['slug']!.text:'about',
          decoration:const InputDecoration(labelText:'نوع متن'),
          items:const [DropdownMenuItem(value:'about',child:Text('درباره ما')),DropdownMenuItem(value:'terms',child:Text('شرایط و قوانین')),DropdownMenuItem(value:'privacy',child:Text('حریم خصوصی'))],
          onChanged:(v)=>refresh(()=>controllers['slug']!.text=v??'about')),
        ...textFields.where((k)=>!(selected=='content_documents'&&k=='slug')).map((k)=>input(k,controllers[k]!)),
        if(selected=='other_apps') DropdownButtonFormField<String>(value:['coming_soon','published'].contains(status.text)?status.text:'coming_soon',
          decoration:const InputDecoration(labelText:'وضعیت'),items:const [DropdownMenuItem(value:'coming_soon',child:Text('به‌زودی')),DropdownMenuItem(value:'published',child:Text('منتشر شده'))],onChanged:(v)=>refresh(()=>status.text=v??'coming_soon')),
        if(selected=='addons') DropdownButtonFormField<String>(value:['feature_flag','remote_content','external_link'].contains(capability.text)?capability.text:'feature_flag',
          decoration:const InputDecoration(labelText:'نوع قابلیت امن'),items:const [DropdownMenuItem(value:'feature_flag',child:Text('قابلیت روشن/خاموش')),DropdownMenuItem(value:'remote_content',child:Text('محتوای آنلاین')),DropdownMenuItem(value:'external_link',child:Text('لینک خارجی'))],onChanged:(v)=>refresh(()=>capability.text=v??'feature_flag')),
        ...nums.entries.map((e)=>input(e.key,e.value)),
        ...bools.entries.map((e)=>SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(label(e.key)),value:e.value,onChanged:(v)=>refresh(()=>bools[e.key]=v)))
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('ذخیره'))]
    )));
    if(ok==true){
      try{
        final row=<String,dynamic>{};
        for(final k in textFields){final raw=controllers[k]!.text.trim();if(k=='config'){final decoded=jsonDecode(raw);if(decoded is! Map)throw Exception('تنظیمات افزونه باید JSON object باشد.');row[k]=decoded;}else{row[k]=raw;}}
        for(final e in nums.entries){final v=int.tryParse(e.value.text.trim());if(v==null)throw Exception('فیلد '+label(e.key)+' باید عدد صحیح باشد.');row[e.key]=v;}
        row.addAll(bools);
        if(selected=='other_apps')row['status']=status.text;
        if(selected=='addons')row['capability_type']=capability.text;
        if(selected=='content_documents'&&!['about','terms','privacy'].contains(row['slug']))throw Exception('شناسه متن معتبر نیست.');
        for(final k in ['store_url','download_url','image_url','video_url']){final v=row[k]?.toString()??'';if(v.isNotEmpty&&Uri.tryParse(v)?.scheme!='https')throw Exception('لینک '+label(k)+' باید HTTPS باشد.');}
        if(selected=='addons'&&!['feature_flag','remote_content','external_link'].contains(row['capability_type']))throw Exception('نوع افزونه مجاز نیست.');
        if(selected!='app_releases')row['updated_at']=DateTime.now().toUtc().toIso8601String();
        setState(()=>saving=true);
        if(old==null){await db.from(selected).insert(row);}else{await db.from(selected).update(row).eq('id',old['id']);}
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('محتوا با موفقیت ذخیره شد.')));
        await load();
      }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(err(e)),backgroundColor:Colors.red.shade800));}
      finally{if(mounted)setState(()=>saving=false);}
    }
    for(final c in controllers.values){c.dispose();}for(final c in nums.values){c.dispose();}status.dispose();capability.dispose();
  }
  Future<void> remove(Map<String,dynamic> r) async {
    final name=(r['title']??r['name']??r['version']??r['slug']??'این مورد').toString();
    final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(backgroundColor:panel,title:const Text('حذف محتوا؟'),content:Text('«'+name+'» حذف شود؟'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));
    if(yes==true){try{await db.from(selected).delete().eq('id',r['id']);await load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(err(e)),backgroundColor:Colors.red.shade800));}}
  }
  String titleOf(Map<String,dynamic> r)=>(r['title']??r['name']??r['version']??r['slug']??'بدون عنوان').toString();
  String subtitleOf(Map<String,dynamic> r){
    if(selected=='content_documents')return 'نسخه '+(r['version']??'1.0').toString()+' • '+(r['is_published']==true?'منتشر':'پیش‌نویس');
    if(selected=='other_apps')return (r['status']??'').toString()+' • '+(r['is_active']==true?'فعال':'غیرفعال');
    if(selected=='app_releases')return (r['is_published']==true?'منتشر':'پیش‌نویس')+' • '+(r['is_mandatory']==true?'اجباری':'عادی');
    if(selected=='tutorials'||selected=='prompt_templates')return (r['category']??'').toString()+' • '+(r['is_published']==true?'منتشر':'پیش‌نویس');
    return (r['capability_type']??'').toString()+' • '+(r['is_enabled']==true?'فعال':'خاموش');
  }
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(12,12,12,4),child:DropdownButtonFormField<String>(value:selected,decoration:const InputDecoration(labelText:'بخش قابل مدیریت',border:OutlineInputBorder()),
      items:tables.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v){if(v!=null){setState(()=>selected=v);load();}})),
    Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),child:Row(children:[
      const Expanded(child:Text('محتوای این بخش از دیتابیس خوانده می‌شود و تغییرات پس از ذخیره آنلاین خواهد شد.',style:TextStyle(color:Colors.white60,fontSize:12))),
      IconButton(onPressed:loading?null:load,icon:const Icon(Icons.refresh,color:purple))])),
    Expanded(child:loading?const Center(child:CircularProgressIndicator()):error!=null
      ?Center(child:Padding(padding:const EdgeInsets.all(20),child:Text('بارگذاری انجام نشد. احتمالاً مهاجرت دیتابیس هنوز اجرا نشده یا دسترسی مالک تنظیم نیست.\n\n'+error!,textAlign:TextAlign.center,style:const TextStyle(color:Colors.orangeAccent))))
      :rows.isEmpty?const Center(child:Text('هنوز موردی ثبت نشده است.',style:TextStyle(color:Colors.white70)))
      :ListView.builder(itemCount:rows.length,itemBuilder:(ctx,i){final r=rows[i];return Card(color:panel,margin:const EdgeInsets.symmetric(horizontal:12,vertical:5),
        child:ListTile(title:Text(titleOf(r),style:const TextStyle(color:Colors.white)),subtitle:Text(subtitleOf(r),style:const TextStyle(color:Colors.white60)),
          trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')edit(r);if(v=='delete')remove(r);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('ویرایش')),PopupMenuItem(value:'delete',child:Text('حذف'))])));})),
    Padding(padding:const EdgeInsets.all(12),child:SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:saving?null:()=>edit(),icon:const Icon(Icons.add),label:const Text('افزودن مورد جدید'))))
  ]));
}
