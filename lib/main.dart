import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final url = const String.fromEnvironment('SUPABASE_URL');
  final key = const String.fromEnvironment('SUPABASE_ANON_KEY');
  var onlineConfigured = false;
  if (url.isNotEmpty && key.isNotEmpty) {
    try {
      await Supabase.initialize(url: url, anonKey: key);
      onlineConfigured = true;
    } catch (_) {}
  }
  await LocalStore.instance.init();
  runApp(FranxxApp(onlineConfigured: onlineConfigured));
}

class FranxxApp extends StatefulWidget {
  const FranxxApp({super.key, required this.onlineConfigured});
  final bool onlineConfigured;
  @override
  State<FranxxApp> createState() => _FranxxAppState();
}

class _FranxxAppState extends State<FranxxApp> {
  bool dark = true;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FRANXX CHAT',
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: buildTheme(false),
      darkTheme: buildTheme(true),
      home: AuthGate(
        onlineConfigured: widget.onlineConfigured,
        onToggleTheme: () => setState(() => dark = !dark),
        dark: dark,
      ),
    );
  }
}

ThemeData buildTheme(bool dark) {
  final bg = dark ? const Color(0xFF090909) : const Color(0xFFF5F5F3);
  final panel = dark ? const Color(0xFF151515) : Colors.white;
  final fg = dark ? const Color(0xFFF5F5F5) : const Color(0xFF151515);
  return ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: fg,
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: panel,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardTheme(
      color: panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      hintStyle: TextStyle(color: fg.withOpacity(.45)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: fg.withOpacity(.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: fg.withOpacity(.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: fg.withOpacity(.55)),
      ),
    ),
    useMaterial3: true,
  );
}

class LocalStore {
  LocalStore._();
  static final instance = LocalStore._();
  Database? _db;

  Future<void> init() async {
    final path = p.join(await getDatabasesPath(), 'franxx_chat.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE messages(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          chat_id TEXT NOT NULL,
          body TEXT NOT NULL,
          mine INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    });
  }

  Future<List<Map<String, Object?>>> messages(String chatId) async {
    return (_db!).query('messages', where: 'chat_id = ?', whereArgs: [chatId], orderBy: 'id ASC');
  }

  Future<void> addMessage(String chatId, String body, bool mine) async {
    await (_db!).insert('messages', {
      'chat_id': chatId,
      'body': body,
      'mine': mine ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> clearChat(String chatId) async {
    await (_db!).delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
  }

  Future<void> clearAll() async => (_db!).delete('messages');
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.onlineConfigured, required this.onToggleTheme, required this.dark});
  final bool onlineConfigured;
  final VoidCallback onToggleTheme;
  final bool dark;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loggedIn = false;
  bool register = false;
  bool busy = false;
  String displayName = 'KyZX';
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final username = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreDemo();
    if (widget.onlineConfigured) {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (mounted) setState(() => loggedIn = data.session != null);
      });
      loggedIn = Supabase.instance.client.auth.currentSession != null;
    }
  }

  Future<void> _restoreDemo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!widget.onlineConfigured && mounted) {
      setState(() {
        loggedIn = prefs.getBool('demo_logged_in') ?? false;
        displayName = prefs.getString('demo_name') ?? 'KyZX';
      });
    }
  }

  Future<void> _submit() async {
    if (email.text.trim().isEmpty || password.text.length < 6) {
      _snack('Masukkan email dan password minimal 6 karakter.');
      return;
    }
    setState(() => busy = true);
    try {
      if (widget.onlineConfigured) {
        final auth = Supabase.instance.client.auth;
        if (register) {
          await auth.signUp(email: email.text.trim(), password: password.text);
          _snack('Pendaftaran dikirim. Periksa email jika verifikasi diaktifkan.');
        } else {
          await auth.signInWithPassword(email: email.text.trim(), password: password.text);
        }
        if (auth.currentSession != null && mounted) setState(() => loggedIn = true);
      } else {
        final prefs = await SharedPreferences.getInstance();
        displayName = name.text.trim().isEmpty ? email.text.trim().split('@').first : name.text.trim();
        await prefs.setBool('demo_logged_in', true);
        await prefs.setString('demo_name', displayName);
        if (mounted) setState(() => loggedIn = true);
        _snack('Mode demo lokal: akun ini belum terhubung ke server.');
      }
    } catch (e) {
      _snack('Gagal: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (loggedIn) {
      return HomeScreen(
        name: displayName,
        onlineConfigured: widget.onlineConfigured,
        onToggleTheme: widget.onToggleTheme,
        dark: widget.dark,
        onLogout: () async {
          if (widget.onlineConfigured) await Supabase.instance.client.auth.signOut();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('demo_logged_in', false);
          if (mounted) setState(() => loggedIn = false);
        },
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const BrandMark(),
                const SizedBox(height: 34),
                Text(register ? 'Create your space.' : 'Conversations,\nwith intention.',
                    style: const TextStyle(fontSize: 34, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -1.3)),
                const SizedBox(height: 12),
                Text(register ? 'Buat akun FRANXX CHAT.' : 'A quieter place for your conversations.',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(.62), fontSize: 15)),
                const SizedBox(height: 28),
                if (register) ...[
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama tampilan', prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 12),
                  TextField(controller: username, decoration: const InputDecoration(labelText: 'Username unik', prefixIcon: Icon(Icons.alternate_email))),
                  const SizedBox(height: 12),
                ],
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
                const SizedBox(height: 12),
                TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password (min. 6 karakter)', prefixIcon: Icon(Icons.lock_outline))),
                const SizedBox(height: 18),
                SizedBox(width: double.infinity, height: 54, child: FilledButton(
                  onPressed: busy ? null : _submit,
                  child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(register ? 'Create account  →' : 'Continue  →'),
                )),
                const SizedBox(height: 14),
                Center(child: TextButton(
                  onPressed: () => setState(() => register = !register),
                  child: Text(register ? 'Sudah punya akun? Login' : 'Belum punya akun? Register'),
                )),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.15)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.onlineConfigured
                      ? 'Supabase terkonfigurasi. Login dan register menggunakan layanan autentikasi.'
                      : 'Mode demo: UI dan chat lokal bisa dicoba, tetapi akun tidak online dan belum bisa mengirim pesan ke pengguna lain.',
                      style: const TextStyle(fontSize: 12.5, height: 1.4))),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface, borderRadius: BorderRadius.circular(14)),
      child: Icon(Icons.forum_rounded, color: Theme.of(context).scaffoldBackgroundColor, size: 23)),
    const SizedBox(width: 12),
    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('FRANXX CHAT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3, fontSize: 14)),
      SizedBox(height: 2),
      Text('MONOCHROME MESSENGER', style: TextStyle(fontSize: 9, letterSpacing: 1.4)),
    ]),
  ]);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.name, required this.onlineConfigured, required this.onToggleTheme, required this.dark, required this.onLogout});
  final String name;
  final bool onlineConfigured;
  final VoidCallback onToggleTheme;
  final bool dark;
  final Future<void> Function() onLogout;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  final search = TextEditingController();
  final demoChats = <Map<String, String>>[
    {'name': 'Alex Morgan', 'user': '@alexm', 'message': 'Oke, nanti kabari ya.', 'time': '12:42', 'avatar': 'A'},
    {'name': 'Nadia', 'user': '@nadiaa', 'message': 'Foto profilnya keren!', 'time': '11:08', 'avatar': 'N'},
    {'name': 'Ryo Yamada', 'user': '@ryoyamada', 'message': 'Sampai ketemu 👋', 'time': 'Kemarin', 'avatar': 'R'},
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _chatsPage(),
      _searchPage(),
      _profilePage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(),
        actions: [
          IconButton(tooltip: widget.dark ? 'Light mode' : 'Dark mode', onPressed: widget.onToggleTheme,
            icon: Icon(widget.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined)),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _chatsPage() {
    final filtered = demoChats.where((c) => ('${c['name']} ${c['user']} ${c['message']}').toLowerCase().contains(search.text.toLowerCase())).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 24), children: [
      const Text('YOUR SPACE', style: TextStyle(fontSize: 10, letterSpacing: 2.2, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Messages', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
      const SizedBox(height: 18),
      TextField(controller: search, onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search conversations')),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('RECENT', style: TextStyle(fontSize: 11, letterSpacing: 1.7, fontWeight: FontWeight.w800)),
        Text('${filtered.length} conversations', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
      ]),
      const SizedBox(height: 10),
      if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Text('Tidak ada percakapan ditemukan.')),
      ...filtered.map((c) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Material(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20),
          child: InkWell(borderRadius: BorderRadius.circular(20), onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChatScreen(chat: c, onlineConfigured: widget.onlineConfigured))),
            child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
              Avatar(letter: c['avatar']!, size: 50),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['name']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 5),
                Text(c['message']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
              ])),
              const SizedBox(width: 8),
              Text(c['time']!, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10)),
            ])),
          ),
        ),
      )),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.18))),
        child: Row(children: [
          const Icon(Icons.offline_bolt_outlined, size: 19),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.onlineConfigured
            ? 'Supabase siap untuk autentikasi. Pesan online belum diaktifkan pada starter ini.'
            : 'Demo lokal aktif. Percakapan contoh bisa dibuka offline.',
            style: const TextStyle(fontSize: 12, height: 1.4))),
        ]),
      ),
    ]);
  }

  Widget _searchPage() {
    final q = TextEditingController();
    return StatefulBuilder(builder: (context, localSet) {
      final matches = demoChats.where((c) => ('${c['name']} ${c['user']}').toLowerCase().contains(q.text.toLowerCase())).toList();
      return ListView(padding: const EdgeInsets.all(20), children: [
        const Text('FIND PEOPLE', style: TextStyle(fontSize: 10, letterSpacing: 2.2, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Discover', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
        const SizedBox(height: 10),
        const Text('Cari username untuk menemukan teman. Pada demo, hasil berikut hanya akun contoh.', style: TextStyle(height: 1.5)),
        const SizedBox(height: 18),
        TextField(controller: q, onChanged: (_) => localSet(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.alternate_email), hintText: 'Cari username...')),
        const SizedBox(height: 18),
        ...matches.map((c) => ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          leading: Avatar(letter: c['avatar']!, size: 46),
          title: Text(c['name']!, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(c['user']!),
          trailing: const Icon(Icons.arrow_outward_rounded),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chat: c, onlineConfigured: widget.onlineConfigured))),
        )),
      ]);
    });
  }

  Widget _profilePage() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('YOUR IDENTITY', style: TextStyle(fontSize: 10, letterSpacing: 2.2, fontWeight: FontWeight.w800)),
    const SizedBox(height: 24),
    Center(child: Column(children: [
      Avatar(letter: widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'F', size: 94),
      const SizedBox(height: 16),
      Text(widget.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text('@${widget.name.toLowerCase().replaceAll(' ', '')}', style: TextStyle(color: Theme.of(context).hintColor)),
      const SizedBox(height: 12),
      const Text('Building something different.', textAlign: TextAlign.center),
    ])),
    const SizedBox(height: 30),
    _settingsTile(Icons.palette_outlined, 'Appearance', widget.dark ? 'Dark mode' : 'Light mode', widget.onToggleTheme),
    _settingsTile(Icons.storage_outlined, 'Local storage', 'Hapus semua riwayat pesan lokal', () async {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Hapus semua chat lokal?'),
        content: const Text('Riwayat pesan yang tersimpan di HP akan dihapus. Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ));
      if (ok == true) {
        await LocalStore.instance.clearAll();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Riwayat lokal dihapus.')));
      }
    }),
    _settingsTile(Icons.info_outline, 'About FRANXX CHAT', 'Version 1.0.0 • Monochrome Premium', () {
      showAboutDialog(context: context, applicationName: 'FRANXX CHAT', applicationVersion: '1.0.0', children: const [Text('A simple monochrome messenger, built step by step.')]);
    }),
    const SizedBox(height: 18),
    OutlinedButton.icon(onPressed: widget.onLogout, icon: const Icon(Icons.logout), label: const Text('Log out')),
    const SizedBox(height: 12),
    Text('Riwayat chat tersimpan di perangkat. Menghapus aplikasi biasanya menghapus database lokal.', style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor, height: 1.5)),
  ]);

  Widget _settingsTile(IconData icon, String title, String subtitle, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(17),
      child: ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        leading: Icon(icon), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)), trailing: const Icon(Icons.chevron_right), onTap: onTap)),
  );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chat, required this.onlineConfigured});
  final Map<String, String> chat;
  final bool onlineConfigured;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  List<Map<String, Object?>> messages = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    messages = await LocalStore.instance.messages(widget.chat['user']!);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _send() async {
    final body = input.text.trim();
    if (body.isEmpty) return;
    await LocalStore.instance.addMessage(widget.chat['user']!, body, true);
    input.clear();
    await _load();
    if (mounted && !widget.onlineConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Disimpan lokal saja. Pengiriman online belum diaktifkan.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(children: [
          Avatar(letter: widget.chat['avatar']!, size: 38),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.chat['name']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Text(widget.chat['user']!, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
          ])),
        ]),
        actions: [PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'clear') {
              await LocalStore.instance.clearChat(widget.chat['user']!);
              await _load();
            }
          },
          itemBuilder: (_) => const [PopupMenuItem(value: 'clear', child: Text('Hapus riwayat chat lokal'))],
        )],
      ),
      body: Column(children: [
        Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : messages.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.forum_outlined, size: 42, color: Theme.of(context).hintColor),
              const SizedBox(height: 12),
              const Text('Mulai percakapan'),
              const SizedBox(height: 5),
              Text('Pesan akan tersimpan di perangkat ini.', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            ]))
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: messages.length, itemBuilder: (context, i) {
              final m = messages[i];
              final mine = m['mine'] == 1;
              return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                decoration: BoxDecoration(
                  color: mine ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(17), topRight: const Radius.circular(17),
                    bottomLeft: Radius.circular(mine ? 17 : 5), bottomRight: Radius.circular(mine ? 5 : 17)),
                ),
                child: Text(m['body'] as String, style: TextStyle(color: mine ? Theme.of(context).scaffoldBackgroundColor : Theme.of(context).colorScheme.onSurface, height: 1.35)),
              ));
            })),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(children: [
            Expanded(child: TextField(controller: input, minLines: 1, maxLines: 5, textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(hintText: 'Tulis pesan...', contentPadding: EdgeInsets.symmetric(horizontal: 17, vertical: 13)))),
            const SizedBox(width: 8),
            SizedBox(height: 50, width: 50, child: FilledButton(
              onPressed: _send, style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Icon(Icons.arrow_upward_rounded))),
          ]),
        )),
      ]),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.letter, this.size = 46});
  final String letter;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface,
      borderRadius: BorderRadius.circular(size * .34),
    ),
    child: Text(letter, style: TextStyle(
      color: Theme.of(context).scaffoldBackgroundColor,
      fontSize: size * .38, fontWeight: FontWeight.w800)),
  );
}
