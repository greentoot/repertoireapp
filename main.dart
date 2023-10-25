import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(RepertoireApp());
}

class RepertoireApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Répertoire Téléphonique',
      theme: ThemeData(
        primaryColor: Colors.blue,
        colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.blue, accentColor: Colors.teal),
      ),
      home: ContactListScreen(),
    );
  }
}

class ContactListScreen extends StatefulWidget {
  @override
  _ContactListScreenState createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  List<Contact> contacts = [];
  List<Contact> displayedContacts = [];
  final TextEditingController searchController = TextEditingController();
  bool showAllContacts = false;

  @override
  void initState() {
    super.initState();
    loadContacts();
  }

  void loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsData = prefs.getStringList('contacts') ?? [];
    if (contactsData.isNotEmpty) {
      contacts = contactsData.map((data) {
        final contactInfo = data.split('|');
        return Contact(name: contactInfo[0], phoneNumber: contactInfo[1]);
      }).toList();
      setState(() {
        displayedContacts = List.from(contacts);
      });
    } else {
      // Contacts de base
      final initialContacts = [
        Contact(name: 'Anthony Loiseau', phoneNumber: '0767400388'),
        Contact(name: 'Dorian Reanrd', phoneNumber: '0716637469'),
        Contact(name: 'Antoine Thaillay', phoneNumber: '0733734809'),
        Contact(name: 'Gauthier Mayer', phoneNumber: '0781096090'),
        Contact(name: 'Mathilde Lehec', phoneNumber: '0761828334'),
        Contact(name: 'Clarisse Milcent', phoneNumber: '0768126711'),
      ];

      contacts.addAll(initialContacts);
      displayedContacts.addAll(initialContacts);
      saveContacts();
    }
  }

  void saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsData =
        contacts.map((c) => "${c.name}|${c.phoneNumber}").toList();
    prefs.setStringList('contacts', contactsData);
  }

  bool contactExists(Contact newContact) {
    return contacts.any((contact) =>
        contact.name == newContact.name &&
        contact.phoneNumber == newContact.phoneNumber);
  }

  void addNewContact(Contact newContact) {
    if (!contactExists(newContact)) {
      contacts.add(newContact);
      displayedContacts.add(newContact);
      saveContacts();
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Contact déjà existant'),
            content: Text('Ce contact existe déjà dans votre répertoire.'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  void filterContacts(String query) {
    if (query.isEmpty) {
      setState(() {
        displayedContacts = showAllContacts ? List.from(contacts) : [];
      });
    } else {
      setState(() {
        displayedContacts = contacts
            .where((contact) =>
                contact.name.toLowerCase().contains(query.toLowerCase()) ||
                contact.phoneNumber.contains(query))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Liste des Contacts'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              onChanged: (text) {
                filterContacts(text);
              },
              decoration: InputDecoration(
                labelText: 'Recherche de Contacts',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                showAllContacts = !showAllContacts;
                if (showAllContacts) {
                  displayedContacts = List.from(contacts);
                } else {
                  displayedContacts = [];
                }
              });
            },
            child: Text(showAllContacts
                ? 'Cacher tous les contacts'
                : 'Afficher tous les contacts'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: displayedContacts.length,
              itemBuilder: (context, index) {
                final contact = displayedContacts[index];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) =>
                          ContactDetailsScreen(contact: contact),
                    ));
                  },
                  child: ListTile(
                    leading: Icon(Icons.person),
                    title: Text(contact.name,
                        style: TextStyle(color: Colors.blue)),
                    subtitle: Text(contact.phoneNumber,
                        style: TextStyle(color: Colors.teal)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => AddContactScreen(
              onSave: (newContact) {
                addNewContact(newContact);
              },
            ),
          ));
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class Contact {
  final String name;
  final String phoneNumber;

  Contact({
    required this.name,
    required this.phoneNumber,
  });
}

class AddContactScreen extends StatefulWidget {
  final Function(Contact) onSave;

  AddContactScreen({required this.onSave});

  @override
  _AddContactScreenState createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ajouter un Contact'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Nom'),
            ),
            TextField(
              controller: phoneNumberController,
              decoration: InputDecoration(labelText: 'Numéro de téléphone'),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () {
                final String name = nameController.text;
                final String phoneNumber = phoneNumberController.text;
                final newContact =
                    Contact(name: name, phoneNumber: phoneNumber);
                widget.onSave(newContact);
                Navigator.of(context).pop();
              },
              child: Text('Ajouter'),
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

  void _launchPhone(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Impossible de lancer $url';
    }
  }

  void _launchMessage(String phoneNumber) async {
    final url = 'sms:$phoneNumber';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Impossible de lancer $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails du Contact'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(contact.name,
                style: TextStyle(fontSize: 24, color: Colors.blue)),
            Text(contact.phoneNumber,
                style: TextStyle(fontSize: 18, color: Colors.teal)),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.phone),
                  onPressed: () {
                    _launchPhone(contact.phoneNumber);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.message),
                  onPressed: () {
                    _launchMessage(contact.phoneNumber);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
