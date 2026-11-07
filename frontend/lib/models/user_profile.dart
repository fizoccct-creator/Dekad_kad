enum ProfileMode { professional, personal }

class UserProfile {
  final ProfileData professional;
  final ProfileData personal;

  const UserProfile({required this.professional, required this.personal});

  ProfileData forMode(ProfileMode mode) =>
      mode == ProfileMode.professional ? professional : personal;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    professional: ProfileData.fromJson(json['professional']),
    personal: ProfileData.fromJson(json['personal']),
  );

  Map<String, dynamic> toJson() => {
    'professional': professional.toJson(),
    'personal': personal.toJson(),
  };
}

class ProfileData {
  final String name;
  final String bio;
  final String role;
  final String? company;
  final List<String> links;
  final String? photoUrl;

  const ProfileData({
    required this.name,
    required this.bio,
    required this.role,
    this.company,
    this.links = const [],
    this.photoUrl,
  });

  ProfileData copyWith({String? bio}) => ProfileData(
    name: name,
    bio: bio ?? this.bio,
    role: role,
    company: company,
    links: links,
    photoUrl: photoUrl,
  );

  factory ProfileData.fromJson(Map<String, dynamic> json) => ProfileData(
    name: json['name'] as String,
    bio: json['bio'] as String? ?? '',
    role: json['role'] as String? ?? '',
    company: json['company'] as String?,
    links: List<String>.from(json['links'] ?? const []),
    photoUrl: json['photoUrl'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'bio': bio,
    'role': role,
    if (company != null) 'company': company,
    'links': links,
    if (photoUrl != null) 'photoUrl': photoUrl,
  };
}
