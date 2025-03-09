import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vanishingtictactoe/screens/game/mode_selection_screen.dart';
import '../../providers/hell_mode_provider.dart';
import '../../models/utils/logger.dart';
import 'matchmaking_screen.dart';
import '../../widgets/mission_icon.dart';


class OnlineScreen extends StatefulWidget {
  final bool returnToModeSelection;
  
  const OnlineScreen({
    super.key,
    this.returnToModeSelection = false,
  });

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  


  void _startMatchmaking() {
    final hellModeProvider = Provider.of<HellModeProvider>(context, listen: false);
    final isHellMode = hellModeProvider.isHellModeActive;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchmakingScreen(
          isHellMode: isHellMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Navigate back to mode selection by popping to first route
            logger.i('Navigating back to mode selection screen');
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ModeSelectionScreen()));
          },
        ),
        title: const Text(
          'Online Match',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: MissionIcon(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  _buildMatchTypeDescription(),
                  Consumer<HellModeProvider>(
                    builder: (context, hellModeProvider, child) {
                      if (hellModeProvider.isHellModeActive) {
                        return Column(
                          children: [
                            const SizedBox(height: 30),
                            _buildHellModeIndicator(),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const Spacer(),
                  _buildPlayButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildMatchTypeDescription() {
    const description = 'Play casual games with other players.';
    const icon = Icons.sports_esports;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              icon,
              size: 48,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(
                fontSize: 18,
                height: 1.5,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),

          ],
        ),
      ),
    );
  }
  
  Widget _buildHellModeIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade800),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.whatshot, color: Colors.red.shade800),
            const SizedBox(width: 8),
            Text(
              'HELL MODE ACTIVE',
              style: TextStyle(
                color: Colors.red.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return Consumer<HellModeProvider>(
      builder: (context, hellModeProvider, child) {
        final isHellModeActive = hellModeProvider.isHellModeActive;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startMatchmaking,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isHellModeActive 
                    ? Colors.red.shade900 
                    : Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isHellModeActive)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.whatshot, color: Colors.yellow),
                    ),
                  Text(
                    isHellModeActive 
                        ? 'PLAY HELL MODE' 
                        : 'PLAY CASUAL',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isHellModeActive ? FontWeight.bold : FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}