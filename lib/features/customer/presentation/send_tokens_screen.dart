import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/data/repository.dart';
import '../../../shared/domain/models.dart';

class SendTokensScreen extends ConsumerStatefulWidget {
  final String? prefillAddress;
  final String? prefillAmount;
  final String? prefillSymbol;
  final String? prefillTitle;
  final String? prefillEscrowId;
  final String? prefillMerchantId;
  final String? prefillMerchantName;

  const SendTokensScreen({
    this.prefillAddress,
    this.prefillAmount,
    this.prefillSymbol,
    this.prefillTitle,
    this.prefillEscrowId,
    this.prefillMerchantId,
    this.prefillMerchantName,
    super.key,
  });

  @override
  ConsumerState<SendTokensScreen> createState() => _SendTokensScreenState();
}

class _SendTokensScreenState extends ConsumerState<SendTokensScreen> {
  final TextEditingController _addressController = TextEditingController();
  String _amount = '';
  String _selectedSymbol = 'ADA';
  String? _scannedTitle;
  String? _scannedEscrowId;
  // ignore: unused_field
  String? _scannedMerchantId;
  String? _scannedMerchantName;

  @override
  void initState() {
    super.initState();
    if (widget.prefillAddress != null) {
      _addressController.text = widget.prefillAddress!;
    }
    if (widget.prefillAmount != null) {
      _amount = widget.prefillAmount!;
    }
    if (widget.prefillSymbol != null) {
      _selectedSymbol = widget.prefillSymbol!.toUpperCase();
    }
    _scannedTitle = widget.prefillTitle;
    _scannedEscrowId = widget.prefillEscrowId;
    _scannedMerchantId = widget.prefillMerchantId;
    _scannedMerchantName = widget.prefillMerchantName;
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _handleDigitPressed(String digit) {
    if (digit == '.') {
      if (_amount.contains('.')) return;
      if (_amount.isEmpty) {
        setState(() => _amount = '0.');
        return;
      }
    }
    setState(() {
      _amount = '$_amount$digit';
    });
  }

  void _handleBackspace() {
    if (_amount.isNotEmpty) {
      setState(() {
        _amount = _amount.substring(0, _amount.length - 1);
      });
    }
  }

  void _handleScanQR() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Lumina Secure QR Scanner',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Point your camera at a Cardano, USDC or Ethereum QR payload, or upload from your device gallery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Scan with Secure Camera', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _showCameraViewfinder();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Select QR from Gallery', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _showGallerySelector();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showCameraViewfinder() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return Dialog.fullscreen(
              backgroundColor: Colors.black.withOpacity(0.95),
              child: Stack(
                children: [
                  // App Bar / Header
                  Positioned(
                    top: 40,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ZeroPay Secure Lens',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Viewfinder Frame
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
                          ),
                          child: Stack(
                            children: [
                              // Viewfinder Corners
                              Positioned(top: 16, left: 16, child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 3), left: BorderSide(color: Colors.white, width: 3))))),
                              Positioned(top: 16, right: 16, child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 3), right: BorderSide(color: Colors.white, width: 3))))),
                              Positioned(bottom: 16, left: 16, child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 3), left: BorderSide(color: Colors.white, width: 3))))),
                              Positioned(bottom: 16, right: 16, child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 3), right: BorderSide(color: Colors.white, width: 3))))),
                              
                              // Glowing laser animation line
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: 1),
                                duration: const Duration(seconds: 2),
                                builder: (context, value, child) {
                                  final double topPosition = 20 + (220 * value);
                                  return Positioned(
                                    top: topPosition,
                                    left: 20,
                                    right: 20,
                                    child: Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.8),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const Center(
                                child: Text(
                                  'ALIGN QR CODE',
                                  style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Auto-focusing on QR payload...',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // Bottom targets panel
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DETECTED QR CODES (SIMULATED)',
                          style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 12),
                        _buildViewfinderTargetCard(
                          title: 'Acme Corp Web Milestone 1',
                          subtitle: '1,500.00 ADA (Escrow Lock)',
                          payload: 'zeropay://pay?address=addr1q8a72b100641de406d824855a782b13fa92c3ff&amount=1500.00&symbol=ADA&title=Acme%20Corp%20Web%20Milestone%201&escrowId=ZP-8842',
                          onTap: (p) => _startProcessingScan(p),
                        ),
                        const SizedBox(height: 8),
                        _buildViewfinderTargetCard(
                          title: 'CryptoBrews Espresso Beans',
                          subtitle: '12.50 ADA (Direct Transfer)',
                          payload: 'zeropay://pay?address=addr1q8a72b100641de406d824855a782b13fa92c3ff&amount=12.50&symbol=ADA&title=CryptoBrews%20Artisan%20Coffee&escrowId=ZP-1001',
                          onTap: (p) => _startProcessingScan(p),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildViewfinderTargetCard(
                                title: 'Invalid QR Payload',
                                subtitle: 'Trigger error validation',
                                payload: 'zeropay://invalid-payload-data',
                                onTap: (p) => _startProcessingScan(p),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildViewfinderTargetCard(
                                title: 'Unreadable QR Image',
                                subtitle: 'Trigger unreadable error',
                                payload: 'zeropay://unreadable-matrix-corruption',
                                onTap: (p) => _startProcessingScan(p),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildViewfinderTargetCard({
    required String title,
    required String subtitle,
    required String payload,
    required Function(String) onTap,
  }) {
    return GestureDetector(
      onTap: () => onTap(payload),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code, color: AppColors.primary, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 12),
          ],
        ),
      ),
    );
  }

  void _showGallerySelector() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppColors.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select QR from Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Images containing ZeroPay invoice payloads:',
                  style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 240,
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildGalleryItem(
                        fileName: 'Invoice_ZP-8842.png',
                        title: 'Acme Web Project',
                        price: '1,500.00 ADA',
                        payload: 'zeropay://pay?address=addr1q8a72b100641de406d824855a782b13fa92c3ff&amount=1500.00&symbol=ADA&title=Acme%20Corp%20Web%20Milestone%201&escrowId=ZP-8842',
                      ),
                      _buildGalleryItem(
                        fileName: 'Invoice_ZP-1001.png',
                        title: 'Artisan Coffee',
                        price: '12.50 ADA',
                        payload: 'zeropay://pay?address=addr1q8a72b100641de406d824855a782b13fa92c3ff&amount=12.50&symbol=ADA&title=CryptoBrews%20Artisan%20Coffee&escrowId=ZP-1001',
                      ),
                      _buildGalleryItem(
                        fileName: 'Corrupted_Hash.png',
                        title: 'Corrupted link test',
                        price: 'ERR_PAYLOAD',
                        payload: 'zeropay://invalid-payload-data',
                        isCorrupt: true,
                      ),
                      _buildGalleryItem(
                        fileName: 'Blurry_Photo.jpg',
                        title: 'Blurry matrix test',
                        price: 'ERR_UNREADABLE',
                        payload: 'zeropay://unreadable-matrix-corruption',
                        isCorrupt: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGalleryItem({
    required String fileName,
    required String title,
    required String price,
    required String payload,
    bool isCorrupt = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // Pop gallery dialog
        _startProcessingScan(payload);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.qr_code, color: isCorrupt ? AppColors.outlineVariant : AppColors.primary, size: 48),
                      if (isCorrupt)
                        Positioned(
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(6)),
                            child: const Text('CORRUPT', style: TextStyle(color: AppColors.onErrorContainer, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startProcessingScan(String payload) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black.withOpacity(0.92),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                ),
                const SizedBox(height: 24),
                const Text(
                  'PROCESSING QR MATRIX',
                  style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Extracting payload parameters and validating signature...',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.pop(context); // Pop processing overlay
        _processQRPayload(payload);
      }
    });
  }

  void _processQRPayload(String payload) {
    if (payload.startsWith('zeropay://unreadable-matrix-corruption')) {
      _showDecodingErrorDialog('Unreadable QR image. The QR code is too blurry or corrupted. Please try again with a clearer image.');
      return;
    }

    if (!payload.startsWith('zeropay://pay')) {
      _showDecodingErrorDialog('Invalid QR payload. This QR code does not contain a valid ZeroPay payment link.');
      return;
    }

    try {
      final uri = Uri.parse(payload);
      final address = uri.queryParameters['address'];
      final amount = uri.queryParameters['amount'];
      final symbol = uri.queryParameters['symbol'] ?? 'ADA';
      final title = uri.queryParameters['title'];
      final escrowId = uri.queryParameters['escrowId'];
      final merchantId = uri.queryParameters['merchantId'];
      final merchantName = uri.queryParameters['merchantName'];

      if (address == null || address.isEmpty || amount == null || amount.isEmpty) {
        _showDecodingErrorDialog('Invalid QR payload. Recipient address and amount are required fields.');
        return;
      }

      setState(() {
        _addressController.text = address;
        _amount = amount;
        _selectedSymbol = symbol.toUpperCase();
        _scannedTitle = title;
        _scannedEscrowId = escrowId;
        _scannedMerchantId = merchantId;
        _scannedMerchantName = merchantName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_scannedEscrowId != null ? 'Secure Escrow Invoice loaded.' : 'Direct payment information loaded.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      _showDecodingErrorDialog('Decoding failed. Unable to parse payment parameters: ${e.toString()}');
    }
  }

  void _showDecodingErrorDialog(String errorMsg) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surfaceContainerHigh,
          title: Row(
            children: const [
              Icon(Icons.error_outline, color: AppColors.error),
              SizedBox(width: 10),
              Text('QR Scan Error', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            errorMsg,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInvoiceDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
      ],
    );
  }

  void _handleSend() async {
    final address = _addressController.text.trim();
    final parsedAmount = double.tryParse(_amount) ?? 0.0;

    if (address.isEmpty || parsedAmount <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid address and amount.')),
      );
      return;
    }

    // Biometric confirmation simulation before releasing funds
    final authState = ref.read(authProvider);
    if (authState.user?.biometricsEnabled ?? true) {
      // Simulate biometric validation screen challenge
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint, color: AppColors.primary, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Confirm Signature',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Confirm transaction of $parsedAmount $_selectedSymbol using FaceID secure signature.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Verify'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (confirmed != true) return;
    }

    // Call repository to subtract balance and generate local ledger activity
    final repo = ref.read(zeroPayRepositoryProvider);

    // Show beautiful loading state HUD
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Broadcasting transaction...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      await repo.sendTokens(address, parsedAmount, _selectedSymbol);
      
      // Update Escrow state locally if it was funded via QR code
      if (_scannedEscrowId != null) {
        final cache = ref.read(secureCacheProvider);
        
        // Update Customer Escrows
        try {
          final cachedList = await cache.getCachedList('escrows_customer');
          if (cachedList != null) {
            final escrows = cachedList.map((e) => Escrow.fromJson(e)).toList();
            final index = escrows.indexWhere((e) => e.id == _scannedEscrowId);
            if (index != -1) {
              final old = escrows[index];
              escrows[index] = Escrow(
                id: old.id,
                title: old.title,
                counterpartyAddress: old.counterpartyAddress,
                counterpartyName: old.counterpartyName,
                totalValue: old.totalValue,
                assetSymbol: old.assetSymbol,
                status: 'Locked', // Fund it!
                milestones: old.milestones,
                contractAddress: old.contractAddress,
                chainName: old.chainName,
                createdAt: old.createdAt,
              );
            } else {
              escrows.add(Escrow(
                id: _scannedEscrowId!,
                title: _scannedTitle ?? 'Artisan Coffee Goods',
                counterpartyAddress: address,
                counterpartyName: _scannedMerchantName ?? 'CryptoBrews Coffee',
                totalValue: parsedAmount,
                assetSymbol: _selectedSymbol,
                status: 'Locked',
                milestones: [
                  Milestone(id: 'ms_${_scannedEscrowId}_1', title: 'Order Fulfillment', description: 'Deliver goods to customer.', amount: parsedAmount, status: 'In Progress'),
                ],
                contractAddress: 'addr_escrow_${_scannedEscrowId}_lock',
                chainName: _selectedSymbol == 'ADA' ? 'Cardano Mainnet' : 'Arbitrum One',
                createdAt: DateTime.now(),
              ));
            }
            await cache.cacheList('escrows_customer', escrows.map((e) => e.toJson()).toList());
          }
        } catch (_) {}

        // Update Merchant Escrows
        try {
          final cachedList = await cache.getCachedList('escrows_merchant');
          if (cachedList != null) {
            final escrows = cachedList.map((e) => Escrow.fromJson(e)).toList();
            final index = escrows.indexWhere((e) => e.id == _scannedEscrowId);
            if (index != -1) {
              final old = escrows[index];
              escrows[index] = Escrow(
                id: old.id,
                title: old.title,
                counterpartyAddress: old.counterpartyAddress,
                counterpartyName: old.counterpartyName,
                totalValue: old.totalValue,
                assetSymbol: old.assetSymbol,
                status: 'Locked', // Fund it!
                milestones: old.milestones,
                contractAddress: old.contractAddress,
                chainName: old.chainName,
                createdAt: old.createdAt,
              );
            } else {
              escrows.add(Escrow(
                id: _scannedEscrowId!,
                title: _scannedTitle ?? 'Artisan Coffee Goods',
                counterpartyAddress: address,
                counterpartyName: _scannedMerchantName ?? 'CryptoBrews Coffee',
                totalValue: parsedAmount,
                assetSymbol: _selectedSymbol,
                status: 'Locked',
                milestones: [
                  Milestone(id: 'ms_${_scannedEscrowId}_1', title: 'Order Fulfillment', description: 'Deliver goods to customer.', amount: parsedAmount, status: 'In Progress'),
                ],
                contractAddress: 'addr_escrow_${_scannedEscrowId}_lock',
                chainName: _selectedSymbol == 'ADA' ? 'Cardano Mainnet' : 'Arbitrum One',
                createdAt: DateTime.now(),
              ));
            }
            await cache.cacheList('escrows_merchant', escrows.map((e) => e.toJson()).toList());
          }
        } catch (_) {}
      }

      if (mounted) {
        Navigator.of(context).pop(); // pop loading dialog
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // pop loading dialog
      }
      rethrow;
    }

    if (mounted) {
      // Show Success Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SuccessDialog(
          title: 'Transaction Confirmed',
          description: 'Successfully sent $parsedAmount $_selectedSymbol on Cardano ledger.\nTxHash: 0x9d4a...1553',
          onConfirm: () {
            context.go('/customer/home');
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: const Text('Send Assets', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                children: [
                  const SizedBox(height: 12),
                  // Recipient Address Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addressController,
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                            decoration: const InputDecoration(
                              hintText: 'Enter recipient wallet address...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                          onPressed: _handleScanQR,
                        ),
                      ],
                    ),
                  ),
                  
                  if (_scannedTitle != null || _scannedEscrowId != null || _scannedMerchantName != null) ...[
                    const SizedBox(height: 16),
                    BentoCard(
                      color: AppColors.primary.withOpacity(0.04),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.receipt_long, color: AppColors.primary, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'TRANSACTION INVOICE DETAILS',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.0),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          if (_scannedMerchantName != null) ...[
                            _buildInvoiceDetailRow('Merchant', _scannedMerchantName!),
                            const SizedBox(height: 8),
                          ],
                          if (_scannedTitle != null) ...[
                            _buildInvoiceDetailRow('Product / Invoice', _scannedTitle!),
                            const SizedBox(height: 8),
                          ],
                          if (_scannedEscrowId != null) ...[
                            _buildInvoiceDetailRow('Escrow Reference', _scannedEscrowId!),
                            const SizedBox(height: 8),
                          ],
                          _buildInvoiceDetailRow('Security Lock', 'Programmable smart escrow protection'),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Amount Display
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'ENTER AMOUNT',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.outline, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _amount.isEmpty ? '0.00' : _amount,
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _amount.isEmpty ? AppColors.outlineVariant : AppColors.onSurface,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            // Token Selector dropdown
                            DropdownButton<String>(
                              value: _selectedSymbol,
                              underline: const SizedBox(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedSymbol = val;
                                  });
                                }
                              },
                              items: ['ADA', 'USDC', 'ETH'].map((sym) {
                                return DropdownMenuItem<String>(value: sym, child: Text(sym));
                              }).toList(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Fee details
                  BentoCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Network Gas Fee Estimate', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                        Text(
                          _selectedSymbol == 'ADA' ? '0.17 ADA' : '1.50 USDC',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Keypad & Send CTA
            Container(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  _buildNumericKeypad(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        text: 'Send Asset Signature',
                        onPressed: _handleSend,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumericKeypad() {
    Widget buildBtn(String label, {VoidCallback? onTap, IconData? icon}) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, color: AppColors.onSurface)
                : Text(
                    label,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            buildBtn('1', onTap: () => _handleDigitPressed('1')),
            buildBtn('2', onTap: () => _handleDigitPressed('2')),
            buildBtn('3', onTap: () => _handleDigitPressed('3')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            buildBtn('4', onTap: () => _handleDigitPressed('4')),
            buildBtn('5', onTap: () => _handleDigitPressed('5')),
            buildBtn('6', onTap: () => _handleDigitPressed('6')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            buildBtn('7', onTap: () => _handleDigitPressed('7')),
            buildBtn('8', onTap: () => _handleDigitPressed('8')),
            buildBtn('9', onTap: () => _handleDigitPressed('9')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            buildBtn('.', onTap: () => _handleDigitPressed('.')),
            buildBtn('0', onTap: () => _handleDigitPressed('0')),
            buildBtn('', icon: Icons.backspace_outlined, onTap: _handleBackspace),
          ],
        ),
      ],
    );
  }
}
