import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ResidentNoticesScreen extends StatelessWidget {
  final String residentId;
  final String? hostelId;

  const ResidentNoticesScreen({
    super.key,
    required this.residentId,
    required this.hostelId,
  });

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
        .where('audienceType', isEqualTo: 'all')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _hostelNoticesStream() {
    return FirebaseFirestore.instance
        .collection('notices')
        .where('audienceType', isEqualTo: 'hostel')
        .where('hostelId', isEqualTo: hostelId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _residentNoticesStream() {
    return FirebaseFirestore.instance
        .collection('notices')
        .where('audienceType', isEqualTo: 'resident')
        .where('residentId', isEqualTo: residentId)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notices'),
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _allNoticesStream(),
        builder: (context, allSnap) {
          if (allSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!allSnap.hasData) {
            return const Center(
              child: Text('No notices available at the moment'),
            );
          }
          final allDocs = allSnap.data?.docs ?? [];

          final hostelStream =
              hostelId == null ? Stream<QuerySnapshot?>.value(null) : _hostelNoticesStream();
          return StreamBuilder<QuerySnapshot?>(
            stream: hostelStream,
            builder: (context, hostelSnap) {
              if (hostelId != null &&
                  hostelSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final hostelDocs = hostelSnap.data?.docs ?? [];

              return StreamBuilder<QuerySnapshot>(
                stream: _residentNoticesStream(),
                builder: (context, residentSnap) {
                  if (residentSnap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final residentDocs = residentSnap.data?.docs ?? [];
                  final merged =
                      _mergeNotices(allDocs, hostelDocs, residentDocs);

                  if (merged.isEmpty) {
                    return const Center(
                      child: Text('No notices available at the moment'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: merged.length,
                    itemBuilder: (context, index) {
                      final doc = merged[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final title = (data['title'] ?? 'Notice').toString();
                      final description =
                          (data['description'] ?? '').toString();
                      final noticeType =
                          (data['noticeType'] ?? '').toString();
                      final createdAt = data['createdAt'] as Timestamp?;
                      final badgeColor = _typeColor(noticeType);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (_) {
                                return Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: SafeArea(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: badgeColor
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  _typeLabel(noticeType),
                                                  style: TextStyle(
                                                    color: badgeColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                _formatDate(createdAt),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            description.isEmpty
                                                ? 'No description provided.'
                                                : description,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Close'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 6,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  badgeColor.withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              _typeLabel(noticeType),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: badgeColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            _formatDate(createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        description.isEmpty
                                            ? 'No description provided.'
                                            : description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
