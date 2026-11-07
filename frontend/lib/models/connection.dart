class Connection {
  final String connectionId;
  final String userId;
  final String displayName;
  final String role;
  final String? photoUrl;
  final DateTime timestamp;
  final String method;
  final String location;
  final String notes;
  final List<String> tags;

  Connection({
    required this.connectionId,
    required this.userId,
    required this.displayName,
    required this.role,
    this.photoUrl,
    required this.timestamp,
    required this.method,
    required this.location,
    required this.notes,
    required this.tags,
  });

  Connection copyWith({String? notes, List<String>? tags}) => Connection(
    connectionId: connectionId,
    userId: userId,
    displayName: displayName,
    role: role,
    photoUrl: photoUrl,
    timestamp: timestamp,
    method: method,
    location: location,
    notes: notes ?? this.notes,
    tags: tags ?? this.tags,
  );

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      connectionId: json['connectionId'],
      userId: json['userId'],
      displayName: json['displayName'],
      role: json['role'],
      photoUrl: json['photoUrl'],
      timestamp: DateTime.parse(json['timestamp']),
      method: json['method'],
      location: json['location'],
      notes: json['notes'],
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'connectionId': connectionId,
      'userId': userId,
      'displayName': displayName,
      'role': role,
      'photoUrl': photoUrl,
      'timestamp': timestamp.toIso8601String(),
      'method': method,
      'location': location,
      'notes': notes,
      'tags': tags,
    };
  }
}
