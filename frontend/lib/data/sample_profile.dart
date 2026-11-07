import '../models/user_profile.dart';

/// Placeholder profile used until sign-up and local storage exist.
final sampleProfile = UserProfile(
  professional: const ProfileData(
    name: 'Alex Johnson',
    bio:
        'Senior Product Manager with 8+ years of experience in tech. '
        'Passionate about building products that solve real-world problems.',
    role: 'Senior Product Manager',
    company: 'Tech Innovations Inc.',
    links: [
      'https://linkedin.com/in/alexjohnson',
      'https://twitter.com/alexjohnson',
    ],
  ),
  personal: const ProfileData(
    name: 'Alex J.',
    bio:
        'Hiking enthusiast and amateur photographer. '
        'Love exploring new places and capturing moments.',
    role: 'Adventure Seeker',
    links: ['https://instagram.com/alexj_adventures'],
  ),
);
