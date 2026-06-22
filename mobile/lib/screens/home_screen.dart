import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/scanner_provider.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        final scanner = Provider.of<ScannerProvider>(context, listen: false);
        scanner.loadDailyStats(auth.user!.uid);
        scanner.loadHistory(auth.user!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final scanner = Provider.of<ScannerProvider>(context);

    final displayName = auth.profile?.name ?? auth.user?.displayName ?? 'User';
    final dailyCalGoal = auth.profile?.dailyCalorieGoal ?? 2000;
    final calPercent = dailyCalGoal > 0 ? (scanner.dailyCalories / dailyCalGoal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF3B82F6),
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Good Morning, 👋", style: TextStyle(fontSize: 12, color: Colors.white60)),
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            )
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (auth.isAuthenticated) {
            await scanner.loadDailyStats(auth.user!.uid);
            await scanner.loadHistory(auth.user!.uid);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Health Score Banner
              Card(
                color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("AI Health Score", style: TextStyle(color: Colors.white60, fontSize: 13)),
                            const SizedBox(height: 4),
                            const Text("87/100", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "Excellent",
                                style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            )
                          ],
                        ),
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              value: calPercent,
                              strokeWidth: 8,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                            ),
                          ),
                          Text(
                            "${(calPercent * 100).toInt()}%",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Real-time Metrics Grid
              const Text("Today's Progress", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _metricCard(
                    title: "Calories",
                    value: "${scanner.dailyCalories} kcal",
                    icon: Icons.local_fire_department,
                    color: Colors.orange,
                  ),
                  _metricCard(
                    title: "Water Logs",
                    value: "${scanner.dailyWater.toStringAsFixed(2)} L",
                    icon: Icons.local_drink,
                    color: Colors.blue,
                    onTap: () {
                      if (auth.isAuthenticated) {
                        scanner.logWater(auth.user!.uid, 0.25);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("💧 logged +250ml water successfully!"), duration: Duration(seconds: 1)),
                        );
                      }
                    },
                  ),
                  _metricCard(
                    title: "Steps Sync",
                    value: "${scanner.dailySteps}",
                    icon: Icons.directions_walk,
                    color: Colors.green,
                    onTap: () {
                      _showStepsSyncDialog(context, scanner);
                    },
                  ),
                  _metricCard(
                    title: "AI Scans",
                    value: "${scanner.dailyScans}",
                    icon: Icons.camera_alt,
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Scans Feed
              const Text("Recent Scans", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              scanner.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (scanner.scanHistory.isEmpty
                      ? const Card(
                          color: Colors.white10,
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                "No scans saved yet. Tap Scanner below to log food!",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: scanner.scanHistory.length > 5 ? 5 : scanner.scanHistory.length,
                          itemBuilder: (context, idx) {
                            final item = scanner.scanHistory[idx];
                            return Card(
                              color: const Color(0xFF1E293B),
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.white10,
                                  child: Text(item.emoji, style: const TextStyle(fontSize: 20)),
                                ),
                                title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text("${item.calories} kcal · Score ${item.score}/100", style: const TextStyle(color: Colors.white60)),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white38),
                              ),
                            );
                          },
                        )),
            ],
          ),
        ),
      ),
    );
  }

  void _showStepsSyncDialog(BuildContext context, ScannerProvider scanner) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.directions_walk, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text("Phone Steps Sync", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Connect and synchronize your phone's fitness tracking data to monitor your daily steps.",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Connection Status:", style: TextStyle(color: Colors.white60, fontSize: 12)),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: scanner.isPhoneConnected ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              scanner.isPhoneConnected ? "Connected" : "Disconnected",
                              style: TextStyle(
                                color: scanner.isPhoneConnected ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Steps Counted:", style: TextStyle(color: Colors.white60, fontSize: 12)),
                        Text(
                          "${scanner.dailySteps}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Close", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: scanner.isLoading
                      ? null
                      : () async {
                          if (scanner.isPhoneConnected) {
                            await scanner.disconnectPhone();
                            setStateDialog(() {});
                          } else {
                            await scanner.connectPhoneAndSyncSteps();
                            setStateDialog(() {});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("👟 Phone steps synced successfully!"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scanner.isPhoneConnected ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: scanner.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : Text(
                          scanner.isPhoneConnected ? "Disconnect" : "Sync Phone Steps",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 28),
                  if (onTap != null)
                    const Icon(Icons.add_circle_outline, color: Colors.white30, size: 20),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
