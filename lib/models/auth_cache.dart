// lib/models/auth_cache.dart

class AuthCacheEntry {
  final String email;
  final String passwordHash;
  final String salt;
  final int lastOnlineLoginMs;

  AuthCacheEntry({
    required this.email,
    required this.passwordHash,
    required this.salt,
    required this.lastOnlineLoginMs,
  });

  factory AuthCacheEntry.fromDb(Map<String, dynamic> m) => AuthCacheEntry(
        email: m['email'] as String,
        passwordHash: m['password_hash'] as String,
        salt: m['salt'] as String,
        lastOnlineLoginMs: (m['last_online_login_ms'] as num).toInt(),
      );

  Map<String, dynamic> toDb() => {
        'email': email,
        'password_hash': passwordHash,
        'salt': salt,
        'last_online_login_ms': lastOnlineLoginMs,
      };
}