import 'package:flutter/material.dart';

// ✅ FIX: Absolute imports ensure we find the generated classes
import 'package:cscb_app/core/di/locator.dart';
import 'package:cscb_app/data/local/repositories/org_repository.dart';
import 'package:cscb_app/data/local/db/app_database.dart';

class OrganizationPage extends StatefulWidget {
  const OrganizationPage({super.key});

  @override
  State<OrganizationPage> createState() => _OrganizationPageState();
}

class _OrganizationPageState extends State<OrganizationPage> {
  int _tabIndex = 0;

  // Get the repository from our Service Locator (GetIt)
  final _orgRepo = getIt<OrgRepository>();

  final _orgNameController = TextEditingController();

  void _createOrganization() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Organization'),
        content: TextField(
          controller: _orgNameController,
          decoration: const InputDecoration(
            labelText: 'Organization Name',
            hintText: 'e.g. Computer Society',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_orgNameController.text.isNotEmpty) {
                // Call the repository to save to SQLite
                await _orgRepo.registerPresident(
                  userName: 'Current User',
                  orgName: _orgNameController.text,
                );

                if (context.mounted) {
                  _orgNameController.clear();
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Organization Created Locally!'),
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              _buildTabItem('My Organization', 0),
              _buildTabItem('Other Organization', 1),
            ],
          ),
        ),
      ),
      // StreamBuilder listens to the database for changes
      body: StreamBuilder<List<Organization>>(
        stream: _tabIndex == 0
            ? _orgRepo.watchMyOrganizations()
            : _orgRepo.watchOtherOrganizations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final orgs = snapshot.data ?? [];

          if (orgs.isEmpty) {
            return Center(
              child: Text(
                _tabIndex == 0
                    ? 'You haven\'t joined any organizations.'
                    : 'No active organizations found.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orgs.length,
            itemBuilder: (context, index) {
              final org = orgs[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.lightBlue[100],
                    child: const Icon(Icons.business, color: Colors.lightBlue),
                  ),
                  title: Text(
                    org.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Status: ${org.status}'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _createOrganization,
              icon: const Icon(Icons.add),
              label: const Text('Create'),
              backgroundColor: Colors.lightBlue,
            )
          : null,
    );
  }

  Widget _buildTabItem(String title, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          decoration: BoxDecoration(
            color: _tabIndex == index ? Colors.white : Colors.grey[200],
            border: Border(
              bottom: BorderSide(
                color: _tabIndex == index
                    ? Colors.lightBlue
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: _tabIndex == index ? Colors.lightBlue : Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
