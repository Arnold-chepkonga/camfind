import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyDfLzlN57MJ0dJ1igniLraSmehKtyffT3I',
  appId: '1:863023915817:android:b8ab5b766693e9a2e00d38',
  messagingSenderId: '863023915817',
  projectId: 'camfind-b9257',
  storageBucket: 'camfind-b9257.firebasestorage.app',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const CampusFindApp());
}

class CampusFindApp extends StatelessWidget {
  const CampusFindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusFind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.travel_explore, size: 72, color: Colors.indigo),
                const SizedBox(height: 8),
                const Text('CampusFind',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const Text('Campus lost & found'),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Password (min 6 characters)',
                      border: OutlineInputBorder()),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isLogin ? 'Log in' : 'Create account'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _isLogin = !_isLogin;
                    _error = null;
                  }),
                  child: Text(_isLogin
                      ? 'No account? Sign up'
                      : 'Already have an account? Log in'),
                ),
              ],
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
  String _filter = 'all';
  String _query = '';

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance
          .collection('items')
          .orderBy('createdAt', descending: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusFind'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ReportPage())),
        icon: const Icon(Icons.add),
        label: const Text('Report item'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search items...',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final f in const ['all', 'lost', 'found'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f[0].toUpperCase() + f.substring(1)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                      child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: ${snap.error}'),
                  ));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs.where((d) {
                  final data = d.data();
                  if (_filter != 'all' && data['type'] != _filter) return false;
                  if (_query.isEmpty) return true;
                  final text =
                      '${data['title']} ${data['description']} ${data['location']}'
                          .toLowerCase();
                  return text.contains(_query);
                }).toList();
                if (docs.isEmpty) {
                  return const Center(child: Text('No items found yet.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final isLost = d['type'] == 'lost';
                    final resolved = d['resolved'] == true;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              isLost ? Colors.red.shade100 : Colors.green.shade100,
                          child: Icon(
                              isLost ? Icons.search : Icons.check_circle_outline,
                              color: isLost ? Colors.red : Colors.green),
                        ),
                        title: Text('${d['title'] ?? ''}'),
                        subtitle: Text(
                            '${isLost ? 'Lost' : 'Found'} at ${d['location'] ?? ''}'),
                        trailing: resolved
                            ? const Chip(label: Text('Returned'))
                            : const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => DetailPage(doc: doc)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
  String _type = 'lost';
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('items').add({
        'type': _type,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'location': _location.text.trim(),
        'contact': _contact.text.trim(),
        'userId': user.uid,
        'userEmail': user.email,
        'resolved': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _contact.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'lost',
                      label: Text('I lost something'),
                      icon: Icon(Icons.search)),
                  ButtonSegment(
                      value: 'found',
                      label: Text('I found something'),
                      icon: Icon(Icons.check_circle_outline)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                validator: _required,
                decoration: const InputDecoration(
                    labelText: 'Item name (e.g. Black wallet)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                validator: _required,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Description (colour, brand, marks)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                validator: _required,
                decoration: const InputDecoration(
                    labelText: 'Where was it lost / found?',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contact,
                validator: _required,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Your phone number or contact',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit report'),
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    final d = doc.data() ?? {};
    final isOwner = FirebaseAuth.instance.currentUser?.uid == d['userId'];
    final isLost = d['type'] == 'lost';
    final created = (d['createdAt'] as Timestamp?)?.toDate();

    return Scaffold(
      appBar: AppBar(title: Text('${d['title'] ?? 'Item'}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Chip(label: Text(isLost ? 'LOST' : 'FOUND')),
          const SizedBox(height: 12),
          Text('${d['title'] ?? ''}',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('${d['description'] ?? ''}'),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.place),
            title: const Text('Location'),
            subtitle: Text('${d['location'] ?? ''}'),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Contact'),
            subtitle: SelectableText('${d['contact'] ?? ''}'),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Reported by'),
            subtitle: Text('${d['userEmail'] ?? ''}'),
          ),
          if (created != null)
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Date'),
              subtitle: Text('${created.day}/${created.month}/${created.year}'),
            ),
          const SizedBox(height: 8),
          Card(
            color: Colors.amber.shade50,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Safe return tip: meet in a public place on campus, such as the '
                'security office or the main gate, and never share personal '
                'details beyond what is needed.',
              ),
            ),
          ),
          if (isOwner && d['resolved'] != true) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await doc.reference.update({'resolved': true});
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.done_all),
              label: const Text('Mark as returned'),
            ),
          ],
          if (isOwner) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await doc.reference.delete();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete report'),
            ),
          ],
        ],
      ),
    );
  }
}
