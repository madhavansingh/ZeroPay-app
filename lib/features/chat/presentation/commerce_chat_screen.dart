import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/domain/models.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/data/repository.dart';

class CommerceChatScreen extends ConsumerStatefulWidget {
  final String? preselectedThreadId;
  final String? preselectedInvoiceId;

  const CommerceChatScreen({
    this.preselectedThreadId,
    this.preselectedInvoiceId,
    super.key,
  });

  @override
  ConsumerState<CommerceChatScreen> createState() => _CommerceChatScreenState();
}

class _CommerceChatScreenState extends ConsumerState<CommerceChatScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _selectedRoom;
  final List<ChatMessage> _messages = [];
  final TextEditingController _msgController = TextEditingController();
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoadingRooms = false;
  bool _isLoadingMessages = false;
  String? _roomsError;
  String? _messagesError;
  Timer? _pollingTimer;
  Escrow? _linkedEscrow;

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

    _fetchRooms();

    if (widget.preselectedInvoiceId != null) {
      _resolvePreselectedInvoice();
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _lockAnimationController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRooms() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRooms = true;
      _roomsError = null;
    });

    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      final rooms = await repo.getChatRooms();
      if (!mounted) return;

      setState(() {
        _rooms = rooms;
        _isLoadingRooms = false;
      });

      // If we have a preselected thread ID, look it up and select it
      if (widget.preselectedThreadId != null && _selectedRoom == null) {
        final idx = rooms.indexWhere((r) => r['roomId'] == widget.preselectedThreadId);
        if (idx != -1) {
          _selectRoom(rooms[idx]);
        }
      }
    } catch (e) {
      debugPrint('[CommerceChatScreen] _fetchRooms error: $e');
      if (!mounted) return;
      setState(() {
        _roomsError = 'Failed to load chat rooms: $e';
        _isLoadingRooms = false;
      });
    }
  }

  Future<void> _resolvePreselectedInvoice() async {
    final invoiceId = widget.preselectedInvoiceId;
    if (invoiceId == null) return;

    setState(() {
      _isLoadingMessages = true;
      _messagesError = null;
    });

    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      final escrow = await repo.getEscrowDetails(invoiceId);
      if (!mounted) return;

      setState(() {
        _linkedEscrow = escrow;
      });

      if (escrow.chatRoomId != null && escrow.chatRoomId!.isNotEmpty) {
        final mockRoom = {
          'roomId': escrow.chatRoomId,
          'shopName': escrow.counterpartyName,
        };
        _selectRoom(mockRoom);
      } else {
        // Chat room doesn't exist yet, provision one!
        final merchantStringId = escrow.merchantStringId;
        if (merchantStringId == null || merchantStringId.isEmpty) {
          throw Exception('No merchant ID associated with this invoice to start a chat.');
        }

        final newRoom = await repo.createChatRoom(merchantStringId);
        if (!mounted) return;

        final roomId = newRoom['roomId'] as String;
        final mockRoom = {
          'roomId': roomId,
          'shopName': escrow.counterpartyName,
        };

        _selectRoom(mockRoom);
        // Refresh rooms list so the new room appears
        _fetchRooms();
      }
    } catch (e) {
      debugPrint('[CommerceChatScreen] _resolvePreselectedInvoice error: $e');
      if (!mounted) return;
      setState(() {
        _messagesError = 'Failed to load/provision chat for invoice: $e';
        _isLoadingMessages = false;
      });
    }
  }

  void _selectRoom(Map<String, dynamic> room) {
    setState(() {
      _selectedRoom = room;
      _messages.clear();
    });

    final roomId = room['roomId'] as String;
    _fetchMessages(roomId);
    _startPolling(roomId);
  }

  void _startPolling(String roomId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchMessages(roomId, isSilent: true);
    });
  }

  Future<void> _fetchMessages(String roomId, {bool isSilent = false}) async {
    if (!mounted) return;
    if (!isSilent) {
      setState(() {
        _isLoadingMessages = true;
        _messagesError = null;
      });
    }

    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      final details = await repo.getChatRoomDetails(roomId);
      if (!mounted) return;

      final messagesList = details['messages'] as List?;
      final currentUserId = ref.read(authProvider).user?.uid;

      final List<ChatMessage> newMessages = [];
      if (messagesList != null) {
        for (final msg in messagesList) {
          final m = Map<String, dynamic>.from(msg as Map);
          final senderId = m['senderId'] as String?;

          String sender;
          if (senderId == currentUserId) {
            sender = 'user';
          } else if (senderId == 'zeropay-ai-agent') {
            sender = 'ai';
          } else {
            sender = 'counterparty';
          }

          final payload = m['payload'] as Map?;
          final text = payload != null ? (payload['text'] as String? ?? '') : '';
          final timestampVal = m['timestamp'];
          DateTime timestamp = DateTime.now();
          if (timestampVal is int) {
            timestamp = DateTime.fromMillisecondsSinceEpoch(timestampVal);
          } else if (timestampVal is String) {
            timestamp = DateTime.parse(timestampVal);
          }

          newMessages.add(ChatMessage(
            id: m['id'] as String? ?? m['key'] as String? ?? 'msg_${timestamp.millisecondsSinceEpoch}',
            text: text,
            timestamp: timestamp,
            sender: sender,
            isAIHelper: sender == 'ai',
          ),);
        }
      }

      setState(() {
        _messages.clear();
        _messages.addAll(newMessages);
        _isLoadingMessages = false;
      });
    } catch (e) {
      debugPrint('[CommerceChatScreen] _fetchMessages error: $e');
      if (!mounted) return;
      if (!isSilent) {
        setState(() {
          _messagesError = 'Failed to load messages: $e';
          _isLoadingMessages = false;
        });
      }
    }
  }

  String _determineInvoiceId(Escrow? activeEscrow) {
    if (widget.preselectedInvoiceId != null) return widget.preselectedInvoiceId!;
    if (activeEscrow != null) return activeEscrow.id;
    // Fallback to first available escrow in the user's role
    final role = ref.read(authProvider).currentRole;
    final provider = role == 'merchant' ? merchantEscrowsProvider : customerEscrowsProvider;
    final escrowsVal = ref.read(provider).value;
    if (escrowsVal != null && escrowsVal.isNotEmpty) {
      return escrowsVal.first.id;
    }
    return 'INV-FALLBACK';
  }

  Future<void> _sendMessage(String text, Escrow? activeEscrow) async {
    if (text.trim().isEmpty || _selectedRoom == null) return;

    final roomId = _selectedRoom!['roomId'] as String;
    final invoiceId = _determineInvoiceId(activeEscrow);
    final msgText = text.trim();

    _msgController.clear();

    // Optimistically append the customer message
    final tempId = 'custom_msg_${DateTime.now().millisecondsSinceEpoch}';
    final userMsg = ChatMessage(
      id: tempId,
      text: msgText,
      timestamp: DateTime.now(),
      sender: 'user',
      isAIHelper: false,
    );

    setState(() {
      _messages.add(userMsg);
    });

    try {
      final repo = ref.read(zeroPayRepositoryProvider);
      await repo.sendChatMessage(roomId, invoiceId, msgText);
      await _fetchMessages(roomId, isSilent: true);
    } catch (e) {
      debugPrint('[CommerceChatScreen] _sendMessage error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dateTime;
    if (timestamp is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      dateTime = DateTime.parse(timestamp);
    } else {
      return '';
    }

    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataset = ref.watch(scenarioProfileProvider);

    ref.listen(scenarioProfileProvider, (previous, next) {
      setState(() {
        _selectedRoom = null;
        _linkedEscrow = null;
        _messages.clear();
      });
      _fetchRooms();
    });

    final role = ref.watch(authProvider).currentRole;
    final escrowsAsync = ref.watch(role == 'merchant' ? merchantEscrowsProvider : customerEscrowsProvider);

    Escrow? activeEscrow = _linkedEscrow;
    if (_selectedRoom != null && activeEscrow == null) {
      final roomId = _selectedRoom!['roomId'] as String;
      escrowsAsync.whenData((escrows) {
        final idx = escrows.indexWhere((e) => e.chatRoomId == roomId);
        if (idx != -1) {
          activeEscrow = escrows[idx];
        }
      });
    }

    final shopName = _selectedRoom?['shopName'] as String? ?? 'Discussion';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _selectedRoom == null ? 'Commerce Discussions' : shopName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
          onPressed: () {
            if (_selectedRoom != null && widget.preselectedThreadId == null && widget.preselectedInvoiceId == null) {
              setState(() {
                _selectedRoom = null;
                _pollingTimer?.cancel();
              });
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
          _selectedRoom == null
              ? _buildRoomsList(escrowsAsync)
              : _buildConversationView(dataset, activeEscrow),
          if (_showLockAnimation) _buildLockAnimationOverlay(),
        ],
      ),
    );
  }

  Widget _buildRoomsList(AsyncValue<List<Escrow>> escrowsAsync) {
    if (_isLoadingRooms && _rooms.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_roomsError != null && _rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_roomsError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchRooms,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_rooms.isEmpty) {
      return const Center(
        child: Text(
          'No active discussions found.',
          style: TextStyle(color: AppColors.outline),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        final roomId = room['roomId'] as String? ?? '';
        final shopName = room['shopName'] as String? ?? 'Discussion';
        final lastMsgMap = room['lastMessage'] as Map?;
        final lastMessage = lastMsgMap != null ? (lastMsgMap['preview'] as String? ?? '') : 'No messages yet';
        final timestampVal = lastMsgMap != null ? lastMsgMap['timestamp'] : null;
        final timestampStr = _formatTime(timestampVal);
        final unreadCount = room['unreadCount'] as int? ?? 0;
        final isUnread = unreadCount > 0;

        Escrow? matchedEscrow;
        escrowsAsync.whenData((escrows) {
          final idx = escrows.indexWhere((e) => e.chatRoomId == roomId);
          if (idx != -1) {
            matchedEscrow = escrows[idx];
          }
        });

        final contractReference = matchedEscrow?.id ?? 'None';
        final status = matchedEscrow?.status ?? 'Active';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: BentoCard(
            onTap: () => _selectRoom(room),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  child: Text(
                    shopName.isNotEmpty ? shopName[0].toUpperCase() : 'C',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(timestampStr, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isUnread ? AppColors.onSurface : AppColors.onSurfaceVariant,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              'Contract: $contractReference',
                              style: const TextStyle(fontSize: 8, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.tertiary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              status.toUpperCase(),
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

  Widget _buildConversationView(ScenarioProfile dataset, Escrow? activeEscrow) {
    return Column(
      children: [
        // Shared Escrow Status Alert header
        _buildSharedContextBar(activeEscrow),

        // Chat messages timeline
        Expanded(
          child: _isLoadingMessages && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _messagesError != null && _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_messagesError!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => _fetchMessages(_selectedRoom!['roomId']),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        if (_messages.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: Text(
                                'No messages yet. Send a message to start negotiation.',
                                style: TextStyle(color: AppColors.outline, fontSize: 12),
                              ),
                            ),
                          ),
                        // Chat message history
                        ..._messages.map((msg) => _buildChatMessageBubble(msg)),

                        // Dynamic Inline Workflows based on active demo context
                        if (dataset == ScenarioProfile.freelanceProject) ...[
                          const SizedBox(height: 16),
                          _buildInvoiceInlineCard('ZP-FREL-1', 1500.00, 'USDC'),
                          const SizedBox(height: 12),
                          _buildMilestonesTimelineCard('ZP-FREL-1', 'USDC'),
                          const SizedBox(height: 12),
                          _buildAiSuggestionPanel('DevCo Solutions submitted Figma designs. Ledger audits confirm git commit branch synced. Recommend unlocking milestone.'),
                        ],
                        if (dataset == ScenarioProfile.marketplacePurchase) ...[
                          const SizedBox(height: 16),
                          _buildFulfillmentDeliveryCard('ZP-MKT-BUY', 'Cardano ADA'),
                        ],
                        // If we have a real activeEscrow, we can show its milestones dynamically
                        if (activeEscrow != null && dataset != ScenarioProfile.freelanceProject && dataset != ScenarioProfile.marketplacePurchase) ...[
                          const SizedBox(height: 16),
                          _buildRealEscrowCard(activeEscrow),
                        ],
                      ],
                    ),
        ),

        // Message input bar
        _buildMessageInput(activeEscrow),
      ],
    );
  }

  Widget _buildSharedContextBar(Escrow? activeEscrow) {
    final contractReference = activeEscrow?.id ?? 'None';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.tertiary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Linked Escrow: $contractReference',
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
                  ? AppColors.secondary.withValues(alpha: 0.06)
                  : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          border: isAI
              ? Border.all(color: AppColors.secondary.withValues(alpha: 0.2))
              : isMe
                  ? null
                  : Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAI) ...[
              const Row(
                children: [
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
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
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
      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      color: AppColors.secondary.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
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
                decoration: BoxDecoration(color: AppColors.tertiary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
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

  Widget _buildRealEscrowCard(Escrow escrow) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ACTIVE ESCROW: ${escrow.id}', style: const TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (escrow.status == 'Locked' || escrow.status == 'Active')
                      ? AppColors.tertiary.withValues(alpha: 0.08)
                      : Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  escrow.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    color: (escrow.status == 'Locked' || escrow.status == 'Active')
                        ? AppColors.tertiary
                        : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            escrow.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Total Value: \$${escrow.totalValue.toStringAsFixed(2)} ${escrow.assetSymbol}',
            style: const TextStyle(fontSize: 11, color: AppColors.outline),
          ),
          if (escrow.milestones.isNotEmpty) ...[
            const Divider(height: 20),
            const Text('MILESTONES', style: TextStyle(fontSize: 9, color: AppColors.outline, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...escrow.milestones.map((m) {
              Color col = AppColors.outline;
              if (m.status == 'Released' || m.status == 'Completed') col = AppColors.tertiary;
              if (m.status == 'In Progress' || m.status == 'Active') col = AppColors.primary;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          (m.status == 'Released' || m.status == 'Completed')
                              ? Icons.check_circle
                              : (m.status == 'In Progress' || m.status == 'Active')
                                  ? Icons.pending
                                  : Icons.radio_button_unchecked,
                          size: 14,
                          color: col,
                        ),
                        const SizedBox(width: 8),
                        Text(m.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Text(
                      '\$${m.amount.toStringAsFixed(2)} ${escrow.assetSymbol}',
                      style: TextStyle(fontSize: 11, color: col, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput(Escrow? activeEscrow) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: AppColors.outline),
            onPressed: () {
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
              onSubmitted: (_) {
                if (_msgController.text.isNotEmpty) {
                  _sendMessage(_msgController.text, activeEscrow);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: AppColors.primary),
            onPressed: () {
              if (_msgController.text.isNotEmpty) {
                _sendMessage(_msgController.text, activeEscrow);
              }
            },
          ),
        ],
      ),
    );
  }

  void _triggerFundLockAnimation() {
    setState(() => _showLockAnimation = true);
    _lockAnimationController.reset();
    _lockAnimationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 1)).then((_) {
        if (mounted) {
          setState(() => _showLockAnimation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Escrow Funded successfully. 3000.00 USDC locked.')),
          );
        }
      });
    });
  }

  Widget _buildLockAnimationOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
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
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 72, color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'Funds Locked',
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
