import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khởi tạo Firebase cho cả web và mobile
  bool firebaseReady = false;
  try {
    // Khởi tạo Firebase với options
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyD3aUAHCLA71s69sjw3FyZdSyJQ5Q1lQYg",
        authDomain: "ptud-42561.firebaseapp.com",
        projectId: "ptud-42561",
        storageBucket: "ptud-42561.firebasestorage.app",
        messagingSenderId: "346353106055",
        appId: "1:346353106055:web:4079ae21b3f4badbbe0c22",
      ),
    );
    firebaseReady = true;
    print('✅ Firebase kết nối thành công!');
  } catch (e) {
    print('❌ Lỗi Firebase: $e');
    firebaseReady = false;
  }
  
  runApp(SmartNoteApp(firebaseReady: firebaseReady));
}

class SmartNoteApp extends StatelessWidget {
  final bool firebaseReady;
  const SmartNoteApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Note',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      home: firebaseReady
          ? StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return snapshot.data != null ? const HomeScreen() : const LoginScreen();
              },
            )
          : const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Đang khởi tạo Firebase...'),
                  ],
                ),
              ),
            ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- MODEL GHI CHÚ ---
class Note {
  String id;
  String title;
  String content;
  DateTime modifiedTime;
  int colorIndex;
  String? userId;
  List<String> attachments;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.modifiedTime,
    this.colorIndex = 0,
    this.userId,
    this.attachments = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'modifiedTime': modifiedTime.toIso8601String(),
        'colorIndex': colorIndex,
        'userId': userId,
        'attachments': attachments,
      };

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'content': content,
        'modifiedTime': Timestamp.fromDate(modifiedTime),
        'colorIndex': colorIndex,
        'userId': userId,
        'attachments': attachments,
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    final dynamic raw = json['attachments'];
    List<String> atts;
    if (raw == null) {
      atts = <String>[];
    } else if (raw is List) {
      atts = raw.map((e) => e.toString()).toList();
    } else if (raw is String) {
      // Một số dữ liệu cũ có thể lưu attachments dưới dạng chuỗi
      // (vd: "[]" hoặc một path đơn)
      final s = raw.trim();
      if (s.isEmpty || s == '[]') {
        atts = <String>[];
      } else {
        atts = <String>[s];
      }
    } else {
      atts = <String>[];
    }

    return Note(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      content: (json['content'] ?? '') as String,
      modifiedTime: DateTime.tryParse((json['modifiedTime'] ?? '').toString()) ?? DateTime.now(),
      colorIndex: (json['colorIndex'] ?? 0) as int,
      userId: json['userId']?.toString(),
      attachments: atts,
    );
  }

  factory Note.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['modifiedTime'];
    DateTime mt;
    if (ts is Timestamp) {
      mt = ts.toDate();
    } else if (ts is String) {
      mt = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      mt = DateTime.now();
    }

    return Note(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      content: (data['content'] ?? '') as String,
      modifiedTime: mt,
      colorIndex: (data['colorIndex'] ?? 0) as int,
      userId: data['userId'] as String?,
      attachments: List<String>.from(data['attachments'] ?? const []),
    );
  }
}

final List<Color> noteColors = [
  Colors.white,
  const Color(0xFFFFF9C4),
  const Color(0xFFFFCCBC),
  const Color(0xFFC8E6C9),
  const Color(0xFFB3E5FC),
  const Color(0xFFF8BBD0),
  const Color(0xFFE1BEE7),
];

// --- MÀN HÌNH ĐĂNG NHẬP ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  String _error = '';
  bool _loading = false;
  String? _lastUsername;

  @override
  void initState() {
    super.initState();
    _loadLastLogin();
  }

  Future<void> _loadLastLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastUser = prefs.getString('lastUsername');
    if (lastUser != null) {
      setState(() {
        _lastUsername = lastUser;
        _userController.text = lastUser;
      });
      print('👤 Đã tải username lần cuối: $lastUser');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      // Chỉ cho phép Google Sign-In trên web
      if (!kIsWeb) {
        setState(() {
          _error = 'Google Sign-In chỉ khả dụng trên web';
          _loading = false;
        });
        return;
      }

      // Kiểm tra Firebase đã được khởi tạo chưa
      try {
        FirebaseAuth.instance.app;
        print('✅ Firebase đã sẵn sàng');
      } catch (e) {
        print('❌ Firebase chưa được khởi tạo: $e');
        setState(() {
          _error = 'Firebase chưa được khởi tạo. Vui lòng refresh trang!';
          _loading = false;
        });
        return;
      }

      print('🔍 Bắt đầu Google Sign-In với Firebase Auth...');
      
      // Dùng Firebase Auth trực tiếp với popup
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      final User? user = userCredential.user;

      if (user != null) {
        // Lưu email lần cuối để tự điền
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastUsername', user.email ?? user.displayName ?? 'Google User');
        
        print('✅ Đăng nhập Google thành công: ${user.email}');
        
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      }
    } catch (e) {
      print('❌ Lỗi Google Sign-In: $e');
      String errorMessage = 'Lỗi đăng nhập Google';
      
      // Xử lý các lỗi phổ biến
      if (e.toString().contains('invalid_client') || e.toString().contains('401')) {
        errorMessage = 'Google OAuth Client ID không hợp lệ. Kiểm tra Firebase Console!';
      } else if (e.toString().contains('redirect_uri_mismatch') || e.toString().contains('400')) {
        errorMessage = 'Redirect URI không khớp. Chạy với port 8080!';
      } else if (e.toString().contains('access_denied')) {
        errorMessage = 'Bạn đã từ chối quyền truy cập Google.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Lỗi kết nối mạng. Vui lòng thử lại!';
      } else if (e.toString().contains('popup-closed-by-user')) {
        errorMessage = 'Bạn đã đóng popup đăng nhập.';
      } else if (e.toString().contains('no-app')) {
        errorMessage = 'Firebase chưa được khởi tạo. Vui lòng refresh trang!';
      }
      
      setState(() {
        _error = errorMessage;
        _loading = false;
      });
    }
  }

  Future<void> _login() async {
    final email = _userController.text.trim();
    final pass = _passController.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Nhập đủ thông tin');
      return;
    }
    
    setState(() => _loading = true);
    
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastUsername', email);
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      setState(() => _error = 'Lỗi: $e');
    }
    
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF673AB7), Color(0xFF512DA8)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.note_alt, size: 60, color: Color(0xFF673AB7)),
                      const SizedBox(height: 16),
                      const Text('Smart Note', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      
                      // Quick login với username đã lưu
                      if (_lastUsername != null && _lastUsername!.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Đăng nhập nhanh với:',
                                style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _lastUsername!,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.login, color: Color(0xFF673AB7)),
                                    onPressed: () {
                                      _userController.text = _lastUsername!;
                                      FocusScope.of(context).nextFocus();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      TextField(
                        controller: _userController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(_error, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF673AB7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _loading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('ĐĂNG NHẬP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      
                      // Google Sign-In button (chỉ trên web)
                      if (kIsWeb) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _signInWithGoogle,
                            icon: const Icon(Icons.account_circle, size: 24),
                            label: const Text('Đăng nhập với Google'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                        },
                        child: const Text('Chưa có tài khoản? Đăng ký ngay'),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tài khoản demo: admin/123 hoặc test/123',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- MÀN HÌNH ĐĂNG KÝ ---
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _u = TextEditingController();
  final TextEditingController _p = TextEditingController();
  final TextEditingController _cp = TextEditingController();
  String _e = '';
  bool _loading = false;

  Future<void> _reg() async {
    if (_u.text.isEmpty || _p.text.isEmpty) {
      setState(() => _e = 'Nhập đủ thông tin');
      return;
    }
    if (_p.text != _cp.text) {
      setState(() => _e = 'Mật khẩu không khớp');
      return;
    }

    setState(() => _loading = true);
    
    try {
      final email = _u.text.trim();
      final pass = _p.text;
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);

      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastUsername', email);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng ký thành công!')),
        );
        Future.delayed(const Duration(seconds: 1), () {
          FirebaseAuth.instance.signOut();
          if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
        });
      }
    } catch (e) {
      setState(() => _e = 'Lỗi: $e');
    }
    
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký tài khoản'), backgroundColor: const Color(0xFF673AB7), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              TextField(
                controller: _u,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _p,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cp,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Nhập lại mật khẩu',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_e.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_e, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _reg,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF673AB7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ĐĂNG KÝ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MÀN HÌNH CHÍNH ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> _all = [], _filtered = [];
  final TextEditingController _s = TextEditingController();
  static const String _prefsNotesKey = 'notes';
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notesSub;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _startNotesSync();
    _s.addListener(() {
      setState(() {
        _filtered = _all.where((n) => n.title.toLowerCase().contains(_s.text.toLowerCase())).toList();
      });
    });
  }

  void _startNotesSync() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notesSub?.cancel();
    _notesSub = _db
        .collection('users')
        .doc(user.uid)
        .collection('notes')
        .orderBy('modifiedTime', descending: true)
        .snapshots()
        .listen(
      (snapshot) async {
        final notes = snapshot.docs.map((d) => Note.fromFirestore(d)).toList();

        if (!mounted) return;
        setState(() {
          _all = notes;
          _filtered = _all.where((n) => n.title.toLowerCase().contains(_s.text.toLowerCase())).toList();
        });

        // Sync về local cache để offline fallback
        try {
          await _saveNotes();
        } catch (_) {}
      },
      onError: (e) {
        print('❌ Lỗi sync Firestore notes: $e');
      },
    );
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();

    // Một số bản cũ đã từng lưu key 'notes' dưới dạng String (vd: "[]")
    // khiến getStringList() bị TypeError trên web. Ta tự migrate/clear trước.
    List<String> notesJson;
    try {
      notesJson = prefs.getStringList(_prefsNotesKey) ?? <String>[];
    } catch (e) {
      final dynamic raw = prefs.get(_prefsNotesKey);
      print('⚠️ Dữ liệu notes bị sai kiểu: ${raw.runtimeType} - $raw');
      await prefs.remove(_prefsNotesKey);
      notesJson = <String>[];
    }

    setState(() {
      _all = notesJson.map((e) => Note.fromJson(jsonDecode(e))).toList();
      _all.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
      _filtered = _all.where((n) => n.title.toLowerCase().contains(_s.text.toLowerCase())).toList();
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = _all.map((note) => jsonEncode(note.toJson())).toList();
    await prefs.setStringList(_prefsNotesKey, notesJson);
  }

  @override
  void dispose() {
    _notesSub?.cancel();
    _s.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _del(int i) async {
    final note = _filtered[i];
    final bool? ok = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Xóa ghi chú này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (ok == true) {
      try {
        print('🗑️ Đang xóa ghi chú: ${note.id}');

        // Optimistic UI
        setState(() {
          _all.removeWhere((n) => n.id == note.id);
          _filtered = _all.where((n) => n.title.toLowerCase().contains(_s.text.toLowerCase())).toList();
        });

        // Local cache update
        await _saveNotes();

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _db.collection('users').doc(user.uid).collection('notes').doc(note.id).delete();
        }

        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa ghi chú thành công')),
        );
      } catch (e) {
        print('❌ Lỗi xóa ghi chú: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF673AB7),
        title: Text('Smart Note - ${user?.email ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _logout),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Bạn chưa đăng nhập'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _s,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Text('Bạn chưa có ghi chú nào!'))
                      : MasonryGridView.count(
                          padding: const EdgeInsets.all(16),
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          itemCount: _filtered.length,
                          itemBuilder: (c, i) => Dismissible(
                            key: Key(_filtered[i].id),
                            direction: DismissDirection.endToStart,
                            background: Container(color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
                            confirmDismiss: (d) async {
                              await _del(i);
                              return false;
                            },
                            child: NoteCard(
                              note: _filtered[i],
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (c) => NoteDetailScreen(note: _filtered[i])),
                                );
                                // Nếu Firestore sync lỗi thì vẫn load từ cache
                                await _loadNotes();
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => const NoteDetailScreen()),
          );
          await _loadNotes();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- WIDGET THẺ GHI CHÚ ---
class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  const NoteCard({super.key, required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: noteColors[note.colorIndex],
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hiển thị ảnh đính kèm nếu có
            if (note.attachments.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: _buildFirstAttachmentPreview(),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isEmpty ? '(Không tiêu đề)' : note.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      DateFormat('dd/MM HH:mm').format(note.modifiedTime),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirstAttachmentPreview() {
    String path = note.attachments.first;
    
    // Kiểm tra nếu là base64 image (web)
    if (path.startsWith('data:image/')) {
      return Image.network(
        path,
        height: 100,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Lỗi hiển thị base64 image: $error');
          return Container(
            height: 100,
            color: Colors.grey[200],
            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
          );
        },
      );
    }
    // Kiểm tra nếu là base64 file khác (web)
    else if (path.startsWith('data:application/')) {
      return Container(
        height: 40,
        color: Colors.black12,
        child: const Center(child: Icon(Icons.attach_file, size: 20)),
      );
    }
    // Kiểm tra nếu là file ảnh local
    else if (path.endsWith('.jpg') || path.endsWith('.png') || path.endsWith('.jpeg')) {
      return Image.file(
        File(path),
        height: 100,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Lỗi hiển thị ảnh local: $error');
          return Container(
            height: 100,
            color: Colors.grey[200],
            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
          );
        },
      );
    }
    // File khác
    return Container(
      height: 40,
      color: Colors.black12,
      child: const Center(child: Icon(Icons.attach_file, size: 20)),
    );
  }
}

// --- MÀN HÌNH CHI TIẾT / SOẠN THẢO ---
class NoteDetailScreen extends StatefulWidget {
  final Note? note;
  const NoteDetailScreen({super.key, this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late TextEditingController _t, _c;
  late String _id;
  int _color = 0;
  List<String> _files = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _id = widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    _t = TextEditingController(text: widget.note?.title ?? '');
    _c = TextEditingController(text: widget.note?.content ?? '');
    _color = widget.note?.colorIndex ?? 0;
    _files = List.from(widget.note?.attachments ?? []);
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      await [
        Permission.storage,
        Permission.camera,
        Permission.photos,
      ].request();
    }
  }

  Future<void> _pickImg() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        String filePath;
        
        if (kIsWeb) {
          // Trên web, đọc bytes và convert sang base64
          final bytes = await image.readAsBytes();
          final base64String = base64Encode(bytes);
          final extension = p.extension(image.name);
          filePath = 'data:image/$extension;base64,$base64String';
          print('✅ Ảnh đã lưu (web): base64 encoded');
        } else {
          // Trên mobile/desktop, lưu vào file system
          final dir = await getApplicationDocumentsDirectory();
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
          final savedImage = await File(image.path).copy('${dir.path}/$fileName');
          filePath = savedImage.path;
          print('✅ Ảnh đã lưu (local): $filePath');
        }
        
        setState(() => _files.add(filePath));
      }
    } catch (e) {
      print('❌ Lỗi chọn ảnh: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi chọn ảnh: $e')),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.bytes != null) {
        String filePath;
        
        if (kIsWeb) {
          // Trên web, dùng bytes và convert sang base64
          final bytes = result.files.single.bytes!;
          final base64String = base64Encode(bytes);
          final fileName = result.files.single.name;
          final extension = p.extension(fileName);
          
          // Kiểm tra nếu là ảnh
          if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension.toLowerCase())) {
            filePath = 'data:image/$extension;base64,$base64String';
          } else {
            // Đối với file khác, lưu dưới dạng data URL
            filePath = 'data:application/$extension;base64,$base64String';
          }
          print('✅ File đã lưu (web): $fileName - base64 encoded');
        } else {
          // Trên mobile/desktop, lưu vào file system
          if (result.files.single.path != null) {
            final dir = await getApplicationDocumentsDirectory();
            final file = File(result.files.single.path!);
            final fileName = p.basename(file.path);
            final savedFile = await file.copy('${dir.path}/$fileName');
            filePath = savedFile.path;
            print('✅ File đã lưu (local): $filePath');
          } else {
            throw Exception('Không thể truy cập file path');
          }
        }
        
        setState(() => _files.add(filePath));
      }
    } catch (e) {
      print('❌ Lỗi chọn file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi chọn file: $e')),
      );
    }
  }

  void _draw() async {
    final SignatureController controller = SignatureController(
      penStrokeWidth: 5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    final bool? ok = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Vẽ/Ký tên'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: Signature(controller: controller, backgroundColor: Colors.grey[200]!),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu')),
        ],
      ),
    );

    if (ok == true && controller.isNotEmpty) {
      try {
        final Uint8List? data = await controller.toPngBytes();
        if (data != null) {
          String fileName = 'draw_${DateTime.now().millisecondsSinceEpoch}.png';
          String filePath;
          
          if (kIsWeb) {
            // Trên web, lưu vào memory và hiển thị dưới dạng base64
            filePath = 'data:image/png;base64,${base64Encode(data)}';
            print('✅ Bản vẽ đã lưu (web): base64 encoded');
          } else {
            // Trên mobile/desktop, lưu vào file system
            final dir = await getApplicationDocumentsDirectory();
            filePath = '${dir.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(data);
            print('✅ Bản vẽ đã lưu (local): $filePath');
          }
          
          setState(() => _files.add(filePath));
        }
      } catch (e) {
        print('❌ Lỗi lưu bản vẽ: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu bản vẽ: $e')),
        );
      }
    }
  }

  Future<bool> _save({required bool popAfterSave}) async {
    if (_loading) return false;

    final title = _t.text.trim();
    final content = _c.text.trim();
    if (title.isEmpty && content.isEmpty && _files.isEmpty && widget.note == null) {
      if (popAfterSave) {
        Navigator.pop(context);
      }
      return true;
    }

    setState(() => _loading = true);

    bool ok = false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Chưa đăng nhập');
      }

      print('📝 Đang lưu ghi chú với ${_files.length} attachments');
      for (int i = 0; i < _files.length; i++) {
        print('  📎 Attachment $i: ${_files[i]}');
        if (_files[i].startsWith('data:')) {
          print('  📎 Type: Base64/Web');
        } else {
          final file = File(_files[i]);
          print('  📎 File tồn tại: ${file.exists()}');
        }
      }

      final updatedNote = Note(
        id: _id,
        title: title,
        content: content,
        modifiedTime: DateTime.now(),
        colorIndex: _color,
        userId: FirebaseAuth.instance.currentUser?.uid,
        attachments: List.from(_files), // Tạo bản sao để tránh reference issues
      );

      // 1) Luôn update local cache trước để back không bị mất dữ liệu
      final prefs = await SharedPreferences.getInstance();

      List<String> notesJson;
      try {
        notesJson = prefs.getStringList(_HomeScreenState._prefsNotesKey) ?? <String>[];
      } catch (e) {
        final dynamic raw = prefs.get(_HomeScreenState._prefsNotesKey);
        print('⚠️ Dữ liệu notes bị sai kiểu (trước khi lưu): ${raw.runtimeType} - $raw');
        await prefs.remove(_HomeScreenState._prefsNotesKey);
        notesJson = <String>[];
      }

      final notes = notesJson.map((e) => Note.fromJson(jsonDecode(e))).toList();

      final existingIndex = notes.indexWhere((n) => n.id == _id);
      if (existingIndex >= 0) {
        notes[existingIndex] = updatedNote;
      } else {
        notes.add(updatedNote);
      }

      notes.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
      await prefs.setStringList(
        _HomeScreenState._prefsNotesKey,
        notes.map((n) => jsonEncode(n.toJson())).toList(),
      );

      // 2) Sau đó ghi Firestore (source of truth)
      Future<void> doWrite() {
        return FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notes')
            .doc(_id)
            .set(updatedNote.toFirestore(), SetOptions(merge: true));
      }

      try {
        await doWrite().timeout(const Duration(seconds: 10));
      } on TimeoutException {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await doWrite().timeout(const Duration(seconds: 20));
      }

      print('✅ Ghi chú đã lưu lên Firestore (và cache local) thành công!');
      
      if (mounted && popAfterSave) Navigator.pop(context);
      ok = true;
    } on FirebaseException catch (e) {
      print('❌ Lỗi lưu FirebaseException: ${e.code} - ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu Firestore: ${e.code}')),
      );
      ok = false;
    } catch (e) {
      print('❌ Lỗi lưu: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu: $e')),
      );
      ok = false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final ok = await _save(popAfterSave: false);
        return ok;
      },
      child: Scaffold(
        backgroundColor: noteColors[_color],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () async {
              final ok = await _save(popAfterSave: true);
              if (!ok) return;
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.palette, color: Colors.black87),
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (c) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      noteColors.length,
                      (i) => GestureDetector(
                        onTap: () {
                          setState(() => _color = i);
                          Navigator.pop(context);
                        },
                        child: CircleAvatar(
                          backgroundColor: noteColors[i],
                          radius: 20,
                          child: _color == i ? const Icon(Icons.check, size: 16) : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextField(
                      controller: _t,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: 'Tiêu đề',
                        border: InputBorder.none,
                      ),
                    ),
                    TextField(
                      controller: _c,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'Nội dung...',
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildAttachmentsList(),
                  ],
                ),
              ),
            ),
            _buildBottomToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsList() {
    if (_files.isEmpty) return const SizedBox.shrink();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _files.length,
      itemBuilder: (c, i) => Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildAttachmentWidget(_files[i]),
            ),
          ),
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: () => setState(() => _files.removeAt(i)),
              child: const Icon(Icons.cancel, color: Colors.red, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentWidget(String path) {
    // Kiểm tra nếu là base64 image (web)
    if (path.startsWith('data:image/')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Lỗi hiển thị base64 image: $error');
          return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
        },
      );
    }
    // Kiểm tra nếu là base64 file khác (web)
    else if (path.startsWith('data:application/')) {
      return const Center(child: Icon(Icons.insert_drive_file, size: 30));
    }
    // Kiểm tra nếu là file ảnh local
    else if (path.endsWith('.png') || path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Lỗi hiển thị ảnh local: $error');
          return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
        },
      );
    }
    // File khác
    return const Center(child: Icon(Icons.insert_drive_file, size: 30));
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(icon: const Icon(Icons.image), onPressed: _pickImg),
          IconButton(icon: const Icon(Icons.attach_file), onPressed: _pickFile),
          IconButton(icon: const Icon(Icons.draw), onPressed: _draw),
        ],
      ),
    );
  }
}
