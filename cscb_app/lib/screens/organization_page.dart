import 'package:flutter/material.dart';

class OrganizationPage extends StatefulWidget {
  const OrganizationPage({super.key});

  @override
  State<OrganizationPage> createState() => _OrganizationPageState();
}

class _OrganizationPageState extends State<OrganizationPage> {
  int _tabIndex = 0;
  final List<String> myOrganizations = ['Org A', 'Org B'];
  final List<String> otherOrganizations = ['Org C', 'Org D'];

  void _createOrganization() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Organization'),
        content: const Text('Organization creation form goes here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinButton(String orgName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join Organization'),
        content: Text('Join $orgName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Join'),
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
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tabIndex = 0),
                  child: Container(
                    color: _tabIndex == 0 ? Colors.white : Colors.grey[200],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'My Organization',
                        style: TextStyle(
                          color: _tabIndex == 0
                              ? Colors.lightBlue
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tabIndex = 1),
                  child: Container(
                    color: _tabIndex == 1 ? Colors.white : Colors.grey[200],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'Other Organization',
                        style: TextStyle(
                          color: _tabIndex == 1
                              ? Colors.lightBlue
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: (_tabIndex == 0 ? myOrganizations : otherOrganizations)
            .map(
              (org) => Card(
                child: ListTile(
                  title: Text(org),
                  trailing: _tabIndex == 1
                      ? ElevatedButton(
                          onPressed: () => _showJoinButton(org),
                          child: const Text('Join Organization'),
                        )
                      : null,
                  onTap: () {
                    // Show org details
                  },
                ),
              ),
            )
            .toList(),
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _createOrganization,
              icon: const Icon(Icons.add),
              label: const Text('Create Organization'),
              backgroundColor: Colors.lightBlue,
            )
          : null,
    );
  }
}
