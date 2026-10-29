import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyDfLzlN57MJ0dJ1igniLraSmehKtyffT3I',
  appId: '1:863023915817:android:b8ab5b766693e9a2e00d38',
  messagingSenderId: '863023915817',
  projectId: 'camfind-b9257',
  storageBucket: 'camfind-b9257.firebasestorage.app',
);

const kPrimary = Color(0xFF4F46E5);
const kLost = Color(0xFFEF4444);
const kFound = Color(0xFF10B981);
const kBg = Color(0xFFF5F6FA);

const kGradient = LinearGradient(
  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const CampusFindApp());
}

// ------------------------------------------------------------- HELPERS

IconData iconFor(String text) {
  final t = text.toLowerCase();
  if (t.contains('phone') ||
      t.contains('samsung') ||
      t.contains('tecno') ||
      t.contains('infinix') ||
      t.contains('iphone')) {
    return Icons.smartphone;
  }
  if (t.contains('wallet') || t.contains('purse')) {
    return Icons.account_balance_wallet;
  }
  if (t.contains('key')) return Icons.vpn_key;
  if (t.contains('bottle') || t.contains('flask')) return Icons.water_drop;
  if (t.contains('card') || t.contains('student id')) return Icons.credit_card;
  if (t.contains('bag') || t.contains('backpack')) return Icons.backpack;
  if (t.contains('laptop') || t.contains('computer')) return Icons.laptop;
  if (t.contains('book')) return Icons.menu_book;
  if (t.contains('charger') || t.contains('cable')) {
    return Icons.battery_charging_full;
  }
  if (t.contains('headphone') ||
      t.contains('earphone') ||
      t.contains('airpod')) {
    return Icons.headphones;
  }
  if (t.contains('watch')) return Icons.watch;
  return Icons.inventory_2;
}

String timeAgo(Timestamp? ts) {
  if (ts == null) return 'Just now';
  final d = ts.toDate();
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${d.day}/${d.month}/${d.year}';
}

InputDecoration fieldDecoration(String label, IconData icon,
    {Widget? suffix}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: kPrimary),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kPrimary, width: 2),
    ),
  );
}

Widget pill(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
  );
}

ButtonStyle bigButton(Color color) {
  return FilledButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );
}

String levelFor(int karma) =>
    karma >= 50 ? 'Legend' : (karma >= 20 ? 'Campus Hero' : 'Rookie');

/// Picks a photo and returns it as a small base64 string (kept under
/// Firestore's 1 MB document limit by resizing and compressing).
Future<String?> pickPhoto(BuildContext context) async {
  final src = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (src == null) return null;
  final x =
      await ImagePicker().pickImage(source: src, maxWidth: 800, imageQuality: 50);
  if (x == null) return null;
  return base64Encode(await x.readAsBytes());
}

Future<void> shareToWhatsApp(Map<String, dynamic> d) async {
  final kind = d['type'] == 'lost' ? 'LOST' : 'FOUND';
  final text = '$kind on campus: ${d['title']} (${d['location']}). '
      'Is it yours? Check CampusFind.';
  await launchUrl(
    Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
    mode: LaunchMode.externalApplication,
  );
}

Widget infoBox(IconData icon, Color color, String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
      ],
    ),
  );
}

// ----------------------------------------------------------------- APP

class CampusFindApp extends StatelessWidget {
  const CampusFindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusFind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return snap.hasData ? const HomePage() : const AuthPage();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- LOGIN

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final pass = _password.text;
      if (_isLogin) {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: pass);
      } else {
        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: pass);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: kGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.travel_explore,
                        size: 54, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'CampusFind',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Lost something? Found something?',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLogin ? 'Welcome back' : 'Create your account',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isLogin
                              ? 'Log in to see what has been reported.'
                              : 'Sign up to report lost and found items.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration:
                              fieldDecoration('Email', Icons.email_outlined),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: fieldDecoration(
                            'Password',
                            Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        if (_error != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 14),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kLost.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(_error!,
                                style: const TextStyle(color: kLost)),
                          ),
                        const SizedBox(height: 20),
                        FilledButton(
                          style: bigButton(kPrimary),
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white))
                              : Text(_isLogin ? 'Log in' : 'Create account'),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() {
                              _isLogin = !_isLogin;
                              _error = null;
                            }),
                            child: Text(_isLogin
                                ? 'No account? Sign up'
                                : 'Already have an account? Log in'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- HOME

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();
  String _filter = 'all';
  String _query = '';

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance
          .collection('items')
          .orderBy('createdAt', descending: true)
          .snapshots();

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _karma =
      FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .snapshots();

  Widget _karmaBadge() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _karma,
      builder: (context, snap) {
        final n = ((snap.data?.data()?['karma'] ?? 0) as num).toInt();
        return Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '\u2B50 $n \u00B7 ${levelFor(n)}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        );
      },
    );
  }

  Widget _thumb(Map<String, dynamic> d, Color color) {
    final photo = d['photo'] as String?;
    if (photo != null && photo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(base64Decode(photo),
            width: 54, height: 54, fit: BoxFit.cover, gaplessPlayback: true),
      );
    }
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(iconFor('${d['title']}'), color: color, size: 28),
    );
  }

  String get _name {
    final e = FirebaseAuth.instance.currentUser?.email ?? '';
    final n = e.split('@').first;
    if (n.isEmpty) return 'there';
    return n[0].toUpperCase() + n.substring(1);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _stat(String label, int value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(label,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, int lost, int found, int returned) {
    return Container(
      decoration: const BoxDecoration(
        gradient: kGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello, $_name',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 2),
                    const Text('CampusFind',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _karmaBadge(),
              IconButton(
                tooltip: 'Log out',
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat('Lost', lost, Icons.search),
              const SizedBox(width: 8),
              _stat('Found', found, Icons.check_circle_outline),
              const SizedBox(width: 8),
              _stat('Returned', returned, Icons.handshake_outlined),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search wallet, phone, library...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          for (final f in const ['all', 'lost', 'found'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f[0].toUpperCase() + f.substring(1)),
                selected: _filter == f,
                showCheckmark: false,
                selectedColor: kPrimary,
                backgroundColor: Colors.white,
                shape: const StadiumBorder(),
                side: BorderSide(
                    color: _filter == f ? kPrimary : Colors.grey.shade300),
                labelStyle: TextStyle(
                  color: _filter == f ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _filter = f),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final isLost = d['type'] == 'lost';
    final resolved = d['resolved'] == true;
    final color = isLost ? kLost : kFound;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailPage(doc: doc)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _thumb(d, color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d['title'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${d['location'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgo(d['createdAt'] as Timestamp?),
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                resolved
                    ? pill('RETURNED', Colors.grey.shade600)
                    : pill(isLost ? 'LOST' : 'FOUND', color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ReportPage())),
        icon: const Icon(Icons.add),
        label: const Text('Report item'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          final List<QueryDocumentSnapshot<Map<String, dynamic>>> all =
              snap.data?.docs ?? [];

          int count(String type) => all.where((d) {
                final m = d.data();
                return m['type'] == type && m['resolved'] != true;
              }).length;
          final returned = all.where((d) => d.data()['resolved'] == true).length;

          final docs = all.where((d) {
            final data = d.data();
            if (_filter != 'all' && data['type'] != _filter) return false;
            if (_query.isEmpty) return true;
            final text =
                '${data['title']} ${data['description']} ${data['location']}'
                    .toLowerCase();
            return text.contains(_query);
          }).toList();

          Widget content;
          if (snap.hasError) {
            content = Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: ${snap.error}'),
              ),
            );
          } else if (!snap.hasData) {
            content = const Center(child: CircularProgressIndicator());
          } else if (docs.isEmpty) {
            content = Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  const Text('Nothing here yet',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Tap "Report item" to add the first one.',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          } else {
            content = ListView.builder(
              padding: const EdgeInsets.only(top: 6, bottom: 100),
              itemCount: docs.length,
              itemBuilder: (context, i) => _card(docs[i]),
            );
          }

          return Column(
            children: [
              _header(context, count('lost'), count('found'), returned),
              _chips(),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------------- REPORT

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _contact = TextEditingController();
  final _question = TextEditingController();
  final _answer = TextEditingController();
  String? _photo;
  String _type = 'lost';
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final ref = await FirebaseFirestore.instance.collection('items').add({
        'type': _type,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'location': _location.text.trim(),
        'contact': _contact.text.trim(),
        'userId': user.uid,
        'userEmail': user.email,
        'resolved': false,
        if (_photo != null) 'photo': _photo,
        if (_type == 'found') 'question': _question.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (_type == 'found') {
        // The real answer lives in a private sub-document that only the
        // finder can read (see firestore.rules).
        await ref
            .collection('private')
            .doc('detail')
            .set({'detail': _answer.text.trim(), 'finderId': user.uid});
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Could not save: $e'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _contact.dispose();
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  Widget _typeCard(String value, String label, IconData icon, Color color) {
    final selected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: selected ? color : Colors.grey),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? color : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an item'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kGradient),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What happened?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _typeCard('lost', 'I lost it', Icons.search, kLost),
                  const SizedBox(width: 12),
                  _typeCard(
                      'found', 'I found it', Icons.check_circle_outline, kFound),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Item details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                validator: _required,
                decoration: fieldDecoration(
                    'Item name (e.g. Black wallet)', Icons.label_outline),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                validator: _required,
                maxLines: 3,
                decoration: fieldDecoration(
                    'Description (colour, brand, marks)', Icons.notes),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _location,
                validator: _required,
                decoration: fieldDecoration(
                    'Where was it lost / found?', Icons.place_outlined),
              ),
              const SizedBox(height: 14),
              PhotoField(
                photo: _photo,
                label: 'Add a photo (optional)',
                onPick: () async {
                  final p = await pickPhoto(context);
                  if (p != null) setState(() => _photo = p);
                },
                onClear: () => setState(() => _photo = null),
              ),
              const SizedBox(height: 14),
              if (_type == 'found') ...[
                infoBox(
                  Icons.verified_user_outlined,
                  kPrimary,
                  'Owner check: ask a question only the real owner can answer '
                  '(e.g. "What is inside the front pocket?"). Keep the true '
                  'answer private. Do not put it in the description.',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _question,
                  validator: _required,
                  decoration: fieldDecoration(
                      'Question for the claimant', Icons.help_outline),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _answer,
                  validator: _required,
                  decoration: fieldDecoration(
                      'True answer (only you can see)', Icons.lock_outline),
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _contact,
                validator: _required,
                keyboardType: TextInputType.phone,
                decoration: fieldDecoration(
                    'Your phone number or contact', Icons.phone_outlined),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                style: bigButton(kPrimary),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.send),
                label: const Text('Submit report'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- DETAIL

class DetailPage extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  const DetailPage({super.key, required this.doc});

  Widget _info(IconData icon, String label, String value, {Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: kPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await doc.reference.delete();
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data() ?? {};
    final isOwner = FirebaseAuth.instance.currentUser?.uid == d['userId'];
    final isLost = d['type'] == 'lost';
    final resolved = d['resolved'] == true;
    final color = isLost ? kLost : kFound;
    final created = d['createdAt'] as Timestamp?;
    final contact = '${d['contact'] ?? ''}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item details'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconFor('${d['title']}'),
                      size: 46, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  '${d['title'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    resolved ? 'RETURNED' : (isLost ? 'LOST' : 'FOUND'),
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Posted ${timeAgo(created)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ('${d['photo'] ?? ''}'.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(base64Decode('${d['photo']}'),
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        gaplessPlayback: true),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Description',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('${d['description'] ?? ''}',
                    style: const TextStyle(fontSize: 15, height: 1.4)),
                const SizedBox(height: 18),
                _info(Icons.place_outlined, 'Location', '${d['location'] ?? ''}'),
                _info(
                  Icons.phone_outlined,
                  'Contact',
                  contact,
                  trailing: IconButton(
                    tooltip: 'Copy contact',
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: contact));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('Contact copied'),
                        ),
                      );
                    },
                  ),
                ),
                _info(Icons.person_outline, 'Reported by',
                    '${d['userEmail'] ?? ''}'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_user_outlined,
                          color: Colors.amber.shade800),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Safe return tip: meet in a public place on campus, '
                          'such as the security office or the main gate, and '
                          'never share more personal details than needed.',
                          style: TextStyle(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF128C7E),
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: Color(0xFF128C7E)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => shareToWhatsApp(d),
                  icon: const Icon(Icons.share),
                  label: const Text('Share to WhatsApp'),
                ),
                if (!isLost && !resolved) ...[
                  const SizedBox(height: 18),
                  ClaimSection(item: doc.reference, data: d),
                ],
                if (isOwner && !resolved && isLost) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: bigButton(kFound),
                    onPressed: () async {
                      await doc.reference.update({'resolved': true});
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.done_all),
                    label: const Text('Mark as returned'),
                  ),
                ],
                if (isOwner) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kLost,
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: kLost),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete report'),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- CLAIMS

class PhotoField extends StatelessWidget {
  final String? photo;
  final String label;
  final VoidCallback onPick;
  final VoidCallback onClear;
  const PhotoField({
    super.key,
    required this.photo,
    required this.label,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: Colors.grey.shade400),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPick,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(label),
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(base64Decode(photo!),
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              gaplessPlayback: true),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton(
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClear,
          ),
        ),
      ],
    );
  }
}

class ClaimSection extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> item;
  final Map<String, dynamic> data;
  const ClaimSection({super.key, required this.item, required this.data});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (uid == data['userId']) return FinderClaims(item: item);
    return MyClaim(item: item, uid: uid, question: '${data['question'] ?? ''}');
  }
}

/// What a non-finder sees: claim button, pending/rejected state, or the
/// handover code once approved.
class MyClaim extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> item;
  final String uid;
  final String question;
  const MyClaim(
      {super.key,
      required this.item,
      required this.uid,
      required this.question});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: item.collection('claims').doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final c = snap.data!.data();
        if (c == null) {
          return FilledButton.icon(
            style: bigButton(kPrimary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ClaimPage(item: item, question: question)),
            ),
            icon: const Icon(Icons.front_hand_outlined),
            label: const Text('This is mine'),
          );
        }
        final status = c['status'];
        if (status == 'approved') {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: kFound.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kFound),
            ),
            child: Column(
              children: [
                const Text('Claim approved!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text(
                    'Meet the finder in a public place and show this code:'),
                const SizedBox(height: 10),
                Text('${c['handoverCode']}',
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: kFound)),
              ],
            ),
          );
        }
        if (status == 'rejected') {
          return infoBox(Icons.block, kLost,
              'Your claim was not accepted. The details did not match.');
        }
        if (status == 'returned') {
          return infoBox(Icons.done_all, kFound, 'This item was returned to you.');
        }
        return infoBox(Icons.hourglass_top, Colors.amber.shade800,
            'Claim sent. Waiting for the finder to review it.');
      },
    );
  }
}

class ClaimPage extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> item;
  final String question;
  const ClaimPage({super.key, required this.item, required this.question});

  @override
  State<ClaimPage> createState() => _ClaimPageState();
}

class _ClaimPageState extends State<ClaimPage> {
  final _answer = TextEditingController();
  String? _photo;
  bool _saving = false;

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(m)),
    );
  }

  Future<void> _submit() async {
    if (_answer.text.trim().isEmpty) {
      _snack('Please answer the finder\'s question');
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await widget.item.collection('claims').doc(user.uid).set({
        'claimantId': user.uid,
        'claimantEmail': user.email,
        'answer': _answer.text.trim(),
        if (_photo != null) 'proofPhoto': _photo,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Could not send claim: $e');
      }
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim this item'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kGradient),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            infoBox(
              Icons.help_outline,
              kPrimary,
              widget.question.isEmpty
                  ? 'Describe something only the real owner would know '
                      '(marks, contents, stickers).'
                  : widget.question,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _answer,
              maxLines: 4,
              decoration: fieldDecoration('Your answer', Icons.edit_outlined),
            ),
            const SizedBox(height: 14),
            PhotoField(
              photo: _photo,
              label: 'Add proof photo (optional)',
              onPick: () async {
                final p = await pickPhoto(context);
                if (p != null) setState(() => _photo = p);
              },
              onClear: () => setState(() => _photo = null),
            ),
            const SizedBox(height: 6),
            Text(
              'A photo of you with the item, or a receipt, makes your claim stronger.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              style: bigButton(kPrimary),
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.send),
              label: const Text('Send claim'),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the finder sees: their private answer next to each claim.
class FinderClaims extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> item;
  const FinderClaims({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Claims',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: item.collection('private').doc('detail').get(),
          builder: (context, s) {
            final a = s.data?.data()?['detail'];
            if (a == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: infoBox(Icons.lock_outline, kPrimary,
                  'True answer (only you can see): $a'),
            );
          },
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: item.collection('claims').snapshots(),
          builder: (context, s) {
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = s.data!.docs;
            if (docs.isEmpty) {
              return Text('No claims yet.',
                  style: TextStyle(color: Colors.grey.shade600));
            }
            final locked = docs.any((d) => d.data()['status'] == 'approved');
            return Column(
              children: [
                for (final d in docs)
                  ClaimCard(
                      key: ValueKey(d.id), item: item, claim: d, locked: locked),
              ],
            );
          },
        ),
      ],
    );
  }
}

class ClaimCard extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> item;
  final QueryDocumentSnapshot<Map<String, dynamic>> claim;
  final bool locked;
  const ClaimCard(
      {super.key,
      required this.item,
      required this.claim,
      required this.locked});

  @override
  State<ClaimCard> createState() => _ClaimCardState();
}

class _ClaimCardState extends State<ClaimCard> {
  final _code = TextEditingController();
  bool _busy = false;

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(m)),
    );
  }

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    try {
      await widget.claim.reference.update({
        'status': approve ? 'approved' : 'rejected',
        if (approve)
          'handoverCode': (100000 + Random().nextInt(900000)).toString(),
      });
    } catch (e) {
      _snack('Could not update: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final c = widget.claim.data();
    if (_code.text.trim() != '${c['handoverCode']}') {
      _snack('That code does not match');
      return;
    }
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final batch = db.batch();
      batch.update(
          widget.item, {'resolved': true, 'returnedTo': c['claimantId']});
      batch.update(widget.claim.reference, {'status': 'returned'});
      batch.set(
        db.collection('users').doc(uid),
        {'karma': FieldValue.increment(10), 'returns': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
      await batch.commit();
      if (mounted) {
        _snack('Returned! You earned +10 karma');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Could not confirm: $e');
      }
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.claim.data();
    final status = '${c['status']}';
    final proof = c['proofPhoto'] as String?;
    final statusColor = status == 'approved' || status == 'returned'
        ? kFound
        : (status == 'rejected' ? kLost : Colors.amber.shade800);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${c['claimantEmail'] ?? ''}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              pill(status.toUpperCase(), statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text('Their answer:',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Text('${c['answer'] ?? ''}',
              style: const TextStyle(fontSize: 15, height: 1.4)),
          if (proof != null && proof.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(base64Decode(proof),
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  gaplessPlayback: true),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _decide(false),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        (_busy || widget.locked) ? null : () => _decide(true),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'approved') ...[
            const SizedBox(height: 12),
            const Text('When you meet, enter the code they show you:'),
            const SizedBox(height: 8),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: fieldDecoration('6-digit code', Icons.pin_outlined),
            ),
            FilledButton.icon(
              style: bigButton(kFound),
              onPressed: _busy ? null : _confirm,
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Confirm handover'),
            ),
          ],
        ],
      ),
    );
  }
}
