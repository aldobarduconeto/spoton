import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spoton/src/models/event.dart';
import 'package:spoton/src/models/ticket.dart';
import 'package:spoton/src/services/event_backend.dart';

class FirebaseEventBackend implements EventBackend, PagedEventBackend {
  final FirebaseFirestore database;
  final FirebaseAuth auth;
  FirebaseEventBackend({FirebaseFirestore? database, FirebaseAuth? auth})
    : database = database ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;

  @override
  String? get currentUserId => auth.currentUser?.uid;
  @override
  Stream<String?> get authChanges =>
      auth.authStateChanges().map((u) => u?.uid).distinct();
  String get _uid =>
      currentUserId ??
      (throw StateError(
        'Entre na sua conta nas configurações para continuar.',
      ));
  CollectionReference<Map<String, dynamic>> get _events =>
      database.collection('events');
  CollectionReference<Map<String, dynamic>> _tickets(String uid) =>
      database.collection('users').doc(uid).collection('tickets');
  CollectionReference<Map<String, dynamic>> _favorites(String uid) =>
      database.collection('users').doc(uid).collection('favorites');

  static Event decodeEvent(Map<String, dynamic> data) => Event.fromJson({
    ...data,
    'startAt': (data['startTime'] as Timestamp).toDate().toIso8601String(),
    'endAt': (data['endTime'] as Timestamp).toDate().toIso8601String(),
  });
  static Ticket decodeTicket(Map<String, dynamic> data) => Ticket.fromJson({
    ...data,
    'eventDate': (data['eventDate'] as Timestamp).toDate().toIso8601String(),
    'purchaseDate':
        ((data['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now())
            .toIso8601String(),
  });
  Map<String, dynamic> _eventData(Event event) {
    final data = event.toJson()
      ..remove('startAt')
      ..remove('endAt');
    return {
      ...data,
      'startTime': Timestamp.fromDate(event.startAt),
      'endTime': Timestamp.fromDate(event.endAt),
    };
  }

  static const pageSize = 40;

  @override
  Future<EventPage> fetchEventPage({
    required DateTime activeAfter,
    Object? cursor,
  }) async {
    Query<Map<String, dynamic>> query = _events
        .where('endTime', isGreaterThan: Timestamp.fromDate(activeAfter))
        .orderBy('endTime')
        .orderBy(FieldPath.documentId)
        .limit(pageSize);
    if (cursor != null) {
      query = query.startAfterDocument(
        cursor as DocumentSnapshot<Map<String, dynamic>>,
      );
    }
    final result = await query.get().timeout(const Duration(seconds: 20));
    return EventPage(
      events: result.docs.map((d) => decodeEvent(d.data())).toList(),
      cursor: result.docs.isEmpty ? cursor : result.docs.last,
      hasMore: result.docs.length == pageSize,
    );
  }

  @override
  Stream<List<Event>> watchOwnedEvents(String userId) => _events
      .where('ownerId', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.map((d) => decodeEvent(d.data())).toList());

  @override
  Stream<List<Event>> watchEvents() => _events
      .where('endTime', isGreaterThan: Timestamp.now())
      .orderBy('endTime')
      .limit(pageSize)
      .snapshots()
      .map((s) => s.docs.map((d) => decodeEvent(d.data())).toList());
  @override
  Stream<List<Ticket>> watchTickets(String userId) =>
      _tickets(userId).snapshots().map((s) {
        final tickets = s.docs.map((d) => decodeTicket(d.data())).toList();
        tickets.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
        return tickets;
      });
  @override
  Stream<Set<int>> watchFavorites(String userId) =>
      _favorites(userId)
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()['eventId'] as int).toSet());

  @override
  Future<Event> createEvent(Event event) async {
    final uid = _uid;
    final owned = event.copyWith(ownerId: uid);
    final ref = _events.doc('${event.eventID}');
    await database.runTransaction((transaction) async {
      if ((await transaction.get(ref)).exists)
        throw StateError('Este evento já existe.');
      transaction.set(ref, {
        ..._eventData(owned),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return owned;
  }

  @override
  Future<void> updateEvent(Event event) async {
    final uid = _uid;
    final ref = _events.doc('${event.eventID}');
    await database.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists || snapshot.data()!['ownerId'] != uid)
        throw StateError('Somente o organizador pode editar o evento.');
      transaction.update(ref, _eventData(event.copyWith(ownerId: uid)));
    });
  }

  @override
  Future<bool> removeEvent(int eventId) async {
    final uid = _uid;
    return database.runTransaction((transaction) async {
      final ref = _events.doc('$eventId');
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return false;
      if (snapshot.data()!['ownerId'] != uid)
        throw StateError('Somente o organizador pode remover o evento.');
      transaction.delete(ref);
      return true;
    });
  }

  @override
  Future<void> setFavorite(int eventId, bool favorite) async {
    final ref = _favorites(_uid).doc('$eventId');
    if (favorite) {
      await ref.set({'eventId': eventId});
    } else {
      await ref.delete();
    }
  }

  @override
  Future<Ticket> purchaseTicket(int eventId, int quantity) async {
    final uid = _uid;
    if (quantity < 1 || quantity > 10)
      throw ArgumentError('Escolha de 1 a 10 ingressos.');
    final ref = _tickets(uid).doc();
    return database.runTransaction((transaction) async {
      final snapshot = await transaction.get(_events.doc('$eventId'));
      if (!snapshot.exists) throw StateError('Evento indisponível.');
      final event = decodeEvent(snapshot.data()!);
      if (!event.isFree || !event.startAt.isAfter(DateTime.now()))
        throw StateError('Emissão gratuita indisponível para este evento.');
      final ticket = Ticket(
        id: ref.id,
        eventId: eventId,
        eventName: event.nome,
        eventDate: event.startAt,
        location: event.local,
        ticketCode: ref.id,
        price: 0,
        quantity: quantity,
      );
      transaction.set(ref, {
        ...ticket.toJson(),
        'eventDate': Timestamp.fromDate(event.startAt),
        'purchaseDate': FieldValue.serverTimestamp(),
        'userId': uid,
        'eventRef': '$eventId',
      });
      return ticket;
    });
  }

  @override
  Future<void> cancelTicket(String ticketId) =>
      _tickets(_uid).doc(ticketId).delete();
}
