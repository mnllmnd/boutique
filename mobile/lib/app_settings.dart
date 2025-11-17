import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  String _locale = 'fr_FR';
  String _currency = 'XOF';
  Map<String, double> _rates = {'XOF': 1.0, 'EUR': 0.0015, 'USD': 0.0017};
  String? _ownerPhone;

  String get locale => _locale;
  String get currency => _currency;
  Map<String, double> get rates => _rates;

  Future<void> initForOwner(String ownerPhone) async {
    _ownerPhone = ownerPhone;
    final prefs = await SharedPreferences.getInstance();
    final l = prefs.getString('locale_${ownerPhone}');
    final c = prefs.getString('currency_${ownerPhone}');
    final r = prefs.getString('rates_${ownerPhone}');
    if (l != null) _locale = l;
    if (c != null) _currency = c;
    if (r != null) {
      try {
        final Map parsed = json.decode(r) as Map;
        _rates = parsed.map((k, v) => MapEntry(k as String, (v as num).toDouble()));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    if (_ownerPhone != null) await prefs.setString('locale_${_ownerPhone}', locale);
    notifyListeners();
  }

  Future<void> setCurrency(String currency) async {
    _currency = currency;
    final prefs = await SharedPreferences.getInstance();
    if (_ownerPhone != null) await prefs.setString('currency_${_ownerPhone}', currency);
    notifyListeners();
  }

  Future<void> setRates(Map<String, double> rates) async {
    _rates = rates;
    final prefs = await SharedPreferences.getInstance();
    if (_ownerPhone != null) await prefs.setString('rates_${_ownerPhone}', json.encode(rates));
    notifyListeners();
  }

  double convertFromXof(num amount) {
    final rate = _rates[_currency] ?? 1.0;
    return (amount.toDouble()) * rate;
  }

  String formatCurrency(dynamic value) {
    if (value == null) return '-';
    final num? parsed = (value is num) ? value : num.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final converted = convertFromXof(parsed);
    // For XOF (FCFA) we want format like "500 FCFA" (no decimals, currency after amount)
    if (_currency == 'XOF') {
      return '${converted.toStringAsFixed(0)} FCFA';
    }

    // For other currencies (EUR, USD) use locale-aware formatting with 2 decimals
    final symbol = _currency == 'EUR' ? '€' : r'$';
    try {
      final fmt = NumberFormat.currency(locale: _locale, symbol: symbol, name: _currency, decimalDigits: 2);
      return fmt.format(converted);
    } catch (_) {
      return '${converted.toStringAsFixed(2)} $symbol';
    }
  }
}
