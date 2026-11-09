import 'dart:convert';

import 'package:spoton/src/models/event.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:spoton/src/models/ticket.dart';

class StorageService {
  static const String _favoritesKey = 'spoton_favorites';
  static const String _ticketsKey = 'spoton_tickets';

  Future<SharedPreferences>? _preferences;
  Future<SharedPreferences> get _prefs =>
      _preferences ??= SharedPreferences.getInstance();

  // Compartilhada entre instâncias para proteger operações read-modify-write.
  static Future<void> _writes = Future<void>.value();
  Future<T> _write<T>(Future<T> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<List<T>> _readRecords<T>(
    String key,
    T Function(Map<String, dynamic>) decode,
  ) async {
    final prefs = await _prefs;
    final records = <T>[];
    for (final raw in prefs.getStringList(key) ?? <String>[]) {
      try {
        records.add(decode(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Um registro danificado não invalida os demais.
      }
    }
    return records;
  }

  Future<void> _writeRecords(
    String key,
    Iterable<Map<String, dynamic>> records,
  ) async {
    final prefs = await _prefs;
    final encoded = records.map(jsonEncode).toList();
    final previous = prefs.getStringList(key);
    if (previous != null && _same(previous, encoded)) return;
    if (!await prefs.setStringList(key, encoded)) {
      throw StateError('Não foi possível salvar os dados.');
    }
  }

  bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<Map<String, bool>> getSettings() async {
    final prefs = await _prefs;
    return {
      for (final key in prefs.getKeys().where((k) => k.startsWith('setting_')))
        if (prefs.get(key) is bool) key.substring(8): prefs.getBool(key)!,
    };
  }

  Future<bool> saveSetting(String name, bool value) => _write(() async {
    final prefs = await _prefs;
    final key = 'setting_$name';
    if (prefs.get(key) == value) return true;
    return prefs.setBool(key, value);
  });

  Future<List<Event>> getEvents() =>
      _readRecords('spoton_events', Event.fromJson);

  Future<void> saveEvents(List<Event> events) {
    final snapshot = events.map((e) => e.toJson()).toList();
    return _write(() => _writeRecords('spoton_events', snapshot));
  }

  /// Retorna os IDs dos eventos favoritados
  Future<Set<int>> getFavoriteIds() async {
    final prefs = await _prefs;
    final list = prefs.getStringList(_favoritesKey) ?? [];
    return list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toSet();
  }

  /// Alterna o estado de favorito de um evento
  Future<bool> toggleFavorite(int eventId) => _write(() async {
    final favorites = await getFavoriteIds();
    final bool isFav;
    if (favorites.contains(eventId)) {
      favorites.remove(eventId);
      isFav = false;
    } else {
      favorites.add(eventId);
      isFav = true;
    }
    await _saveFavoriteIds(favorites);
    return isFav;
  });

  Future<void> saveFavoriteIds(Set<int> ids) {
    final snapshot = Set<int>.of(ids);
    return _write(() => _saveFavoriteIds(snapshot));
  }

  Future<void> _saveFavoriteIds(Set<int> ids) async {
    final prefs = await _prefs;
    final encoded = (ids.toList()..sort()).map((id) => '$id').toList();
    if (_same(prefs.getStringList(_favoritesKey) ?? [], encoded)) return;
    if (!await prefs.setStringList(_favoritesKey, encoded)) {
      throw StateError('Não foi possível salvar os favoritos.');
    }
  }

  /// Verifica se um evento é favorito
  Future<bool> isFavorite(int eventId) async {
    final favorites = await getFavoriteIds();
    return favorites.contains(eventId);
  }

  /// Retorna a lista de ingressos do usuário
  Future<List<Ticket>> getTickets() =>
      _readRecords(_ticketsKey, Ticket.fromJson);

  Future<void> saveTicket(Ticket ticket) => _write(() async {
    final tickets = await getTickets();
    await _writeRecords(
      _ticketsKey,
      [
        ticket,
        ...tickets.where((t) => t.id != ticket.id),
      ].map((t) => t.toJson()),
    );
  });

  Future<void> removeTicket(String ticketId) => _write(() async {
    final tickets = await getTickets();
    await _writeRecords(
      _ticketsKey,
      tickets.where((t) => t.id != ticketId).map((t) => t.toJson()),
    );
  });

  /// Limpa todos os dados de ingressos e favoritos
  Future<void> clearAll() => _write(() async {
    final prefs = await _prefs;
    for (final key in [_favoritesKey, _ticketsKey]) {
      if (!await prefs.remove(key))
        throw StateError('Não foi possível limpar os dados.');
    }
  });
}
