import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ResidentNoticesScreen extends StatefulWidget {
  final String residentId;
  final String? pgId;

  const ResidentNoticesScreen({
    super.key,
    required this.residentId,
    required this.pgId,
  });

  @override
  State<ResidentNoticesScreen> createState() => _ResidentNoticesScreenState();
}

class _ResidentNoticesScreenState extends State<ResidentNoticesScreen> {
  String? _expandedNoticeId;
  final String _filterType =
      'all'; // all, general, maintenance, payment, warning
  final String _sortOrder = 'newest'; // newest, oldest

  Color _typeColor(String rawType) {
    final type = rawType.toLowerCase();
    if (type == 'general') return const Color(0xFF6366F1); // Indigo
    if (type == 'maintenance') return const Color(0xFFF59E0B); // Amber
    if (type == 'payment') return const Color(0xFF10B981); // Emerald
    if (type == 'warning') return const Color(0xFFEF4444); // Red
    return const Color(0xFF6366F1);
  }

  String _typeLabel(String rawType) {
    final type = rawType.toLowerCase();
    if (type == 'general') return 'General';
    if (type == 'maintenance') return 'Maintenance';
    if (type == 'payment') return 'Payment';
    if (type == 'warning') return 'Warning';
    return 'Notice';
  }

  String _formatDate(Timestamp? createdAt) {
    if (createdAt == null) return '—';
    return DateFormat('MMM dd, yyyy').format(createdAt.toDate());
  }

  Stream<QuerySnapshot> _allNoticesStream() {
    // Return empty stream if pgId is not available
    if (widget.pgId == null || widget.pgId!.isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('notices')
        .where('scope', isEqualTo: 'ALL')
        .where('senderRole', isEqualTo: 'admin')
        .where('isActive', isEqualTo: true)
        .where('pgIds', arrayContains: widget.pgId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _hostelNoticesStream() {
    // Return empty stream if pgId is not available
    if (widget.pgId == null || widget.pgId!.isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('notices')
        .where('scope', isEqualTo: 'PG')
        .where('senderRole', isEqualTo: 'admin')
        .where('isActive', isEqualTo: true)
        .where('pgIds', arrayContains: widget.pgId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _residentNoticesStream() {
    return FirebaseFirestore.instance
        .collection('notices')
        .where('scope', isEqualTo: 'RESIDENT')
        .where('senderRole', isEqualTo: 'admin')
        .where('isActive', isEqualTo: true)
        .where('residentIds', arrayContains: widget.residentId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _mergeNotices(
    List<QueryDocumentSnapshot> a,
    List<QueryDocumentSnapshot> b,
    List<QueryDocumentSnapshot> c,
  ) {
    final map = <String, QueryDocumentSnapshot>{};
    for (final doc in a) {
      map[doc.id] = doc;
    }
    for (final doc in b) {
      map[doc.id] = doc;
    }
    for (final doc in c) {
      map[doc.id] = doc;
    }
    final merged = map.values.toList();
    merged.sort((x, y) {
      final xData = x.data() as Map<String, dynamic>;
      final yData = y.data() as Map<String, dynamic>;
      final xTime = xData['createdAt'] as Timestamp?;
      final yTime = yData['createdAt'] as Timestamp?;
      final xMillis = xTime?.millisecondsSinceEpoch ?? 0;
      final yMillis = yTime?.millisecondsSinceEpoch ?? 0;
      return yMillis.compareTo(xMillis);
    });
    return merged;
  }

  Stream<Set<String>> _readStatusStream() {
    return FirebaseFirestore.instance
        .collection('residents')
        .doc(widget.residentId)
        .collection('readStatus')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  bool _isRead(String noticeId, Set<String> readIds) {
    return readIds.contains(noticeId);
  }

  Map<String, int> _calculateTypeCounts(List<QueryDocumentSnapshot> notices) {
    final counts = <String, int>{
      'general': 0,
      'maintenance': 0,
      'payment': 0,
      'warning': 0,
    };

    for (final doc in notices) {
      final data = doc.data() as Map<String, dynamic>;
      final type = (data['noticeType'] ?? '').toString().toLowerCase();
      if (counts.containsKey(type)) {
        counts[type] = counts[type]! + 1;
      }
    }

    return counts;
  }

  List<QueryDocumentSnapshot> _applyFilters(
    List<QueryDocumentSnapshot> notices,
  ) {
    var filtered = notices;

    // Filter by type
    if (_filterType != 'all') {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final type = (data['noticeType'] ?? '').toString().toLowerCase();
        return type == _filterType;
      }).toList();
    }

    // Sort
    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aTime = aData['createdAt'] as Timestamp?;
      final bTime = bData['createdAt'] as Timestamp?;
      final aMillis = aTime?.millisecondsSinceEpoch ?? 0;
      final bMillis = bTime?.millisecondsSinceEpoch ?? 0;
      return _sortOrder == 'newest'
          ? bMillis.compareTo(aMillis)
          : aMillis.compareTo(bMillis);
    });

    return filtered;
  }

  void _showNoticeDetail(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return _NoticeDetailModal(
            data: data,
            scrollController: scrollController,
            typeColor: _typeColor,
            typeLabel: _typeLabel,
            formatDate: _formatDate,
          );
        },
      ),
    );

    _markRead(doc.id);
  }

  Future<void> _markRead(String noticeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('residents')
          .doc(widget.residentId)
          .collection('readStatus')
          .doc(noticeId)
          .set({'readAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  Future<void> _refreshNotices() async {
    await Future.wait([
      _allNoticesStream().first,
      if (widget.pgId != null) _hostelNoticesStream().first,
      _residentNoticesStream().first,
    ]);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: _readStatusStream(),
      builder: (context, readStatusSnap) {
        final readIds = readStatusSnap.data ?? {};
        if (widget.pgId == null || widget.pgId!.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Notices')),
            body: _EmptyNoticesState(),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Notices',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: false,
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E293B),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _allNoticesStream(),
            builder: (context, allSnap) {
              if (allSnap.hasError) {
                return _ErrorState(onRetry: _refreshNotices);
              }
              if (allSnap.connectionState == ConnectionState.waiting) {
                return const _NoticeShimmerList();
              }
              final allDocs = allSnap.data?.docs ?? [];

              final hostelStream = widget.pgId == null
                  ? Stream<QuerySnapshot?>.value(null)
                  : _hostelNoticesStream();
              return StreamBuilder<QuerySnapshot?>(
                stream: hostelStream,
                builder: (context, hostelSnap) {
                  if (hostelSnap.hasError) {
                    return _ErrorState(onRetry: _refreshNotices);
                  }
                  if (widget.pgId != null &&
                      hostelSnap.connectionState == ConnectionState.waiting) {
                    return const _NoticeShimmerList();
                  }
                  final hostelDocs = hostelSnap.data?.docs ?? [];

                  return StreamBuilder<QuerySnapshot>(
                    stream: _residentNoticesStream(),
                    builder: (context, residentSnap) {
                      if (residentSnap.hasError) {
                        return _ErrorState(onRetry: _refreshNotices);
                      }
                      if (residentSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const _NoticeShimmerList();
                      }
                      final residentDocs = residentSnap.data?.docs ?? [];
                      final merged = _mergeNotices(
                        allDocs,
                        hostelDocs,
                        residentDocs,
                      );

                      // Apply filters and sorting
                      final filtered = _applyFilters(merged);

                      if (merged.isEmpty) {
                        return _EmptyNoticesState();
                      }

                      return RefreshIndicator(
                        onRefresh: _refreshNotices,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final doc = filtered[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final title = (data['title'] ?? 'Notice')
                                .toString();
                            final description = (data['message'] ?? '')
                                .toString();
                            final noticeType = (data['noticeType'] ?? '')
                                .toString();
                            final createdAt = data['createdAt'] as Timestamp?;
                            final badgeColor = _typeColor(noticeType);
                            final isRead = _isRead(doc.id, readIds);
                            final isExpanded = _expandedNoticeId == doc.id;

                            return _NoticeCard(
                              title: title,
                              description: description,
                              typeLabel: _typeLabel(noticeType),
                              badgeColor: badgeColor,
                              isRead: isRead,
                              isExpanded: isExpanded,
                              onTap: () => _showNoticeDetail(doc),
                              formattedDate: _formatDate(createdAt),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String title;
  final String description;
  final String typeLabel;
  final Color badgeColor;
  final String formattedDate;
  final bool isRead;
  final bool isExpanded;
  final VoidCallback onTap;

  const _NoticeCard({
    required this.title,
    required this.description,
    required this.typeLabel,
    required this.badgeColor,
    required this.formattedDate,
    required this.isRead,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isRead ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRead
              ? const Color(0xFFF1F5F9)
              : const Color(0xFF6366F1).withOpacity(0.1),
        ),
        boxShadow: isRead
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6366F1),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description.isEmpty
                            ? 'No description provided.'
                            : description,
                        maxLines: isExpanded ? null : 2,
                        overflow: isExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              typeLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: badgeColor,
                                letterSpacing: 0.5,
                              ),
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
        ),
      ),
    );
  }
}

class _NoticeShimmerList extends StatelessWidget {
  const _NoticeShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _Shimmer(
                  child: Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Shimmer(
                        child: Container(
                          width: 120,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _Shimmer(
                        child: Container(
                          width: double.infinity,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Shimmer(
                            child: Container(
                              width: 80,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          _Shimmer(
                            child: Container(
                              width: 60,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(6),
                              ),
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
}

class _EmptyNoticesState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_rounded,
                color: Color(0xFF6366F1),
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Notices Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Admin announcements and updates\nwill appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  final Widget child;

  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1.0 - _controller.value, -0.3),
              end: Alignment(1.0 + _controller.value, 0.3),
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load notices',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/* =========================================================
   FILTER SECTION
========================================================= */

class _FilterSection extends StatelessWidget {
  final List<QueryDocumentSnapshot> allNotices;
  final String filterType;
  final String sortOrder;
  final Function(String) onFilterChanged;
  final Function(String) onSortChanged;
  final Map<String, int> Function(List<QueryDocumentSnapshot>)
  calculateTypeCounts;

  const _FilterSection({
    required this.allNotices,
    required this.filterType,
    required this.sortOrder,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.calculateTypeCounts,
  });

  @override
  Widget build(BuildContext context) {
    final counts = calculateTypeCounts(allNotices);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Filter by Type',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    count: allNotices.length,
                    isSelected: filterType == 'all',
                    onTap: () => onFilterChanged('all'),
                    color: const Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'General',
                    count: counts['general'] ?? 0,
                    isSelected: filterType == 'general',
                    onTap: () => onFilterChanged('general'),
                    color: const Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Maintenance',
                    count: counts['maintenance'] ?? 0,
                    isSelected: filterType == 'maintenance',
                    onTap: () => onFilterChanged('maintenance'),
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Payment',
                    count: counts['payment'] ?? 0,
                    isSelected: filterType == 'payment',
                    onTap: () => onFilterChanged('payment'),
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Warning',
                    count: counts['warning'] ?? 0,
                    isSelected: filterType == 'warning',
                    onTap: () => onFilterChanged('warning'),
                    color: const Color(0xFFEF4444),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  'Sort by',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: sortOrder,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF64748B),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'newest',
                            child: Text('Newest First'),
                          ),
                          DropdownMenuItem(
                            value: 'oldest',
                            child: Text('Oldest First'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) onSortChanged(value);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFF6366F1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.white,
          border: Border.all(
            color: isSelected ? chipColor : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================================================
   NOTICE DETAIL MODAL
========================================================= */

class _NoticeDetailModal extends StatelessWidget {
  final Map<String, dynamic> data;
  final ScrollController scrollController;
  final Color Function(String) typeColor;
  final String Function(String) typeLabel;
  final String Function(Timestamp?) formatDate;

  const _NoticeDetailModal({
    required this.data,
    required this.scrollController,
    required this.typeColor,
    required this.typeLabel,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? 'Notice').toString();
    final message = (data['message'] ?? '').toString();
    final noticeType = (data['noticeType'] ?? '').toString();
    final createdAt = data['createdAt'] as Timestamp?;
    final badgeColor = typeColor(noticeType);
    final label = typeLabel(noticeType);
    final dateStr = formatDate(createdAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.05),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Material(
                      color: const Color(0xFFF1F5F9),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: const Color(0xFF64748B),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  message.isEmpty ? 'No message provided.' : message,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Close Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
