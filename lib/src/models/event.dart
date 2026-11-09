import 'package:flutter/material.dart';

enum EventCategory {
  musica,
  gastronomia,
  arte,
  aoArLivre,
  tecnologia,
  esportes,
  outros;

  String get displayName {
    switch (this) {
      case EventCategory.musica:
        return 'Música';
      case EventCategory.gastronomia:
        return 'Gastronomia';
      case EventCategory.arte:
        return 'Arte';
      case EventCategory.aoArLivre:
        return 'Ao ar livre';
      case EventCategory.tecnologia:
        return 'Tecnologia';
      case EventCategory.esportes:
        return 'Esportes';
      case EventCategory.outros:
        return 'Outros';
    }
  }

  IconData get icon {
    switch (this) {
      case EventCategory.musica:
        return Icons.music_note_rounded;
      case EventCategory.gastronomia:
        return Icons.restaurant_rounded;
      case EventCategory.arte:
        return Icons.palette_outlined;
      case EventCategory.aoArLivre:
        return Icons.park_outlined;
      case EventCategory.tecnologia:
        return Icons.memory_rounded;
      case EventCategory.esportes:
        return Icons.sports_soccer_rounded;
      case EventCategory.outros:
        return Icons.category_outlined;
    }
  }
}

class Event {
  final int eventID;
  final String nome;
  final String description;
  final DateTime startAt;
  final DateTime endAt;
  final String local;
  final EventCategory category;
  final double latitude;
  final double longitude;
  final double price;
  final String organizer;
  final bool isFeatured;
  final String? imageUrl;
  final String? checkoutUrl;
  final String? ownerId;

  const Event({
    required this.eventID,
    required this.nome,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.local,
    required this.category,
    this.latitude = -23.55052,
    this.longitude = -46.633308,
    this.price = 0.0,
    this.organizer = 'Organização Spoton',
    this.isFeatured = false,
    this.imageUrl,
    this.checkoutUrl,
    this.ownerId,
  });

  bool get isFree => price <= 0;

  String get formattedPrice => isFree
      ? 'Gratuito'
      : 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';

  String get categoryName => category.displayName;
  IconData get categoryIcon => category.icon;

  Event copyWith({
    int? eventID,
    String? nome,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    String? local,
    EventCategory? category,
    double? latitude,
    double? longitude,
    double? price,
    String? organizer,
    bool? isFeatured,
    String? imageUrl,
    String? checkoutUrl,
    String? ownerId,
  }) {
    return Event(
      eventID: eventID ?? this.eventID,
      nome: nome ?? this.nome,
      description: description ?? this.description,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      local: local ?? this.local,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      price: price ?? this.price,
      organizer: organizer ?? this.organizer,
      isFeatured: isFeatured ?? this.isFeatured,
      imageUrl: imageUrl ?? this.imageUrl,
      checkoutUrl: checkoutUrl ?? this.checkoutUrl,
      ownerId: ownerId ?? this.ownerId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventID': eventID,
      'nome': nome,
      'description': description,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'local': local,
      'category': category.name,
      'latitude': latitude,
      'longitude': longitude,
      'price': price,
      'organizer': organizer,
      'isFeatured': isFeatured,
      'imageUrl': imageUrl,
      'checkoutUrl': checkoutUrl,
      'ownerId': ownerId,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      eventID: json['eventID'] as int,
      nome: json['nome'] as String,
      description: json['description'] as String,
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: DateTime.parse(json['endAt'] as String),
      local: json['local'] as String,
      category: EventCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => EventCategory.outros,
      ),
      latitude: (json['latitude'] as num?)?.toDouble() ?? -23.55052,
      longitude: (json['longitude'] as num?)?.toDouble() ?? -46.633308,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      organizer: json['organizer'] as String? ?? 'Organização Spoton',
      isFeatured: json['isFeatured'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
      checkoutUrl: json['checkoutUrl'] as String?,
      ownerId: json['ownerId'] as String?,
    );
  }
}
