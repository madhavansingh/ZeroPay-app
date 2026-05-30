import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/providers/global_providers.dart';

class ChatThread {
  final String id;
  final String senderName;
  final String lastMessage;
  final String timestamp;
  final bool isUnread;
  final String contractReference;
  final String status;

  ChatThread({
    required this.id,
    required this.senderName,
    required this.lastMessage,
    required this.timestamp,
    required this.isUnread,
    required this.contractReference,
    required this.status,
  });
}

class CommerceChatScreen extends ConsumerStatefulWidget {
  final String? preselectedThreadId;
  const CommerceChatScreen({this.preselectedThreadId, super.key});

  @override
  ConsumerState<CommerceChatScreen> createState() => _CommerceChatScreenState();
}

class _CommerceChatScreenState extends ConsumerState<CommerceChatScreen> with TickerProviderStateMixin {
  ChatThread? _selectedThread;
  final List<ChatMessage> _messages = [];
  final TextEditingController _msgController = TextEditingController();
  final List<ChatThread> _threads = [];
  bool _initialized = false;

  // Animation controller for fund lock success overlay
  late AnimationController _lockAnimationController;
  late Animation<double> _lockScaleAnimation;
  bool _showLockAnimation = false;

  @override
  void initState() {
    super.initState();
    _lockAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _lockScaleAnimation = CurvedAnimation(
      parent: _lockAnimationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _msgController.dispose();
    _lockAnimationController.dispose();
    super.dispose();
  }

  void _initializeThreads(DemoDataset dataset) {
    if (_initialized) return;
    _threads.clear();
    _messages.clear();

    switch (dataset) {
      case DemoDataset.freelanceProject:
        _threads.add(ChatThread(
          id: 'th_f',
          senderName: 'DevCo Solutions (Lead Dev)',
          lastMessage: 'I completed the onboarding UI. Code committed to Github.',
          timestamp: '10m ago',
          isUnread: true,
          contractReference: 'ZP-FREL-1',
          status: 'Locked',
        ));
        _messages.addAll([
          ChatMessage(id: 'msg_f_10', text: 'Hey Sarah! We just compiled the baseline project scaffolding on Cardano devnet.', timestamp: DateTime.now().subtract(const Duration(days: 2)), sender: 'counterparty', isAIHelper: false),
          ChatMessage(id: 'msg_f_11', text: 'Looks great. I verified the pre-funded lock is registered on-chain.', timestamp: DateTime.now().subtract(const Duration(days: 2)), sender: 'user', isAIHelper: false),
          ChatMessage(id: 'msg_f_12', text: 'Onboarding UI development is completed. Can you review and release Milestone 1?', timestamp: DateTime.now().subtract(const Duration(minutes: 10)), sender: 'counterparty', isAIHelper: false),
        ]);
        break;
      case DemoDataset.marketplacePurchase:
        _threads.add(ChatThread(
          id: 'th_m',
          senderName: 'Retro Gaming Source (Seller)',
          lastMessage: 'Vintage NES console package has been shipped. Carrier updated.',
          timestamp: '1h ago',
          isUnread: false,
          contractReference: 'ZP-MKT-BUY',
          status: 'Active',
        ));
        _messages.addAll([
          ChatMessage(id: 'msg_m_10', text: 'Thank you for locking the ADA! I am preparing the NES shipment.', timestamp: DateTime.now().subtract(const Duration(days: 1)), sender: 'counterparty', isAIHelper: false),
          ChatMessage(id: 'msg_m_11', text: 'Tracking updated. Package picked up by courier.', timestamp: DateTime.now().subtract(const Duration(hours: 1)), sender: 'counterparty', isAIHelper: false),
        ]);
        break;
      default:
        _threads.addAll([
          ChatThread(
            id: 'th_default_1',
            senderName: 'DevCo Solutions',
            lastMessage: 'Onboarding UI development completed.',
            timestamp: '10m ago',
            isUnread: true,
            contractReference: 'ZP-FREL-1',
            status: 'Locked',
          ),
          ChatThread(
            id: 'th_default_2',
            senderName: 'Registrar Domain Agents',
            lastMessage: 'Domain transfer auth code verified.',
            timestamp: 'Yesterday',
            isUnread: false,
            contractReference: 'ZP-DOM-9',
            status: 'Confirming',
          ),
        ]);
        _messages.addAll([
          ChatMessage(id: 'msg_def_1', text: 'Welcome to ZeroPay Chat. Link your contract or lock invoices.', timestamp: DateTime.now().subtract(const Duration(hours: 12)), sender: 'ai', isAIHelper: true),
        ]);
    }

    if (widget.preselectedThreadId != null) {
      final index = _threads.indexWhere((element) => element.id == widget.preselectedThreadId);
      if (index != -1) {
        _selectedThread = _threads[index];
      }
    } else if (_threads.isNotEmpty && _selectedThread == null) {
      _selectedThread = _threads.first;
    }

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final dataset = ref.watch(demoDatasetProvider);
    _initializeThreads(dataset);

    ref.listen(demoDatasetProvider, (previous, next) {
      setState(() {
        _initialized = false;
        _selectedThread = null;
        _initializeThreads(next);
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _selectedThread == null ? 'Commerce Discussions' : _selectedThread!.senderName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () {
            if (_selectedThread != null && widget.preselectedThreadId == null) {
              setState(() => _selectedThread = null);
            } else {
              if (context.canPop()) {
                context.pop();
              } else {
                final role = ref.read(authProvider).currentRole;
                context.go(role == 'merchant' ? '/merchant/dashboard' : '/customer/home');
              }
            }
          },
        ),
      ),
      body: Stack(
        children: [
          _selectedThread == null
              ? _buildThreadsList()
              : _buildConversationView(dataset),
          if (_showLockAnimation) _buildLockAnimationOverlay(),
        ],
      ),
    );
  }

  Widget _buildThreadsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _threads.length,
      itemBuilder: (context, index) {
        final thread = _threads[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: BentoCard(
            onTap: () => setState(() {
              _selectedThread = thread;
              _initialized = false; // reload messages
            }),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  child: Text(thread.senderName[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(thread.senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(thread.timestamp, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        thread.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: thread.isUnread ? AppColors.onSurface : AppColors.onSurfaceVariant,
                          fontWeight: thread.isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              'Contract: ${thread.contractReference}',
                              style: const TextStyle(fontSize: 8, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.tertiary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              thread.status.toUpperCase(),
                              style: const TextStyle(fontSize: 8, color: AppColors.tertiary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
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

  Widget _buildConversationView(DemoDataset dataset) {
    return Column(
      children: [
        // Shared Escrow Status Alert header
        _buildSharedContextBar(),

        // Chat messages timeline
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Chat message history
              ..._messages.map((msg) => _buildChatMessageBubble(msg)),

              // Dynamic Inline Workflows based on active demo context
              if (dataset == DemoDataset.freelanceProject) ...[
                const SizedBox(height: 16),
                _buildInvoiceInlineCard('ZP-FREL-1', 1500.00, 'USDC'),
                const SizedBox(height: 12),
                _buildMilestonesTimelineCard('ZP-FREL-1', 'USDC'),
                const SizedBox(height: 12),
                _buildAiSuggestionPanel('DevCo Solutions submitted Figma designs. Ledger audits confirm git commit branch synced. Recommend unlocking milestone.'),
              ],
              if (dataset == DemoDataset.marketplacePurchase) ...[
                const SizedBox(height: 16),
                _buildFulfillmentDeliveryCard('ZP-MKT-BUY', 'Cardano ADA'),
              ],
            ],
          ),
        ),

        // Message input bar
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildSharedContextBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.tertiary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Linked Escrow: ${_selectedThread!.contractReference}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 26),
              side: const BorderSide(color: AppColors.primary),
            ),
            onPressed: () {
              // Direct route to contract analysis
              context.push('/ai/contract-analysis');
            },
            child: const Text('Analyze Terms', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageBubble(ChatMessage msg) {
    final isMe = msg.sender == 'user';
    final isAI = msg.sender == 'ai';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary
              : isAI
                  ? AppColors.secondary.withOpacity(0.06)
                  : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          border: isAI
              ? Border.all(color: AppColors.secondary.withOpacity(0.2))
              : isMe
                  ? null
                  : Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAI) ...[
              Row(
                children: const [
                  Icon(Icons.auto_awesome, size: 12, color: AppColors.secondary),
                  SizedBox(width: 6),
                  Text('ZeroPay AI Assistant Prompt', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 12.5,
                color: isMe ? Colors.white : AppColors.onSurface,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceInlineCard(String ref, double amount, String symbol) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('INCOMING INVOICE REQUEST', style: TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                child: const Text('Pending funding', style: TextStyle(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invoice amount', style: TextStyle(fontSize: 9, color: AppColors.outline)),
                  Text('\$${amount.toStringAsFixed(2)} $symbol', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              // Action lock button
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () => _triggerFundLockAnimation(),
                icon: const Icon(Icons.lock, size: 12, color: Colors.white),
                label: const Text('Fund & Lock Escrow', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesTimelineCard(String ref, String symbol) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONTRACT MILESTONES REVIEW', style: TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildMilestoneRow('Design Concept Wireframes', 'Released', 1000.0, symbol),
          _buildMilestoneRow('Screens Front-end implementation', 'In Progress', 1500.0, symbol),
          _buildMilestoneRow('API Sync Endpoints integration', 'Pending', 500.0, symbol),
        ],
      ),
    );
  }

  Widget _buildMilestoneRow(String title, String status, double value, String symbol) {
    Color col = AppColors.outline;
    if (status == 'Released') col = AppColors.tertiary;
    if (status == 'In Progress') col = AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                status == 'Released' ? Icons.check_circle : status == 'In Progress' ? Icons.pending : Icons.radio_button_unchecked,
                size: 14,
                color: col,
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
          Text('\$${value.toStringAsFixed(0)} $symbol', style: TextStyle(fontSize: 11, color: col, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAiSuggestionPanel(String text) {
    return BentoCard(
      border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      color: AppColors.secondary.withOpacity(0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: AppColors.secondary, size: 14),
              SizedBox(width: 6),
              Text('ZeroPay AI Assistant Suggestion', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildFulfillmentDeliveryCard(String ref, String asset) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('COURIER SHIPMENT TRACKING', style: TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.tertiary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                child: const Text('DELIVERED', style: TextStyle(fontSize: 8, color: AppColors.tertiary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Carrier: USPS Express', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const Text('Tracking Number: USPS-NES-9801', style: TextStyle(fontSize: 10, color: AppColors.outline)),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Confirm milestone delivery receipt to release funds.', style: TextStyle(fontSize: 10, color: AppColors.outline)),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.tertiary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                onPressed: () {
                  // Trigger release success animation
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verification processed. Payout broadcasted to Cardano ledger.')),
                  );
                },
                child: const Text('Confirm Receipt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: AppColors.outline),
            onPressed: () {
              // Direct route to evidence upload
              context.push('/court/evidence-upload');
            },
          ),
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: 'Discuss terms, request price audits...',
                hintStyle: const TextStyle(fontSize: 13),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: AppColors.primary),
            onPressed: () {
              if (_msgController.text.isNotEmpty) {
                setState(() {
                  _messages.add(ChatMessage(
                    id: 'custom_msg_${DateTime.now().millisecondsSinceEpoch}',
                    text: _msgController.text,
                    timestamp: DateTime.now(),
                    sender: 'user',
                    isAIHelper: false,
                  ));
                });
                _msgController.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  // Task 11: Escrow Locked Animation Overlay
  void _triggerFundLockAnimation() {
    setState(() => _showLockAnimation = true);
    _lockAnimationController.reset();
    _lockAnimationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 1)).then((_) {
        if (mounted) {
          setState(() => _showLockAnimation = false);
          // Show Success dialog or SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Escrow Funded successfully. 3000.00 USDC locked.')),
          );
        }
      });
    });
  }

  Widget _buildLockAnimationOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: ScaleTransition(
          scale: _lockScaleAnimation,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock, size: 72, color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'Funds Locked Locked',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: 6),
                Text(
                  'Broadcasted transaction to Arbitrum network.',
                  style: TextStyle(color: AppColors.outline, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
