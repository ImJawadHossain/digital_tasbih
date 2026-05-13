import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tasbih_item.dart';

class StorageService {
  static const String _itemsKey = 'tasbih_items_list';

  StorageService._();

  /// Default items to populate if the list is empty
  static List<TasbihItem> _getDefaultItems() {
    return [
      TasbihItem(id: '1', name: 'Subhanallah', targetLimit: 33),
      TasbihItem(id: '2', name: 'Alhamdulillah', targetLimit: 33),
      TasbihItem(id: '3', name: 'Allahuakbar', targetLimit: 34),
      TasbihItem(id: '4', name: 'La ilaha illallah', targetLimit: 100),
    ];
  }

  /// Load all tasbih items
  static Future<List<TasbihItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_itemsKey);

    if (jsonString == null || jsonString.isEmpty) {
      // Return defaults and save them
      final defaults = _getDefaultItems();
      await saveItems(defaults);
      return defaults;
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((jsonItem) => TasbihItem.fromJson(jsonItem)).toList();
    } catch (e) {
      // If there's an error parsing, return defaults
      return _getDefaultItems();
    }
  }

  /// Save all tasbih items
  static Future<void> saveItems(List<TasbihItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_itemsKey, jsonString);
  }
}
