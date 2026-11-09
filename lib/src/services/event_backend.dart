import 'package:spoton/src/models/event.dart';
import 'package:spoton/src/models/ticket.dart';

/// Contract shared by Firebase and deterministic service tests.
abstract interface class EventBackend {
  String? get currentUserId;
  Stream<String?> get authChanges;
  Stream<List<Event>> watchEvents();
  Stream<List<Ticket>> watchTickets(String userId);
  Stream<Set<int>> watchFavorites(String userId);
  Future<Event> createEvent(Event event);
  Future<void> updateEvent(Event event);
  Future<bool> removeEvent(int eventId);
  Future<void> setFavorite(int eventId, bool favorite);
  Future<Ticket> purchaseTicket(int eventId, int quantity);
  Future<void> cancelTicket(String ticketId);
}

/// Descoberta paginada sem assinatura da coleção pública inteira.
class EventPage {
  final List<Event> events;
  final Object? cursor;
  final bool hasMore;
  const EventPage({required this.events, this.cursor, required this.hasMore});
}

abstract interface class PagedEventBackend {
  Future<EventPage> fetchEventPage({
    required DateTime activeAfter,
    Object? cursor,
  });
  Stream<List<Event>> watchOwnedEvents(String userId);
}
