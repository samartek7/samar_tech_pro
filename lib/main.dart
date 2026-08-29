import 'package:flutter/material.dart';
import 'package:routeros_api/routeros_api.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const SamarTechApp());
}

class SamarTechApp extends StatelessWidget {
  const SamarTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سمر تك برو',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: LoginPage(),
      ),
    );
  }
}

// ================= صفحة تسجيل الدخول =================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _ip = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();

  bool _loading = false;
  String _msg = '';

  Future<void> _connect() async {
    if (_ip.text.trim().isEmpty ||
        _user.text.trim().isEmpty ||
        _pass.text.isEmpty) {
      setState(() {
        _msg = 'يرجى إدخال جميع البيانات';
      });
      return;
    }

    setState(() {
      _loading = true;
      _msg = 'جاري الاتصال...';
    });

    try {
      final client = RouterOSClient(
        _ip.text.trim(),
        _user.text.trim(),
        _pass.text,
        port: 8728,
      );

      await client.connect();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: HomePage(client: client),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _msg = 'فشل الاتصال بالراوتر';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ip.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo, Colors.blue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.router,
                      size: 70,
                      color: Colors.indigo,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'سمر تك برو',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('إدارة شبكات MikroTik'),
                    const SizedBox(height: 25),
                    TextField(
                      controller: _ip,
                      decoration: const InputDecoration(
                        labelText: 'IP المايكروتك',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _user,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _loading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _connect,
                              child: const Text('اتصال'),
                            ),
                          ),
                    const SizedBox(height: 10),
                    Text(_msg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= الصفحة الرئيسية =================

class HomePage extends StatefulWidget {
  final RouterOSClient client;

  const HomePage({
    super.key,
    required this.client,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  bool _loading = false;

  List<dynamic> _users = [];
  List<dynamic> _profiles = [];
  List<dynamic> _vlans = [];

  final TextEditingController _cardCount = TextEditingController();
  final TextEditingController _cardProfile = TextEditingController();

  final List<Map<String, String>> _createdCards = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    try {
      final users =
          await widget.client.send('/ip/hotspot/user/print');
      final profiles =
          await widget.client.send('/ip/hotspot/user/profile/print');
      final vlans =
          await widget.client.send('/interface/vlan/print');

      if (!mounted) return;

      setState(() {
        _users = users;
        _profiles = profiles;
        _vlans = vlans;
      });
    } catch (e) {
      _showMessage('حدث خطأ أثناء تحميل البيانات');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _createCards() async {
    final count = int.tryParse(_cardCount.text);

    if (count == null || count <= 0) {
      _showMessage('أدخل عددًا صحيحًا للكروت');
      return;
    }

    final profile = _cardProfile.text.trim();

    if (profile.isEmpty) {
      _showMessage('أدخل اسم الباقة');
      return;
    }

    setState(() {
      _loading = true;
      _createdCards.clear();
    });

    try {
      for (int i = 0; i < count; i++) {
        final user =
            'card${DateTime.now().millisecondsSinceEpoch}_$i';

        await widget.client.send(
          '/ip/hotspot/user/add',
          {
            'name': user,
            'password': user,
            'profile': profile,
          },
        );

        _createdCards.add({
          'user': user,
          'pass': user,
          'profile': profile,
        });
      }

      _showMessage('تم إنشاء الكروت بنجاح');
      await _loadAll();
    } catch (e) {
      _showMessage('حدث خطأ أثناء إنشاء الكروت');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _cardCount.dispose();
    _cardProfile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildCardsPage(),
      _buildUsersPage(),
      _buildVlanPage(),
      _buildProfilesPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('سمر تك برو'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() => _index = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.credit_card),
            label: 'الكروت',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'المستخدمين',
          ),
          NavigationDestination(
            icon: Icon(Icons.lan),
            label: 'VLAN',
          ),
          NavigationDestination(
            icon: Icon(Icons.speed),
            label: 'الباقات',
          ),
        ],
      ),
    );
  }

  Widget _buildCardsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.credit_card,
            size: 70,
            color: Colors.indigo,
          ),
          const SizedBox(height: 10),
          const Text(
            'إنشاء كروت الهوتسبوت',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 25),
          TextField(
            controller: _cardCount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'عدد الكروت',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _cardProfile,
            decoration: const InputDecoration(
              labelText: 'اسم الباقة',
              hintText: 'مثال: 2M',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _createCards,
              icon: const Icon(Icons.add),
              label: const Text('إنشاء الكروت'),
            ),
          ),
          const SizedBox(height: 25),
          if (_createdCards.isNotEmpty) ...[
            const Text(
              'الكروت التي تم إنشاؤها',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ..._createdCards.map(
              (card) => Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(card['user'] ?? ''),
                  subtitle: Text(
                    'كلمة المرور: ${card['pass']} | الباقة: ${card['profile']}',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsersPage() {
    if (_users.isEmpty) {
      return const Center(
        child: Text('لا يوجد مستخدمون أو لم يتم تحميل البيانات'),
      );
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index] as Map;

        final name = user['name']?.toString() ?? '';
        final profile = user['profile']?.toString() ?? '-';

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(name),
            subtitle: Text('الباقة: $profile'),
          ),
        );
      },
    );
  }

  Widget _buildVlanPage() {
    if (_vlans.isEmpty) {
      return const Center(
        child: Text('لا توجد شبكات VLAN'),
      );
    }

    return ListView.builder(
      itemCount: _vlans.length,
      itemBuilder: (context, index) {
        final vlan = _vlans[index] as Map;

        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading: const Icon(
              Icons.lan,
              color: Colors.indigo,
            ),
            title: Text(vlan['name']?.toString() ?? ''),
            subtitle: Text(
              'VLAN ID: ${vlan['vlan-id']?.toString() ?? ''}',
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfilesPage() {
    if (_profiles.isEmpty) {
      return const Center(
        child: Text('لا توجد باقات أو لم يتم تحميلها'),
      );
    }

    return ListView.builder(
      itemCount: _profiles.length,
      itemBuilder: (context, index) {
        final profile = _profiles[index] as Map;

        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading: const Icon(
              Icons.speed,
              color: Colors.green,
            ),
            title: Text(profile['name']?.toString() ?? ''),
          ),
        );
      },
    );
  }
}
