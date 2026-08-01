/// Anonymous sign-in and profile bootstrap. No email, no password, no OAuth.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/models.dart';

/// Unambiguous alphabet: no 0/O, no 1/I.
const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Stable 6-character code derived from the uid, so a reinstall of the same
/// session keeps the same code.
String inviteCodeFor(String uid) {
  var h = 0x811c9dc5;
  for (final unit in uid.codeUnits) {
    h = (h ^ unit) & 0xffffffff;
    h = (h * 0x01000193) & 0xffffffff;
  }
  final out = StringBuffer();
  for (var i = 0; i < 6; i++) {
    out.write(_alphabet[h % _alphabet.length]);
    h = (h ~/ _alphabet.length) ^ ((h << 7) & 0xffffffff);
    h = (h * 0x01000193 + i) & 0xffffffff;
  }
  return out.toString();
}

Future<Profile> signInAndEnsureProfile(SupabaseClient c) async {
  try {
    if (c.auth.currentUser == null) {
      await c.auth.signInAnonymously();
    }
    // Never `!` here: a sign-in that returns no session must surface as the
    // boot error, not as a null-check crash on a black screen.
    final uid = c.auth.currentUser?.id;
    if (uid == null) throw Exception('Could not sign in: no session.');

    final existing = await c
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (existing != null) return Profile.fromMap(existing);

    final row = await c
        .from('profiles')
        .insert({'id': uid, 'invite_code': inviteCodeFor(uid)})
        .select()
        .single();
    return Profile.fromMap(row);
  } on AuthException catch (e) {
    throw Exception('Could not sign in: ${e.message}');
  } on PostgrestException catch (e) {
    throw Exception('Could not create your profile: ${e.message}');
  }
}
