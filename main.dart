// main.dart
// Dépendances requises dans pubspec.yaml : shared_preferences, url_launcher, image_picker

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(RepertoireApp());
}

class RepertoireApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Répertoire amélioré',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        colorScheme:
            ColorScheme.fromSwatch(primarySwatch: Colors.indigo).copyWith(secondary: Colors.teal),
      ),
      home: ContactListScreen(),
    );
  }
}

class Contact {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String? imagePath; // chemin local vers l'image

  Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.imagePath,
  });

  factory Contact.fromMap(Map<String, dynamic> m) => Contact(
        id: m['id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String,
        email: m['email'] as String,
        imagePath: m['imagePath'] != null ? m['imagePath'] as String : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'imagePath': imagePath,
      };
}

class ContactListScreen extends StatefulWidget {
  @override
  _ContactListScreenState createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  List<Contact> _contacts = [];
  List<Contact> _filtered = [];
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  bool _showAll = true;
  bool _sortAZ = true;

  static const String _storageKey = 'contacts_v2';

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    if (raw.isEmpty) {
      // contacts par défaut
      _contacts = [
        Contact(id: '1', name: 'Anthony Loiseau', phone: '0747400388', email: 'anthony@example.com'),
        Contact(id: '2', name: 'Dorian Renard', phone: '0716437469', email: 'dorian@example.com'),
        Contact(id: '3', name: 'Antoine Thaillay', phone: '0744734809', email: 'antoine@example.com'),
        Contact(id: '4', name: 'Gauthier Mayer', phone: '0781089090', email: 'gauthier@example.com'),
        Contact(id: '5', name: 'Mathilde Lehec', phone: '0761845334', email: 'mathilde@example.com'),
        Contact(id: '6', name: 'Clarisse Milcent', phone: '0768126451', email: 'clarisse@example.com'),
      ];
      await _saveContacts();
    } else {
      _contacts = raw.map((s) {
        final Map<String, dynamic> m = jsonDecode(s) as Map<String, dynamic>;
        return Contact.fromMap(m);
      }).toList();
    }

    _applySort();
    _updateFiltered();
    setState(() {
      _loading = false;
    });
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = _contacts.map((c) => jsonEncode(c.toMap())).toList();
    await prefs.setStringList(_storageKey, storage);
  }

  void _applySort() {
    _contacts.sort((a, b) => _sortAZ
        ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
        : b.name.toLowerCase().compareTo(a.name.toLowerCase()));
  }

  void _updateFiltered() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = _showAll ? List.from(_contacts) : [];
    } else {
      _filtered = _contacts
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.phone.contains(q) ||
              c.email.toLowerCase().contains(q))
          .toList();
    }
    setState(() {});
  }

  void _onSearchChanged() => _updateFiltered();

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _addOrEditContact({Contact? existing}) async {
    final result = await showModalBottomSheet<Contact?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ContactForm(contact: existing),
      ),
    );

    if (result != null) {
      final exists = _contacts.any((c) => c.id == result.id);
      if (exists) {
        _contacts = _contacts.map((c) => c.id == result.id ? result : c).toList();
      } else {
        _contacts.add(result);
      }
      _applySort();
      await _saveContacts();
      _updateFiltered();
    }
  }

  Future<void> _deleteContact(Contact contact) async {
    setState(() {
      _contacts.removeWhere((c) => c.id == contact.id);
      _updateFiltered();
    });
    await _saveContacts();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Contact supprimé'),
      action: SnackBarAction(
        label: 'Annuler',
        onPressed: () async {
          _contacts.add(contact);
          _applySort();
          await _saveContacts();
          _updateFiltered();
        },
      ),
    ));
  }

  Color _avatarColor(String id) {
    final int hash = id.codeUnits.fold(0, (p, e) => p + e);
    final colors = [Colors.indigo, Colors.teal, Colors.deepPurple, Colors.orange, Colors.blueGrey];
    return colors[hash % colors.length];
  }

  ImageProvider? _avatarImageProvider(Contact contact) {
    if (contact.imagePath == null) return null;
    try {
      final f = File(contact.imagePath!);
      if (f.existsSync()) return FileImage(f);
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Répertoire'),
        actions: [
          IconButton(
            icon: Icon(_sortAZ ? Icons.sort_by_alpha : Icons.sort),
            tooltip: 'Trier',
            onPressed: () {
              setState(() {
                _sortAZ = !_sortAZ;
                _applySort();
                _updateFiltered();
              });
            },
          ),
          IconButton(
            icon: Icon(_showAll ? Icons.visibility_off : Icons.visibility),
            tooltip: _showAll ? 'Cacher' : 'Afficher',
            onPressed: () {
              setState(() {
                _showAll = !_showAll;
                _updateFiltered();
              });
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Rechercher nom, téléphone ou email',
                      fillColor: Colors.grey[100],
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty ? 'Aucun contact affiché' : 'Aucun résultat',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final contact = _filtered[index];
                            final avatarImage = _avatarImageProvider(contact);
                            return Dismissible(
                              key: ValueKey(contact.id),
                              background: Container(color: Colors.redAccent, alignment: Alignment.centerLeft, padding: EdgeInsets.only(left: 20), child: Icon(Icons.delete, color: Colors.white)),
                              secondaryBackground: Container(color: Colors.redAccent, alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20), child: Icon(Icons.delete_forever, color: Colors.white)),
                              onDismissed: (_) => _deleteContact(contact),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: avatarImage,
                                  backgroundColor: avatarImage == null ? _avatarColor(contact.id) : null,
                                  child: avatarImage == null ? Text(contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?', style: TextStyle(color: Colors.white)) : null,
                                ),
                                title: Text(contact.name),
                                subtitle: Text('${contact.phone} • ${contact.email}'),
                                onTap: () async {
                                  final updated = await Navigator.of(context).push<Contact?>(
                                    MaterialPageRoute(builder: (_) => ContactDetailsScreen(contact: contact)),
                                  );
                                  if (updated != null) {
                                    // returned contact means edit happened
                                    final idx = _contacts.indexWhere((c) => c.id == updated.id);
                                    if (idx != -1) {
                                      _contacts[idx] = updated;
                                      _applySort();
                                      await _saveContacts();
                                      _updateFiltered();
                                    }
                                  }
                                },
                                trailing: IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () => _addOrEditContact(existing: contact),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          final newContact = await showModalBottomSheet<Contact?>(
            context: context,
            isScrollControlled: true,
            builder: (context) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: ContactForm(contact: null),
            ),
          );

          if (newContact != null) {
            // ensure unique id and preserve imagePath
            final created = Contact(
              id: _generateId(),
              name: newContact.name,
              phone: newContact.phone,
              email: newContact.email,
              imagePath: newContact.imagePath,
            );
            _contacts.add(created);
            _applySort();
            await _saveContacts();
            _updateFiltered();
          }
        },
      ),
    );
  }
}

class ContactForm extends StatefulWidget {
  final Contact? contact;
  ContactForm({this.contact});

  @override
  _ContactFormState createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;

  final ImagePicker _picker = ImagePicker();
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.contact?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.contact?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.contact?.email ?? '');
    _imagePath = widget.contact?.imagePath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _imagePath = picked.path;
        });
      }
    } catch (e) {
      // ignore errors for now, optionally show snackbar
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Galerie'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Appareil photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Supprimer la photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _imagePath = null;
                  });
                },
              ),
            ListTile(
              leading: Icon(Icons.close),
              title: Text('Annuler'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      final c = Contact(
        id: widget.contact?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        imagePath: _imagePath,
      );
      Navigator.of(context).pop(c);
    }
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Numéro requis';
    final normalized = v.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.length < 6) return 'Numéro invalide';
    return null;
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Nom requis';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optionnel
    final pattern = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!pattern.hasMatch(v.trim())) return 'Email invalide';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _imagePath != null && File(_imagePath!).existsSync() ? FileImage(File(_imagePath!)) : null;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.contact == null ? 'Ajouter un contact' : 'Modifier le contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showImageSourceSheet,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: avatar,
                      backgroundColor: avatar == null ? Colors.indigo : null,
                      child: avatar == null ? Icon(Icons.camera_alt, size: 36, color: Colors.white) : null,
                    ),
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _nameCtrl,
                    validator: _validateName,
                    decoration: InputDecoration(labelText: 'Nom', border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneCtrl,
                    validator: _validatePhone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtrl,
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: 'Email (optionnel)', border: OutlineInputBorder()),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          child: Text('Enregistrer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactDetailsScreen extends StatelessWidget {
  final Contact contact;
  ContactDetailsScreen({required this.contact});

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      throw 'Impossible de lancer $uri';
    }
  }

  Future<void> _launchSms(String phone) async {
    final uri = Uri(scheme: 'sms', path: phone);
    if (!await launchUrl(uri)) {
      throw 'Impossible de lancer $uri';
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'Salut', 'body': 'Bonjour !'},
    );
    if (!await launchUrl(uri)) {
      throw 'Impossible de lancer $uri';
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = (contact.imagePath != null && File(contact.imagePath!).existsSync()) ? FileImage(File(contact.imagePath!)) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Détails'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () async {
              final updated = await showModalBottomSheet<Contact?>(
                context: context,
                isScrollControlled: true,
                builder: (context) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: ContactForm(contact: contact),
                ),
              );

              if (updated != null) {
                Navigator.of(context).pop(updated); // return updated contact to previous screen
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundImage: imageProvider,
              child: imageProvider == null ? Text(contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?', style: TextStyle(fontSize: 30)) : null,
            ),
            SizedBox(height: 12),
            Text(contact.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(contact.phone, style: TextStyle(fontSize: 16)),
            SizedBox(height: 4),
            Text(contact.email.isNotEmpty ? contact.email : 'Aucun email', style: TextStyle(color: Colors.grey[700])),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _launchPhone(contact.phone),
                  icon: Icon(Icons.phone),
                  label: Text('Appeler'),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _launchSms(contact.phone),
                  icon: Icon(Icons.message),
                  label: Text('SMS'),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: contact.email.isNotEmpty ? () => _launchEmail(contact.email) : null,
                  icon: Icon(Icons.email),
                  label: Text('Email'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
