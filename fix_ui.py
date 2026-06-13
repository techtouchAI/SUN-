import re

# Fix LoadInputScreen duplicate button
with open('lib/screens/load_input_screen.dart', 'r') as f:
    content = f.read()

content = content.replace('''            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardScreen()),
                );
              },
            )''', '')

with open('lib/screens/load_input_screen.dart', 'w') as f:
    f.write(content)

# Fix SettingsScreen Telegram Link
with open('lib/screens/settings_screen.dart', 'r') as f:
    content = f.read()

content = content.replace('''                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  final url = Uri.parse('https://t.me/techtouch7');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },''', '''                trailing: const Icon(Icons.telegram),
                onTap: () async {
                  try {
                    final url = Uri.parse('https://t.me/techtouch7');
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    debugPrint('Could not launch Telegram: $e');
                  }
                },''')

with open('lib/screens/settings_screen.dart', 'w') as f:
    f.write(content)
