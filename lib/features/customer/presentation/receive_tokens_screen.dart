import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/providers/global_providers.dart';

class ReceiveTokensScreen extends ConsumerStatefulWidget {
  const ReceiveTokensScreen({super.key});

  @override
  ConsumerState<ReceiveTokensScreen> createState() => _ReceiveTokensScreenState();
}

class _ReceiveTokensScreenState extends ConsumerState<ReceiveTokensScreen> {
  String _selectedNetwork = 'Cardano';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userAddress = user?.walletAddress ?? 'addr1q8a72b100641de406d824855a782b13fa92c3ff';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => context.canPop() ? context.pop() : context.go('/customer/home'),
        ),
        title: const Text('Receive Assets', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Network Switcher Chips
              Text(
                'SELECT LEDGER NETWORK',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.outline,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['Cardano', 'Ethereum', 'Arbitrum'].map((net) {
                  final isSelected = _selectedNetwork == net;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(net, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedNetwork = net;
                          });
                        }
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.1),
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(),

              // Centered QR Code Box
              BentoCard(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Dynamic QR Representation
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Styled QR Pattern lines
                          Container(
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage('https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$userAddress'),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          // App icon overlay in center
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.all_inclusive, color: AppColors.primary, size: 28),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Scan to make $_selectedNetwork payment',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Address Display & Copy Button
              BentoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RECEIVING ADDRESS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.outline),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            userAddress,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.onSurface),
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy, color: AppColors.primary),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: userAddress));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Address copied to clipboard.')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
