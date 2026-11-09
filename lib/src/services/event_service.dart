import 'dart:async';

import 'package:spoton/src/services/event_backend.dart';

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:spoton/src/models/event.dart';
import 'package:spoton/src/models/ticket.dart';
import 'package:spoton/src/services/storage_service.dart';
import 'package:spoton/src/services/google_services.dart';

/// Serviço gerenciador de eventos, favoritos e ingressos da aplicação.
class EventService extends ChangeNotifier {
  final StorageService _storageService;
  final EventBackend? _backend;
  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<List<Event>>? _eventsSubscription;
  StreamSubscription<List<Ticket>>? _ticketsSubscription;
  StreamSubscription<Set<int>>? _favoritesSubscription;
  StreamSubscription<List<Event>>? _ownedSubscription;
  List<Event> _ownedEvents = [];
  PagedEventBackend? get _paged =>
      _backend is PagedEventBackend ? _backend as PagedEventBackend : null;
  bool _loadingEvents = false;
  bool _hasMoreEvents = true;
  Object? _eventCursor;
  DateTime _activeAfter = DateTime.now();
  int _feedVersion = 0;
  bool get loadingEvents => _loadingEvents;
  bool get hasMoreEvents => _paged != null && _hasMoreEvents;

  Future<void> loadMoreEvents() => _loadPage();
  Future<void> refreshEvents() => _loadPage(reset: true);

  Future<void> _loadPage({bool reset = false}) async {
    if (_paged == null ||
        _loadingEvents ||
        (!reset && !_hasMoreEvents) ||
        _disposed)
      return;
    final version = _feedVersion;
    final activeAfter = reset ? DateTime.now() : _activeAfter;
    _loadingEvents = true;
    _changed();
    try {
      final page = await _paged!.fetchEventPage(
        activeAfter: activeAfter,
        cursor: reset ? null : _eventCursor,
      );
      if (_disposed || version != _feedVersion) return;
      final merged = {
        if (!reset)
          for (final event in _events) event.eventID: event,
      };
      for (final event in page.events) {
        merged[event.eventID] = event;
      }
      _events
        ..clear()
        ..addAll(merged.values);
      _activeAfter = activeAfter;
      _eventCursor = page.cursor;
      _hasMoreEvents = page.hasMore;
      _syncErrors.remove('eventos');
    } catch (error) {
      if (!_disposed && version == _feedVersion) _syncFailed('eventos', error);
    } finally {
      if (!_disposed && version == _feedVersion) {
        _loadingEvents = false;
        _changed();
      }
    }
  }

  int _session = 0;
  bool _disposed = false;
  String? _userId;
  final Map<String, String> _syncErrors = {};
  bool get isCloudEnabled => _backend != null;
  bool get isSignedIn => _userId != null;
  String? get syncError =>
      _syncErrors.isEmpty ? null : _syncErrors.values.first;
  List<Event> get myEvents => List.unmodifiable(
    _paged != null
        ? _ownedEvents
        : _events.where(
            (e) => !isCloudEnabled || (_userId != null && e.ownerId == _userId),
          ),
  );

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _syncFailed(String channel, Object error) {
    debugPrint('Firebase $channel: $error');
    _syncErrors[channel] =
        'Não foi possível sincronizar $channel. Verifique a conexão e a configuração do Firebase.';
    _changed();
  }

  void _changeUser(String? uid) {
    final session = ++_session;
    _userId = uid;
    unawaited(_ticketsSubscription?.cancel());
    unawaited(_favoritesSubscription?.cancel());
    unawaited(_ownedSubscription?.cancel());
    _ownedEvents = [];
    _tickets = [];
    _favoriteIds = {};
    _pendingFavorites.clear();
    _syncErrors.remove('ingressos');
    _syncErrors.remove('favoritos');
    _syncErrors.remove('meus eventos');
    if (uid != null) {
      if (_paged != null) {
        _ownedSubscription = _paged!
            .watchOwnedEvents(uid)
            .listen(
              (items) {
                if (_session != session || _disposed) return;
                _ownedEvents = items;
                _syncErrors.remove('meus eventos');
                _changed();
              },
              onError: (Object error) {
                if (_session == session && !_disposed)
                  _syncFailed('meus eventos', error);
              },
            );
      }
      _ticketsSubscription = _backend!
          .watchTickets(uid)
          .listen(
            (items) {
              if (_session != session || _disposed) return;
              _tickets = items;
              _syncErrors.remove('ingressos');
              _changed();
            },
            onError: (Object error) {
              if (_session == session && !_disposed)
                _syncFailed('ingressos', error);
            },
          );
      _favoritesSubscription = _backend
          .watchFavorites(uid)
          .listen(
            (items) {
              if (_session != session || _disposed) return;
              _favoriteIds = {...items};
              for (final pending in _pendingFavorites.entries) {
                if (pending.value.session != session) continue;
                if (pending.value.desired) {
                  _favoriteIds.add(pending.key);
                } else {
                  _favoriteIds.remove(pending.key);
                }
              }
              _syncErrors.remove('favoritos');
              _changed();
            },
            onError: (Object error) {
              if (_session == session && !_disposed)
                _syncFailed('favoritos', error);
            },
          );
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _session++;
    _feedVersion++;
    unawaited(_ownedSubscription?.cancel());
    unawaited(_authSubscription?.cancel());
    unawaited(_eventsSubscription?.cancel());
    unawaited(_ticketsSubscription?.cancel());
    unawaited(_favoritesSubscription?.cancel());
    super.dispose();
  }

  final List<Event> _events = [];
  Set<int> _favoriteIds = {};
  List<Ticket> _tickets = [];
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  List<Event> get events => List.unmodifiable(_events);
  List<Ticket> get tickets => List.unmodifiable(_tickets);
  Set<int> get favoriteIds => Set.unmodifiable(_favoriteIds);

  EventService({StorageService? storageService, EventBackend? backend})
    : _storageService = storageService ?? StorageService(),
      _backend = backend;

  /// Inicializa o serviço carregando dados persistidos
  Future<void> init() async {
    if (_isInitialized) return;
    if (_backend != null) {
      _isInitialized = true;
      _changeUser(_backend.currentUserId);
      if (_paged != null) {
        unawaited(loadMoreEvents());
      } else {
        _eventsSubscription = _backend.watchEvents().listen((items) {
          _events
            ..clear()
            ..addAll(items);
          _syncErrors.remove('eventos');
          _changed();
        }, onError: (Object error) => _syncFailed('eventos', error));
      }
      _authSubscription = _backend.authChanges.listen((uid) {
        if (uid != _userId) _changeUser(uid);
      }, onError: (Object error) => _syncFailed('conta', error));
      _changed();
      return;
    }
    try {
      _favoriteIds = await _storageService.getFavoriteIds();
      _tickets = await _storageService.getTickets();
      _events.addAll(await _storageService.getEvents());
    } catch (e) {
      debugPrint('Erro ao inicializar dados do storage: $e');
    } finally {
      _isInitialized = true;
      _changed();
    }
  }

  List<Event> getAllEvents() => List.unmodifiable(_events);

  Event? getEventById(int eventID) {
    for (final event in _events) {
      if (event.eventID == eventID) return event;
    }
    return null;
  }

  Event? get featuredEvent {
    try {
      return _events.firstWhere((e) => e.isFeatured);
    } catch (_) {
      return _events.isNotEmpty ? _events.first : null;
    }
  }

  List<Event> get featuredEvents =>
      List.unmodifiable(_events.where((e) => e.isFeatured));

  List<Event> getEventsByCategory(EventCategory category) =>
      List.unmodifiable(_events.where((event) => event.category == category));

  List<Event> getUpcomingEvents({DateTime? from}) {
    final reference = from ?? DateTime.now();
    final list =
        _events.where((event) => event.endAt.isAfter(reference)).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return List.unmodifiable(list);
  }

  final _searchText = Expando<String>();
  final _searchNames = Expando<String>();
  String _nameKey(Event event) =>
      _searchNames[event] ??= normalizeSearch(event.nome);
  String _textKey(Event event) => _searchText[event] ??= normalizeSearch(
    '${event.nome} ${event.description} ${event.local} ${event.organizer}',
  );

  List<Event> searchEvents(
    String query, {
    EventCategory? category,
    bool favoritesOnly = false,
    bool freeOnly = false,
    double? maxPrice,
    bool upcomingOnly = false,
    DateTime? from,
    DateTime? until,
    EventSort sort = EventSort.date,
  }) {
    final term = normalizeSearch(query.trim());
    final now = DateTime.now();
    final results = _events.where((event) {
      if (category != null && event.category != category) return false;
      if (favoritesOnly && !isFavorite(event.eventID)) return false;
      if (freeOnly && !event.isFree) return false;
      if (maxPrice != null && event.price > maxPrice) return false;
      if (upcomingOnly && !event.endAt.isAfter(now)) return false;
      // Interseção de intervalos: inclui eventos em andamento.
      if (from != null && !event.endAt.isAfter(from)) return false;
      if (until != null && !event.startAt.isBefore(until)) return false;
      return term.isEmpty || _textKey(event).contains(term);
    }).toList();
    results.sort((a, b) {
      final comparison = switch (sort) {
        EventSort.date => a.startAt.compareTo(b.startAt),
        EventSort.price => a.price.compareTo(b.price),
        EventSort.name => _nameKey(a).compareTo(_nameKey(b)),
      };
      return comparison != 0 ? comparison : a.eventID.compareTo(b.eventID);
    });
    return List.unmodifiable(results);
  }

  // --- Favoritos ---
  bool isFavorite(int eventId) => _favoriteIds.contains(eventId);
  final Map<int, ({int session, bool desired})> _pendingFavorites = {};
  bool favoritePending(int id) => _pendingFavorites.containsKey(id);

  Future<void> toggleFavorite(int eventId) async {
    if (favoritePending(eventId)) return;
    final session = _session;
    final wasFavorite = isFavorite(eventId);
    _pendingFavorites[eventId] = (session: session, desired: !wasFavorite);
    if (!wasFavorite)
      _favoriteIds.add(eventId);
    else
      _favoriteIds.remove(eventId);
    _changed();
    try {
      if (_backend != null) {
        await _backend.setFavorite(eventId, !wasFavorite);
      } else {
        await _storageService.saveFavoriteIds(_favoriteIds);
      }
    } catch (_) {
      if (_session == session) {
        if (wasFavorite)
          _favoriteIds.add(eventId);
        else
          _favoriteIds.remove(eventId);
      }
      rethrow;
    } finally {
      if (_pendingFavorites[eventId]?.session == session)
        _pendingFavorites.remove(eventId);
      _changed();
    }
  }

  List<Event> getFavoriteEvents() {
    return List.unmodifiable(
      _events.where((event) => _favoriteIds.contains(event.eventID)),
    );
  }

  // --- Ingressos ---
  Future<Ticket> purchaseTicket(Event event, int quantity) async {
    if (_backend != null)
      return _backend.purchaseTicket(event.eventID, quantity);
    final stored = getEventById(event.eventID);
    if (stored == null) {
      throw ArgumentError("Evento não encontrado.");
    }
    event = stored;
    if (!_isInitialized ||
        getEventById(event.eventID) == null ||
        quantity < 1 ||
        quantity > 10 ||
        !event.startAt.isAfter(DateTime.now())) {
      throw ArgumentError('Evento ou quantidade inválidos.');
    }
    if (!event.isFree) {
      throw StateError(
        'Ingressos pagos são emitidos pelo checkout do organizador.',
      );
    }
    final randomCode =
        'SPT-${DateTime.now().year}-${(Random.secure().nextInt(899999999) + 100000000)}';
    final ticket = Ticket(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      eventId: event.eventID,
      eventName: event.nome,
      eventDate: event.startAt,
      location: event.local,
      ticketCode: randomCode,
      price: event.price,
      quantity: quantity,
    );
    await _storageService.saveTicket(ticket);
    await GoogleServices.logEvent(
      'ticket_created',
      parameters: {'event_id': event.eventID, 'quantity': quantity},
    );
    _tickets.insert(0, ticket);
    _changed();
    return ticket;
  }

  Future<void> cancelTicket(String ticketId) async {
    if (_backend != null) {
      await _backend.cancelTicket(ticketId);
      return;
    }
    await _storageService.removeTicket(ticketId);
    _tickets.removeWhere((t) => t.id == ticketId);
    _changed();
  }

  Future<void> _mutations = Future<void>.value();
  Future<T> _mutate<T>(Future<T> Function() action) {
    final result = _mutations.then((_) {
      if (_disposed) throw StateError('Serviço encerrado.');
      return action();
    });
    _mutations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  // --- Operações CRUD de Eventos ---
  void _validateEvent(Event event) {
    if (event.eventID <= 0 ||
        event.nome.length > 160 ||
        event.description.trim().isEmpty ||
        event.description.length > 10000 ||
        event.local.length > 500 ||
        event.organizer.length > 160 ||
        !event.latitude.isFinite ||
        event.latitude < -90 ||
        event.latitude > 90 ||
        !event.longitude.isFinite ||
        event.longitude < -180 ||
        event.longitude > 180 ||
        event.price > 1000000 ||
        (event.checkoutUrl?.length ?? 0) > 2048 ||
        (event.imageUrl?.length ?? 0) > 2048 ||
        event.nome.trim().isEmpty ||
        event.local.trim().isEmpty ||
        event.organizer.trim().isEmpty ||
        !event.startAt.isAfter(DateTime.now()) ||
        !event.endAt.isAfter(event.startAt) ||
        !event.price.isFinite ||
        event.price < 0) {
      throw ArgumentError("Dados inválidos do evento.");
    }
    if (event.imageUrl != null) {
      final image = Uri.tryParse(event.imageUrl!);
      if (image == null ||
          image.scheme != 'https' ||
          image.host.isEmpty ||
          image.userInfo.isNotEmpty) {
        throw ArgumentError('Imagem deve usar HTTPS.');
      }
    }
    if (!event.isFree || event.checkoutUrl != null) {
      final uri = Uri.tryParse(event.checkoutUrl ?? "");
      if (uri == null ||
          uri.scheme != "https" ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw ArgumentError("Link de compra inválido.");
      }
    }
  }

  Future<void> addEvent(Event event) => _mutate(() => _addEvent(event));

  Future<void> _addEvent(Event event) async {
    _validateEvent(event);
    if (_events.any((item) => item.eventID == event.eventID)) {
      throw ArgumentError('Já existe um evento com o ID ${event.eventID}.');
    }
    if (_backend != null) {
      final created = await _backend.createEvent(event);
      if (_paged != null && !_disposed) {
        _events.removeWhere((e) => e.eventID == created.eventID);
        _events.add(created);
        _changed();
      }
      return;
    }
    await _storageService.saveEvents([..._events, event]);
    _events.add(event);
    _changed();
  }

  Future<void> updateEvent(Event updatedEvent) =>
      _mutate(() => _updateEvent(updatedEvent));

  Future<void> _updateEvent(Event updatedEvent) async {
    _validateEvent(updatedEvent);
    if (_backend != null) {
      await _backend.updateEvent(updatedEvent);
      if (_paged != null && !_disposed) {
        final index = _events.indexWhere(
          (e) => e.eventID == updatedEvent.eventID,
        );
        if (index >= 0) _events[index] = updatedEvent;
        _changed();
      }
      return;
    }
    final index = _events.indexWhere(
      (event) => event.eventID == updatedEvent.eventID,
    );
    if (index == -1) {
      throw ArgumentError(
        'Nenhum evento encontrado com o ID ${updatedEvent.eventID}.',
      );
    }
    final updated = [..._events];
    updated[index] = updatedEvent;
    await _storageService.saveEvents(updated);
    _events[index] = updatedEvent;
    _changed();
  }

  Future<bool> removeEvent(int eventID) => _mutate(() => _removeEvent(eventID));

  Future<bool> _removeEvent(int eventID) async {
    if (_backend != null) {
      final removed = await _backend.removeEvent(eventID);
      if (removed && _paged != null && !_disposed) {
        _events.removeWhere((e) => e.eventID == eventID);
        _changed();
      }
      return removed;
    }
    await _storageService.saveEvents(
      _events.where((e) => e.eventID != eventID).toList(),
    );
    final oldLength = _events.length;
    _events.removeWhere((event) => event.eventID == eventID);
    final changed = _events.length != oldLength;
    if (changed) {
      final favorites = {..._favoriteIds}..remove(eventID);
      _favoriteIds = favorites;
      _changed();
      await _storageService.saveFavoriteIds(favorites);
    }
    return changed;
  }
}

enum EventSort { date, price, name }

String normalizeSearch(String value) {
  const accented = 'áàâãäåéèêëíìîïóòôõöúùûüçñ';
  const plain = 'aaaaaaeeeeiiiiooooouuuucn';
  var result = value.toLowerCase();
  for (var i = 0; i < accented.length; i++) {
    result = result.replaceAll(accented[i], plain[i]);
  }
  return result;
}
