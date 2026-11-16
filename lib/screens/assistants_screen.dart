import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';

class AssistantsScreen extends StatefulWidget {
  const AssistantsScreen({super.key});
  @override State<AssistantsScreen> createState()=>_AssistantsScreenState();
}
class _AssistantsScreenState extends State<AssistantsScreen> {
  static const _key='varnix_personal_assistants_v1',_panel=Color(0xFF211936),_purple=Color(0xFFA78BFA);
  List<Map<String,dynamic>> _public=[],_personal=[];
  bool _loading=true; String? _error;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    setState(()=>_loading=true);
    try{
      final prefs=await SharedPreferences.getInstance();final raw=prefs.getString(_key);
      _personal=raw==null?[]:(jsonDecode(raw) as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
      final rows=await Supabase.instance.client.from('assistants').select('id,name,description,icon,system_prompt,model,sort_order').eq('is_active',true).order('sort_order');
      _public=List<Map<String,dynamic>>.from(rows);_error=null;
    }catch(e){_error=e.toString();}
    if(mounted)setState(()=>_loading=false);
  }
  Future<void> _save()async{final p=await SharedPreferences.getInstance();await p.setString(_key,jsonEncode(_personal));}
  Future<void> _edit([Map<String,dynamic>? old])async{
    final name=TextEditingController(text:old?['name']?.toString()??'');
    final icon=TextEditingController(text:old?['icon']?.toString()??'🤖');
    final desc=TextEditingController(text:old?['description']?.toString()??'');
    final prompt=TextEditingController(text:old?['system_prompt']?.toString()??'');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(backgroundColor:_panel,title:Text(old==null?'ساخت دستیار شخصی':'ویرایش دستیار'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'نام دستیار')),
        TextField(controller:icon,decoration:const InputDecoration(labelText:'ایموجی یا نماد')),
        TextField(controller:desc,decoration:const InputDecoration(labelText:'توضیح کوتاه')),
        TextField(controller:prompt,minLines:5,maxLines:9,decoration:const InputDecoration(labelText:'دستور و نقش دستیار')),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('ذخیره'))]));
    if(ok==true){
      if(name.text.trim().isEmpty||prompt.text.trim().isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('نام و دستور دستیار را وارد کن.')));}
      else{
        final item=<String,dynamic>{'id':old?['id']??DateTime.now().microsecondsSinceEpoch.toString(),'name':name.text.trim(),'icon':icon.text.trim().isEmpty?'🤖':icon.text.trim(),'description':desc.text.trim(),'system_prompt':prompt.text.trim(),'model':'openrouter/free'};
        if(old==null)_personal.add(item);else{final i=_personal.indexWhere((e)=>e['id']==old['id']);if(i>=0)_personal[i]=item;}
        await _save();if(mounted)setState((){});
      }
    }
    name.dispose();icon.dispose();desc.dispose();prompt.dispose();
  }
  Future<void> _delete(Map<String,dynamic> item)async{
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(backgroundColor:_panel,title:const Text('حذف دستیار'),content:Text('دستیار «'+item['name'].toString()+'» حذف شود؟'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('نه')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حذف'))]));
    if(yes==true){_personal.removeWhere((e)=>e['id']==item['id']);await _save();if(mounted)setState((){});}
  }
  void _start(Map<String,dynamic> item){
    final instruction='تو دستیار تخصصی «'+item['name'].toString()+'» هستی. '+(item['description']??'').toString()+'\n\nدستورالعمل اصلی:\n'+item['system_prompt'].toString()+'\n\nهمیشه مطابق این نقش پاسخ بده و به زبان کاربر صحبت کن.';
    Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatScreen(assistantInstruction:instruction)));
  }
  Widget _card(Map<String,dynamic> item,{required bool personal})=>Card(color:_panel,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Text(item['icon']?.toString()??'✨',style:const TextStyle(fontSize:26)),const SizedBox(width:10),Expanded(child:Text(item['name']?.toString()??'دستیار',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:16))),if(personal)PopupMenuButton<String>(onSelected:(v){if(v=='edit')_edit(item);if(v=='delete')_delete(item);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('ویرایش')),PopupMenuItem(value:'delete',child:Text('حذف'))])]),
    if((item['description']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:6,bottom:10),child:Text(item['description'].toString(),style:const TextStyle(color:Colors.white60))),
    Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:()=>_start(item),icon:const Icon(Icons.chat_bubble_outline),label:const Text('شروع گفتگو'),style:FilledButton.styleFrom(backgroundColor:const Color(0xFF6D4CE8))))
  ])));
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(backgroundColor:const Color(0xFF0F0F1A),
    appBar:AppBar(title:const Text('دستیارهای هوشمند'),backgroundColor:const Color(0xFF1A1030),foregroundColor:Colors.white,actions:[IconButton(onPressed:_loading?null:_load,icon:const Icon(Icons.refresh))]),
    floatingActionButton:FloatingActionButton.extended(onPressed:()=>_edit(),icon:const Icon(Icons.add),label:const Text('دستیار شخصی')),
    body:_loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(14),children:[
      const Text('دستیارهای آماده',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:18)),const SizedBox(height:8),
      if(_error!=null)Text('دریافت دستیارهای آماده از سرور انجام نشد؛ دستیارهای شخصی همچنان قابل استفاده‌اند.\n'+_error!,style:const TextStyle(color:Colors.orangeAccent,fontSize:12)),
      if(_public.isEmpty)const Text('فعلاً دستیار آماده‌ای از طرف سازنده منتشر نشده است.',style:TextStyle(color:Colors.white54)),
      ..._public.map((a)=>_card(a,personal:false)),
      const SizedBox(height:16),const Text('دستیارهای شخصی من',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:18)),const SizedBox(height:8),
      if(_personal.isEmpty)const Text('هنوز دستیار شخصی نساخته‌ای. می‌توانی یک نقش دلخواه بسازی و برای گفتگو از آن استفاده کنی.',style:TextStyle(color:Colors.white54)),
      ..._personal.map((a)=>_card(a,personal:true)),const SizedBox(height:80)
    ])));
}
