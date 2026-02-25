import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/admin_design_system.dart';
import '../widgets/admin_widgets.dart';
import 'floor_management_screen.dart';


class HostelManagementScreen extends StatefulWidget {
  final String adminId;
  const HostelManagementScreen({super.key, required this.adminId});

  @override
  State<HostelManagementScreen> createState() => _HostelManagementScreenState();
}

class _HostelManagementScreenState extends State<HostelManagementScreen> {
  // ── helpers ─────────────────────────────────
  Stream<QuerySnapshot> get _hostelStream {
    final fs = FirebaseFirestore.instance;
    // Try ownerId; UI merges with adminId results
    return fs.collection('hostels').where('ownerId', isEqualTo: widget.adminId).snapshots();
  }

  Stream<QuerySnapshot> get _hostelStreamFallback {
    return FirebaseFirestore.instance.collection('hostels').where('adminId', isEqualTo: widget.adminId).snapshots();
  }

  Future<void> _showAddHostelDialog() async {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF1E2130) : Colors.white, borderRadius: AdminRadius.xl, boxShadow: AdminShadows.cardHover),
            child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(gradient: AdminGradients.primary, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 20)),
                const SizedBox(width: 12),
                const Expanded(child: Text('Add Hostel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter'))),
                InkWell(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 20),
              AdminTextField(label: 'Hostel / PG Name *', hint: 'e.g., Sunrise Boys Hostel', controller: nameCtrl, validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 14),
              AdminTextField(label: 'Address *', hint: 'Full address', controller: addrCtrl, maxLines: 2, validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 20),
              AdminPrimaryButton(
                label: 'Create Hostel', icon: Icons.add_rounded, isLoading: loading,
                onPressed: loading ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setLocal(() => loading = true);
                  try {
                    // Create hostel + default PG
                    final hostelRef = FirebaseFirestore.instance.collection('hostels').doc();
                    final pgRef = hostelRef.collection('pgs').doc();
                    final batch = FirebaseFirestore.instance.batch();
                    batch.set(hostelRef, {
                      'name': nameCtrl.text.trim(),
                      'hostelName': nameCtrl.text.trim(),
                      'address': addrCtrl.text.trim(),
                      'ownerId': widget.adminId,
                      'adminId': widget.adminId,
                      'floors': 0,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    batch.set(pgRef, {
                      'name': nameCtrl.text.trim(),
                      'pgName': nameCtrl.text.trim(),
                      'hostelId': hostelRef.id,
                      'ownerId': widget.adminId,
                      'adminId': widget.adminId,
                      'floors': 0,
                      'totalBeds': 0,
                      'availableBeds': 0,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    await batch.commit();
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    await showAdminSuccessDialog(context, title: 'Hostel Created!', message: '"${nameCtrl.text.trim()}" is ready. Add floors to get started.');
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                  } finally { setLocal(() => loading = false); }
                },
              ),
            ])),
          ),
        );
      }),
    );
  }

  Future<void> _editHostel(DocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: (d['name'] ?? '').toString());
    final addrCtrl = TextEditingController(text: (d['address'] ?? '').toString());
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF1E2130) : Colors.white, borderRadius: AdminRadius.xl, boxShadow: AdminShadows.cardHover),
            child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(gradient: AdminGradients.indigo, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18)),
                const SizedBox(width: 12),
                const Expanded(child: Text('Edit Hostel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter'))),
                InkWell(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 20),
              AdminTextField(label: 'Hostel / PG Name *', hint: 'Hostel name', controller: nameCtrl, validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 14),
              AdminTextField(label: 'Address', hint: 'Full address', controller: addrCtrl, maxLines: 2),
              const SizedBox(height: 20),
              AdminPrimaryButton(
                label: 'Save Changes', icon: Icons.save_rounded, isLoading: loading, gradient: AdminGradients.indigo,
                onPressed: loading ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setLocal(() => loading = true);
                  try {
                    await doc.reference.update({'name': nameCtrl.text.trim(), 'hostelName': nameCtrl.text.trim(), 'address': addrCtrl.text.trim()});
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                  } finally { setLocal(() => loading = false); }
                },
              ),
            ])),
          ),
        );
      }),
    );
  }

  Future<void> _deleteHostel(DocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>;
    final name = (d['name'] ?? 'this hostel').toString();
    final confirmed = await showAdminConfirmDialog(context, title: 'Delete Hostel?', message: 'Delete "$name"? This cannot be undone.', confirmLabel: 'Delete', isDangerous: true);
    if (!confirmed) return;
    try {
      await doc.reference.delete();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : AdminColors.scaffoldLight,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddHostelDialog,
        backgroundColor: AdminColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Hostel', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(child: Column(children: [
        AdminPageHeader(
          title: 'Hostel Management',
          subtitle: 'Dashboard → Hostels',
          icon: Icons.apartment_rounded,
          iconGradient: AdminGradients.primary,
          onBack: () => Navigator.pop(context),
        ),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: _hostelStream,
          builder: (ctx, snap1) => StreamBuilder<QuerySnapshot>(
            stream: _hostelStreamFallback,
            builder: (ctx, snap2) {
              if (!snap1.hasData && !snap2.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              // Merge both streams, deduplicate by doc id
              final all = <String, QueryDocumentSnapshot>{};
              for (final d in snap1.data?.docs ?? []) all[d.id] = d;
              for (final d in snap2.data?.docs ?? []) all[d.id] = d;
              final hostels = all.values.toList();
              if (hostels.isEmpty) {
                return AdminEmptyState(
                  icon: Icons.apartment_rounded, title: 'No hostels yet',
                  subtitle: 'Create your first hostel to get started.',
                  actionLabel: 'Add Hostel', onAction: _showAddHostelDialog,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: hostels.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) => _HostelCard(
                  doc: hostels[i],
                  adminId: widget.adminId,
                  onEdit: () => _editHostel(hostels[i]),
                  onDelete: () => _deleteHostel(hostels[i]),
                ),
              );
            },
          ),
        )),
      ])),
    );
  }
}

// ─────────────────────────────────────────────
// HostelCard with aggregated metrics
// ─────────────────────────────────────────────
class _HostelCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String adminId;
  final VoidCallback onEdit, onDelete;
  const _HostelCard({required this.doc, required this.adminId, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final name = (d['name'] ?? d['hostelName'] ?? 'Hostel').toString();
    final addr = (d['address'] ?? '').toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<QuerySnapshot>(
      future: doc.reference.collection('pgs').get(),
      builder: (ctx, pgSnap) {
        int totalFloors = 0, totalBeds = 0, availBeds = 0;
        if (pgSnap.hasData) {
          for (final p in pgSnap.data!.docs) {
            final pd = p.data() as Map<String, dynamic>;
            totalFloors += _int(pd['floors']);
            totalBeds += _int(pd['totalBeds']);
            availBeds += _int(pd['availableBeds']);
          }
        }

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2130) : Colors.white,
            borderRadius: AdminRadius.lg,
            boxShadow: AdminShadows.card,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(gradient: AdminGradients.primary, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                if (addr.isNotEmpty) Text(addr, style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary, fontFamily: 'Inter')),
              ])),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AdminColors.textMuted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  _menuItem('manage', Icons.layers_rounded, 'Manage Floors'),
                  _menuItem('edit', Icons.edit_rounded, 'Edit'),
                  _menuItem('delete', Icons.delete_rounded, 'Delete', danger: true),
                ],
                onSelected: (v) {
                  if (v == 'manage') {
                    final pgDocs = pgSnap.data?.docs ?? [];
                    if (pgDocs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No PG found for this hostel')));
                      return;
                    }
                    final pgData = pgDocs.first.data() as Map<String, dynamic>;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => FloorManagementScreen(hostelId: doc.id, pgId: pgDocs.first.id, hostelName: name, pgName: (pgData['name'] ?? pgData['pgName'] ?? '').toString(), adminId: adminId)));
                  } else if (v == 'edit') { onEdit(); }
                  else if (v == 'delete') { onDelete(); }
                },
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _MiniStat(icon: Icons.layers_rounded, label: 'Floors', value: '$totalFloors'),
              const SizedBox(width: 20),
              _MiniStat(icon: Icons.bed_rounded, label: 'Beds', value: '$totalBeds'),
              const SizedBox(width: 20),
              _MiniStat(icon: Icons.check_circle_rounded, label: 'Vacant', value: '$availBeds', color: AdminColors.success),
            ]),
            const SizedBox(height: 12),
            if (totalBeds > 0) ...[
              OccupancyBar(label: 'Occupancy', occupied: totalBeds - availBeds, total: totalBeds),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final pgDocs = pgSnap.data?.docs ?? [];
                  if (pgDocs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No PG found'))); return; }
                  final pgData = pgDocs.first.data() as Map<String, dynamic>;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => FloorManagementScreen(hostelId: doc.id, pgId: pgDocs.first.id, hostelName: name, pgName: (pgData['name'] ?? pgData['pgName'] ?? '').toString(), adminId: adminId)));
                },
                icon: const Icon(Icons.layers_rounded, size: 16),
                label: const Text('Manage Floors', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: AdminColors.primary),
                  foregroundColor: AdminColors.primary,
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  int _int(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {bool danger = false}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 16, color: danger ? AdminColors.danger : AdminColors.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, fontFamily: 'Inter', color: danger ? AdminColors.danger : null)),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon; final String label, value; final Color? color;
  const _MiniStat({required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color ?? AdminColors.primary),
    const SizedBox(width: 4),
    Text('$value $label', style: TextStyle(fontSize: 12, fontFamily: 'Inter', color: color ?? AdminColors.textSecondary)),
  ]);
}
