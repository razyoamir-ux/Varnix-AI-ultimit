import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});
  @override State<DocumentsScreen> createState()=>_DocumentsScreenState();
}
class _DocumentsScreenState extends State<DocumentsScreen>{
  static const _key='varnix_local_documents_v1',_panel=Color(0xFF211936),_purple=Color(0xFFA78BFA);
  List<Map<String,dynamic>> _docs=[];bool _loading=true;String _query='';
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{final p=await SharedPreferences.getInstance();final raw=p.getString(_key);try{_docs=raw==null?[]:(jsonDecode(raw) as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();}catch(_){_docs=[];}if(mounted)setState(()=>_loading=false);}
  Future<void> _save()async{final p=await SharedPreferences.getInstance();await p.setString(_key,jsonEncode(_docs));}
  Future<void> _edit([Map<String,dynamic>? old])async{
    final title=TextEditingController(text:old?['title']?.toString()??'');
    final category=TextEditingController(text:old?['category']?.toString()??'عمومی');
    final body=TextEditingController(text:old?['body']?.toString()??'');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(backgroundColor:_panel,title:Text(old==null?'سند جدید':'ویرایش سند'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان سند')),
        TextField(controller:category,decoration:const InputDecoration(labelText:'دسته‌بندی')),
        TextField(controller:body,minLines:8,maxLines:14,decoration:const InputDecoration(labelText:'متن سند یا یادداشت')),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('ذخیره'))]));
    if(ok==true){
      if(title.text.trim().isEmpty||body.text.trim().isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('عنوان و متن سند را وارد کن.')));}
      else{
        final item=<String,dynamic>{'id':old?['id']??DateTime.now().microsecondsSinceEpoch.toString(),'title':title.text.trim(),'category':category.text.trim(),'body':body.text,'updated_at':DateTime.now().toIso8601String()};
        if(old==null)_docs.insert(0,item);else{final i=_docs.indexWhere((e)=>e['id']==old['id']);if(i>=0)_docs[i]=item;}
        await _save();if(mounted)setState((){});
      }
    }
    title.dispose();category.dispose();body.dispose();
  }
  Future<void> _delete(Map<String,dynamic>d)async{
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(backgroundColor:_panel,title:const Text('حذف سند؟'),content:Text('«'+d['title'].toString()+'» حذف شود؟'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حذف'))]));
    if(yes==true){_docs.removeWhere((e)=>e['id']==d['id']);await _save();if(mounted)setState((){});}
  }
  Future<void> _copy(Map<String,dynamic>d)async{await Clipboard.setData(ClipboardData(text:d['body'].toString()));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('متن سند کپی شد.')));}
  Future<void> _view(Map<String,dynamic>d)async{await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(backgroundColor:_panel,title:Text(d['title'].toString()),content:SizedBox(width:double.maxFinite,child:SingleChildScrollView(child:SelectableText(d['body'].toString(),style:const TextStyle(color:Colors.white,height:1.6)))),actions:[TextButton(onPressed:()=>_copy(d),child:const Text('کپی')),TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('بستن'))]));}
  @override Widget build(BuildContext context){
    final visible=_docs.where((d)=>(d['title'].toString()+' '+d['category'].toString()+' '+d['body'].toString()).toLowerCase().contains(_query.toLowerCase())).toList();
    return Directionality(textDirection:TextDirection.rtl,child:Scaffold(backgroundColor:const Color(0xFF0F0F1A),
      appBar:AppBar(title:const Text('فایل‌ها و اسناد من'),backgroundColor:const Color(0xFF1A1030),foregroundColor:Colors.white),
      floatingActionButton:FloatingActionButton.extended(onPressed:()=>_edit(),icon:const Icon(Icons.note_add),label:const Text('سند جدید')),
      body:_loading?const Center(child:CircularProgressIndicator()):Column(children:[
        Padding(padding:const EdgeInsets.all(14),child:TextField(onChanged:(v)=>setState(()=>_query=v),style:const TextStyle(color:Colors.white),decoration:InputDecoration(hintText:'جست‌وجو در عنوان و متن اسناد...',prefixIcon:const Icon(Icons.search),filled:true,fillColor:_panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none)))),
        Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:Row(children:[const Icon(Icons.phone_android,color:_purple,size:17),const SizedBox(width:6),const Expanded(child:Text('اسناد این بخش فقط روی همین دستگاه ذخیره می‌شوند.',style:TextStyle(color:Colors.white54,fontSize:12))),Text(_docs.length.toString()+' سند',style:const TextStyle(color:_purple))])),
        Expanded(child:visible.isEmpty?Center(child:Text(_docs.isEmpty?'هنوز سندی نساخته‌ای.':'نتیجه‌ای پیدا نشد.',style:const TextStyle(color:Colors.white54))):ListView.builder(padding:const EdgeInsets.all(12),itemCount:visible.length,itemBuilder:(ctx,i){final d=visible[i];return Card(color:_panel,child:ListTile(onTap:()=>_view(d),leading:const Icon(Icons.description_outlined,color:_purple),title:Text(d['title'].toString(),style:const TextStyle(color:Colors.white)),subtitle:Text(d['category'].toString()+' • '+d['updated_at'].toString(),style:const TextStyle(color:Colors.white54,fontSize:11)),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')_edit(d);if(v=='delete')_delete(d);if(v=='copy')_copy(d);},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('ویرایش')),PopupMenuItem(value:'copy',child:Text('کپی متن')),PopupMenuItem(value:'delete',child:Text('حذف'))])));})),
        const SizedBox(height:76)
      ])));
  }
}
