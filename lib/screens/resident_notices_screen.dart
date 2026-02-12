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

  Color _typeColor(String rawType) {
    final type = rawType.toLowerCase();
    if (type == 'general') return const Color(0xFF3B82F6);
    if (type == 'maintenance') return const Color(0xFFF97316);
    if (type == 'payment') return const Color(0xFF7C3AED);
    if (type == 'warning') return const Color(0xFFEF4444);
    return const Color(0xFF6B7280);
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

  bool _isRead(Map<String, dynamic> data) {
    final readers = data['readBy'];
    if (readers is Iterable) {
      return readers.contains(widget.residentId);
    }
    return false;
  }

  Future<void> _markRead(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    if (_isRead(data)) return;
    try {
      await doc.reference.update({
        'readBy': FieldValue.arrayUnion([widget.residentId]),
      });
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
    if (widget.pgId == null || widget.pgId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notices')),
        body: _EmptyNoticesState(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Notices'), centerTitle: false),
      body: StreamBuilder<QuerySnapshot>(
        stream: _allNoticesStream(),
        builder: (context, allSnap) {
          if (allSnap.connectionState == ConnectionState.waiting) {
            return const _NoticeShimmerList();
          }
          if (!allSnap.hasData) {
            return _EmptyNoticesState();
          }
          final allDocs = allSnap.data?.docs ?? [];

          final hostelStream = widget.pgId == null
              ? Stream<QuerySnapshot?>.value(null)
              : _hostelNoticesStream();
          return StreamBuilder<QuerySnapshot?>(
            stream: hostelStream,
            builder: (context, hostelSnap) {
              if (widget.pgId != null &&
                  hostelSnap.connectionState == ConnectionState.waiting) {
                return const _NoticeShimmerList();
              }
              final hostelDocs = hostelSnap.data?.docs ?? [];

              return StreamBuilder<QuerySnapshot>(
                stream: _residentNoticesStream(),
                builder: (context, residentSnap) {
                  if (residentSnap.connectionState == ConnectionState.waiting) {
                    return const _NoticeShimmerList();
                  }
                  final residentDocs = residentSnap.data?.docs ?? [];
                  final merged = _mergeNotices(
                    allDocs,
                    hostelDocs,
                    residentDocs,
                  );

                  if (merged.isEmpty) {
                    return _EmptyNoticesState();
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshNotices,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: merged.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = merged[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final title = (data['title'] ?? 'Notice').toString();
                        final description = (data['message'] ?? '').toString();
                        final noticeType = (data['noticeType'] ?? '')
                            .toString();
                        final createdAt = data['createdAt'] as Timestamp?;
                        final badgeColor = _typeColor(noticeType);
                        final isRead = _isRead(data);
                        final isExpanded = _expandedNoticeId == doc.id;

                        return _NoticeCard(
                          title: title,
                          description: description,
                          typeLabel: _typeLabel(noticeType),
                          badgeColor: badgeColor,
                          isRead: isRead,
                          isExpanded: isExpanded,
                          onTap: () {
                            setState(() {
                              _expandedNoticeId = isExpanded ? null : doc.id;
                            });
                            _markRead(doc);
                          },
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
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final muted = Theme.of(context).textTheme.bodySmall?.color;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 82,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: badgeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isRead)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'New',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isRead ? 0 : 8,
                          height: isRead ? 0 : 8,
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeInOut,
                      child: Text(
                        description.isEmpty
                            ? 'No description provided.'
                            : description,
                        maxLines: isExpanded ? null : 2,
                        overflow: isExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isExpanded ? 'Tap to collapse' : 'Tap to read more',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
            ],
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
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _Shimmer(
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
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
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_off, color: Colors.teal),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Notices Yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Admin announcements will appear here.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
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
