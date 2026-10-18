import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileRepository {
  ProfileRepository(this.uid);

  final String uid;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _petsRef =>
      _userRef.collection('pets');

  void _checkUser() {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
  }

  Future<void> ensureProfile(User user) async {
    _checkUser();

    if (user.uid != uid) {
      throw StateError('Profile owner does not match the session.');
    }

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(_userRef);

      // Do not overwrite profile edits when the user signs in again.
      if (snapshot.exists) return;

      final suppliedName = user.displayName?.trim() ?? '';
      final name = suppliedName.length > 80
          ? suppliedName.substring(0, 80)
          : suppliedName;

      transaction.set(_userRef, {
        'displayName': name,
        'experience': 'beginner',
        'schemaVersion': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<Map<String, dynamic>> loadProfile() async {
    _checkUser();

    final snapshot = await _userRef.get();

    if (!snapshot.exists) {
      throw StateError('The user profile does not exist.');
    }

    return snapshot.data()!;
  }

  Future<void> saveProfile({
    required String displayName,
    required String experience,
  }) async {
    _checkUser();

    await _userRef.update({
      'displayName': displayName.trim(),
      'experience': experience,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPets() {
    _checkUser();
    return _petsRef.orderBy('createdAt').snapshots();
  }

  Future<void> savePet({
    String? petId,
    required String name,
    required String breed,
    required String birthDate,
    required String focus,
    required String goals,
    required String notes,
  }) async {
    _checkUser();

    final data = <String, dynamic>{
      'name': name.trim(),
      'breed': breed.trim(),
      // Empty string means unknown; otherwise YYYY-MM-DD.
      'birthDate': birthDate.trim(),
      'focus': focus,
      'goals': goals.trim(),
      'notes': notes.trim(),
      'schemaVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (petId == null) {
      await _petsRef.add({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      // update() deliberately fails if this pet was deleted elsewhere.
      await _petsRef.doc(petId).update(data);
    }
  }

  Future<void> deletePet(String petId) async {
    _checkUser();
    await _petsRef.doc(petId).delete();
  }
}
