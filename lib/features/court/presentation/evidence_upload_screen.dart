import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';

class SimulatedFile {
  final String name;
  final String size;
  final String hash;
  final String ipfsCid;
  final DateTime timestamp;
  final String status; // 'Pending', 'Anchoring', 'Anchored'
  final String blockNumber;

  SimulatedFile({
    required this.name,
    required this.size,
    required this.hash,
    required this.ipfsCid,
    required this.timestamp,
    required this.status,
    required this.blockNumber,
  });

  SimulatedFile copyWith({
    String? status,
    String? blockNumber,
  }) {
    return SimulatedFile(
      name: name,
      size: size,
      hash: hash,
      ipfsCid: ipfsCid,
      timestamp: timestamp,
      status: status ?? this.status,
      blockNumber: blockNumber ?? this.blockNumber,
    );
  }
}

class EvidenceUploadScreen extends ConsumerStatefulWidget {
  const EvidenceUploadScreen({super.key});

  @override
  ConsumerState<EvidenceUploadScreen> createState() => _EvidenceUploadScreenState();
}

class _EvidenceUploadScreenState extends ConsumerState<EvidenceUploadScreen> {
  final List<SimulatedFile> _evidenceLedger = [];
  bool _isUploading = false;
  bool _isSubmitting = false;
  String _uploadStatusText = '';

  @override
  void initState() {
    super.initState();
    // Default mock database evidence anchored on chain
    _evidenceLedger.addAll([
      SimulatedFile(
        name: 'USPS_Express_Freight_Manifest.pdf',
        size: '1.2 MB',
        hash: 'SHA256: 2a8b7c55...4490f',
        ipfsCid: 'ipfs://QmXoyp...5941',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        status: 'Anchored',
        blockNumber: '#1938202',
      ),
      SimulatedFile(
        name: 'Cardano_Escrow_Deploy_Parameters.json',
        size: '42 KB',
        hash: 'SHA256: 9e8c7a6b...2110c',
        ipfsCid: 'ipfs://QmYpXo...1842',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        status: 'Anchored',
        blockNumber: '#1938522',
      ),
    ]);
  }

  void _simulateFileSelection(String name, String size) {
    if (_isUploading) return;
    setState(() {
      _isUploading = true;
      _uploadStatusText = 'Hashing file metadata...';
    });

    Timer(const Duration(seconds: 1), () {
      final timestamp = DateTime.now();
      final ms = timestamp.millisecondsSinceEpoch;
      final fileHash = 'SHA256: ${ms.toString().substring(4)}ab...${name.hashCode.toString().substring(0, 4)}f';
      final cid = 'ipfs://QmTz${ms.toString().substring(5)}...${name.length}2';

      setState(() {
        _evidenceLedger.add(
          SimulatedFile(
            name: name,
            size: size,
            hash: fileHash,
            ipfsCid: cid,
            timestamp: timestamp,
            status: 'Pending',
            blockNumber: '--',
          ),
        );
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" uploaded to draft evidence queue.')),
      );
    });
  }

  Future<void> _anchorEvidenceToLedger() async {
    final pendingCount = _evidenceLedger.where((e) => e.status == 'Pending').length;
    if (pendingCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending documents to anchor. Select or upload files first.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadStatusText = 'Generating IPFS multi-hashes...';
    });

    // Step-by-step terminal anchoring sequence
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() => _uploadStatusText = 'Broadcasting content identifiers to smart contract...');
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() => _uploadStatusText = 'Anchoring transaction parameters to Cardano validator block...');

    // Call mock repository submit evidence logic to simulate status change
    final repo = ref.read(zeroPayRepositoryProvider);
    await repo.submitEvidence('DS-9281', 'Anchoring $pendingCount evidence documents.');

    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      for (int i = 0; i < _evidenceLedger.length; i++) {
        if (_evidenceLedger[i].status == 'Pending') {
          _evidenceLedger[i] = _evidenceLedger[i].copyWith(
            status: 'Anchored',
            blockNumber: '#1939104',
          );
        }
      }
      _isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All pending evidence successfully anchored to the ledger.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingFiles = _evidenceLedger.where((e) => e.status == 'Pending').toList();
    final anchoredFiles = _evidenceLedger.where((e) => e.status == 'Anchored').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Evidence Management Center',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () => context.canPop() ? context.pop() : context.go('/court/dashboard'),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIntroCard(),
                  const SizedBox(height: 16),
                  _buildUploadZone(),
                  const SizedBox(height: 20),
                  if (pendingFiles.isNotEmpty) ...[
                    _buildPendingSection(pendingFiles),
                    const SizedBox(height: 20),
                  ],
                  _buildChainOfCustodyLedger(anchoredFiles),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          if (_isSubmitting || _isUploading) _buildLoadingOverlay(),
        ],
      ),
      floatingActionButton: pendingFiles.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: _anchorEvidenceToLedger,
              icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
              label: const Text('Anchor & Sign Evidence', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chain of Custody Protection',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
          ),
          SizedBox(height: 6),
          Text(
            'All submitted evidence files are hashed locally, stored on IPFS, and permanently anchored on-chain with cryptographic timestamps. This guarantees evidence tamper-proofing for consensus jurors.',
            style: TextStyle(fontSize: 11, height: 1.3, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadZone() {
    return BentoCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      onTap: () {
        // Mock file selection trigger options
        _showFilePickerSelection();
      },
      child: Column(
        children: [
          Icon(Icons.upload_file_outlined, size: 48, color: AppColors.primary.withValues(alpha: 0.8)),
          const SizedBox(height: 14),
          const Text(
            'Select Dispute Evidence Files',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload Cargo Manifests, Courier Slips, Invoices, or Chat Logs.',
            style: TextStyle(color: AppColors.outline, fontSize: 10.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Browse Files',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilePickerSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassPanel(
        radius: 24,
        backgroundColor: AppColors.surfaceContainerLowest.withValues(alpha: 0.98),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Attach Supporting Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              _buildPickerOption('NES_Consoles_Packaging_Photo.jpg', '2.4 MB', Icons.photo_outlined),
              _buildPickerOption('USPS_Carrier_Receipt_Official.pdf', '480 KB', Icons.description_outlined),
              _buildPickerOption('Customs_Export_Declaration_Delay.pdf', '1.8 MB', Icons.gavel_outlined),
              _buildPickerOption('Counterparty_Email_Convo.txt', '12 KB', Icons.text_snippet_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption(String name, String size, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
      subtitle: Text(size, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
      onTap: () {
        Navigator.of(context).pop();
        _simulateFileSelection(name, size);
      },
    );
  }

  Widget _buildPendingSection(List<SimulatedFile> files) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pending Anchoring (Draft Queue)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: BentoCard(
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, color: Colors.orange, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(file.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('IPFS CID: ${file.ipfsCid.substring(0, 16)}...', style: const TextStyle(fontSize: 9, color: AppColors.outline, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
                      onPressed: () {
                        setState(() {
                          _evidenceLedger.remove(file);
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildChainOfCustodyLedger(List<SimulatedFile> files) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Permanent Chain-of-Custody Ledger',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        BentoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: AppColors.surfaceContainerLow,
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('DOCUMENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.outline))),
                    Expanded(flex: 2, child: Text('IPFS / BLOCK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.outline))),
                    Expanded(flex: 2, child: Text('TIMESTAMP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.outline), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              if (files.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No permanently anchored documents found.', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.2))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(file.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(file.hash, style: const TextStyle(fontSize: 8, color: AppColors.outline, fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(file.blockNumber, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.tertiary)),
                                const SizedBox(height: 2),
                                Text('${file.ipfsCid.substring(7, 18)}...', style: const TextStyle(fontSize: 8, color: AppColors.outline, fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${file.timestamp.hour}:${file.timestamp.minute.toString().padLeft(2, '0')}:${file.timestamp.second.toString().padLeft(2, '0')}\n'
                              '${file.timestamp.day}/${file.timestamp.month}/${file.timestamp.year}',
                              style: const TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: BentoCard(
          radius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
              const SizedBox(height: 16),
              Text(
                _uploadStatusText.isEmpty ? 'Processing File...' : _uploadStatusText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
