import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/level_progress_bar.dart';
import '../../widgets/level_badge.dart';
import '../../models/user_account.dart';
import 'edit_credentials_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isOnlineStatsSelected = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final account = userProvider.user;

        if (account == null) {
          return _buildUnauthenticatedView(context);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Account'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.black),
                onPressed: () => _confirmLogout(context, userProvider),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileCard(account: account),
                const SizedBox(height: 24),
                _buildStatsToggle(),
                const SizedBox(height: 24),
                StatsSection(
                  title: _isOnlineStatsSelected ? 'Online Stats' : 'VS Computer Stats',
                  stats: _isOnlineStatsSelected ? account.onlineStats : account.vsComputerStats,
                  icon: _isOnlineStatsSelected ? Icons.public : Icons.computer,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnauthenticatedView(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white, // Set AppBar background to white
      elevation: 0, // Remove shadow
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Account',
        style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0), // Add padding around the content
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_circle,
              size: 100,
              color: Colors.grey, // Use a subtle grey color for the icon
            ),
            const SizedBox(height: 24), // Add spacing below the icon
            const Text(
              'Sign in to track your progress',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87, // Use a darker color for better readability
              ),
              textAlign: TextAlign.center, // Center-align the text
            ),
            const SizedBox(height: 32), // Add spacing before the button
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                backgroundColor: Colors.blue, // Use a primary color for the button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // Rounded corners for the button
                ),
                elevation: 0, // Remove shadow for a flat design
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // White text for better contrast
                ),
              ),
            ),
            const SizedBox(height: 16), // Add spacing between buttons
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blue, // Use a primary color for the text
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildStatsToggle() {
    return Row(
      children: [
        _buildToggleButton(
          title: 'VS Computer',
          icon: Icons.computer,
          isSelected: !_isOnlineStatsSelected,
          onTap: () => setState(() => _isOnlineStatsSelected = false),
        ),
        const SizedBox(width: 16),
        _buildToggleButton(
          title: 'Online',
          icon: Icons.public,
          isSelected: _isOnlineStatsSelected,
          onTap: () => setState(() => _isOnlineStatsSelected = true),
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, UserProvider userProvider) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      title: Row(
        children: [
          Icon(Icons.warning, color: isDarkMode ? Colors.orange[300] : Colors.orange),
          const SizedBox(width: 8),
          Text(
            'Confirm Logout',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to log out?',
        style: TextStyle(
          fontSize: 16,
          color: isDarkMode ? Colors.grey[400] : Colors.grey,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.grey[400] : Colors.grey,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context); // Close dialog
            await userProvider.signOut();
            if (context.mounted) Navigator.pop(context); // Go back to previous screen
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          child: const Text(
            'Logout',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}
}

class ProfileCard extends StatelessWidget {
  final UserAccount account;

  const ProfileCard({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              // Profile Avatar with Level Badge
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  // Level Badge
                  LevelBadge.fromUserLevel(
                    userLevel: account.userLevel,
                    fontSize: 14,
                    showIcon: false,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Username with Level
              Text(
                account.username,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                account.email,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              
              // Level Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: LevelProgressBar(
                  userLevel: account.userLevel,
                  progressColor: Colors.amber,
                  backgroundColor: Colors.amber.shade100,
                  height: 15,
                  showPercentage: false,
                ),
              ),
              const SizedBox(height: 16),
              
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditCredentialsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Credentials'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatsSection extends StatelessWidget {
  final String title;
  final GameStats stats;
  final IconData icon;

  const StatsSection({
    super.key,
    required this.title,
    required this.stats,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            StatCard(
              title: 'Matches Played',
              value: stats.gamesPlayed.toString(),
              icon: Icons.sports_esports,
            ),
            StatCard(
              title: 'Games Won',
              value: stats.gamesWon.toString(),
              icon: Icons.emoji_events,
            ),
            StatCard(
              title: 'Win Rate',
              value: '${stats.winRate.toStringAsFixed(1)}%',
              icon: Icons.trending_up,
            ),
            StatCard(
              title: 'Win Streak',
              value: stats.currentWinStreak.toString(),
              icon: Icons.whatshot,
            ),
            StatCard(
              title: 'Best Streak',
              value: stats.highestWinStreak.toString(),
              icon: Icons.star,
            ),
            StatCard(
              title: 'Avg Moves to Win',
              value: stats.winningGames > 0 
                ? stats.averageMovesToWin.toStringAsFixed(1)
                : '-',
              icon: Icons.route,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          stats.lastPlayed != null 
            ? 'Last Played: ${DateFormat('MMM dd, yyyy').format(stats.lastPlayed!)}'
            : 'No games played yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}