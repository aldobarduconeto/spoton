class Ticket {
  final String id;
  final int eventId;
  final String eventName;
  final DateTime eventDate;
  final String location;
  final String ticketCode;
  final double price;
  final int quantity;
  final DateTime purchaseDate;

  Ticket({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.location,
    required this.ticketCode,
    required this.price,
    this.quantity = 1,
    DateTime? purchaseDate,
  }) : purchaseDate = purchaseDate ?? DateTime.now();

  String get formattedTotal => price <= 0
      ? 'Gratuito'
      : 'R\$ ${(price * quantity).toStringAsFixed(2).replaceAll('.', ',')}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'eventName': eventName,
    'eventDate': eventDate.toIso8601String(),
    'location': location,
    'ticketCode': ticketCode,
    'price': price,
    'quantity': quantity,
    'purchaseDate': purchaseDate.toIso8601String(),
  };

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
    id: json['id'] as String,
    eventId: json['eventId'] as int,
    eventName: json['eventName'] as String,
    eventDate: DateTime.parse(json['eventDate'] as String),
    location: json['location'] as String,
    ticketCode: json['ticketCode'] as String,
    price: (json['price'] as num).toDouble(),
    quantity: json['quantity'] as int? ?? 1,
    purchaseDate: DateTime.parse(json['purchaseDate'] as String),
  );
}
