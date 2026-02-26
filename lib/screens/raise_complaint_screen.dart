import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RaiseComplaintScreen extends StatefulWidget {
  final String residentId;

  const RaiseComplaintScreen({super.key, required this.residentId});

  @override
  State<RaiseComplaintScreen> createState() => _RaiseComplaintScreenState();
}

class _RaiseComplaintScreenState extends State<RaiseComplaintScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  String _priority = 'Low';
  bool _isSubmitting = false;
  bool _isLoadingLocation = true;

  // Location details fetched from DB
  String _hostelName = '-';
  String _floorLabel = '-';
  String _roomNumber = '-';
  String? _hostelId;
  String? _pgId;
  String? _floorId;
  String? _roomId;
  String? _adminId;
  String _residentName = 'Resident';

  static const teal = Color(0xFF14B8A6);

  final List<String> _categories = [
    'Plumbing',
    'Electrical',
    'Furniture',
    'Cleaning',
    'Internet / WiFi',
    'Water Supply',
    'Security',
    'Noise',
    'Pest Control',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fetchLocationDetails();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationDetails() async {
    try {
      final residentSnap = await FirebaseFirestore.instance
          .collection('residents')
          .doc(widget.residentId)
          .get();
      final residentData = residentSnap.data();
      if (residentData == null) {
        debugPrint('RaiseComplaint: No resident data found for ${widget.residentId}');
        return;
      }

      // Get adminId and resident name
      _adminId = residentData['adminId']?.toString();
      _residentName = residentData['fullName']?.toString() ??
          residentData['name']?.toString() ??
          'Resident';

      final allocation =
          residentData['allocationDetails'] as Map<String, dynamic>?;
      
      // Try allocationDetails first, then root-level fields
      final hId = allocation?['hostelId']?.toString() ??
          residentData['hostelId']?.toString();
      final pId = allocation?['pgId']?.toString() ??
          residentData['pgId']?.toString();
      final fId = allocation?['floorId']?.toString() ??
          residentData['floorId']?.toString();
      final rId = allocation?['roomId']?.toString() ??
          residentData['roomId']?.toString();

      debugPrint('RaiseComplaint: IDs - hostel=$hId, pg=$pId, floor=$fId, room=$rId, admin=$_adminId');

      if (hId == null || pId == null || fId == null || rId == null) {
        debugPrint('RaiseComplaint: Missing allocation IDs');
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      _hostelId = hId;
      _pgId = pId;
      _floorId = fId;
      _roomId = rId;

      final hostelRef =
          FirebaseFirestore.instance.collection('hostels').doc(hId);
      final floorRef =
          hostelRef.collection('pgs').doc(pId).collection('floors').doc(fId);
      final roomRef = floorRef.collection('rooms').doc(rId);

      final results =
          await Future.wait([hostelRef.get(), floorRef.get(), roomRef.get()]);

      final hostelData = results[0].data();
      final floorData = results[1].data();
      final roomData = results[2].data();

      debugPrint('RaiseComplaint: hostelData=$hostelData');
      debugPrint('RaiseComplaint: floorData=$floorData');
      debugPrint('RaiseComplaint: roomData=$roomData');

      if (mounted) {
        setState(() {
          _hostelName = hostelData?['hostelName']?.toString() ??
              hostelData?['name']?.toString() ??
              '-';
          final floorIndex = floorData?['floorIndex'];
          _floorLabel = floorData?['floorName']?.toString() ??
              floorData?['floorNumber']?.toString() ??
              floorData?['floorLabel']?.toString() ??
              (floorIndex != null ? 'Floor $floorIndex' : '-');
          _roomNumber = roomData?['roomNumber']?.toString() ?? '-';
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('RaiseComplaint: Error fetching location: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load location details: $e'),
            backgroundColor: const Color(0xFFF59E0B),
          ),
        );
      }
    }
  }

  Future<void> _submitComplaint() async {
    // Validate
    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter a complaint title');
      return;
    }
    if (_selectedCategory == null) {
      _showError('Please select a category');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showError('Please enter a detailed description');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('complaints').add({
        'residentId': widget.residentId,
        'residentName': _residentName,
        'adminId': _adminId,
        'title': _titleController.text.trim(),
        'category': _selectedCategory,
        'priority': _priority.toLowerCase(),
        'description': _descriptionController.text.trim(),
        'hostelId': _hostelId,
        'pgId': _pgId,
        'floorId': _floorId,
        'roomId': _roomId,
        'hostelName': _hostelName,
        'floorLabel': _floorLabel,
        'roomNumber': _roomNumber,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 64),
              const SizedBox(height: 16),
              const Text(
                'Complaint Submitted!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your complaint has been submitted and will be reviewed by the admin team.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Done',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showError('Failed to submit complaint: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: const Color(0xFF1E293B),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 12),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: teal.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.report_problem_rounded,
                          color: Color(0xFF14B8A6),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Raise Complaint',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Dashboard → Complaints → Raise Complaint',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ──
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ════════════════════════════════════
                      // COMPLAINT DETAILS SECTION
                      // ════════════════════════════════════
                      _buildSectionHeader(
                        icon: Icons.info_outline_rounded,
                        title: 'Complaint Details',
                        gradient: LinearGradient(
                          colors: [
                            teal.withOpacity(0.08),
                            teal.withOpacity(0.03),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border:
                              Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Complaint Title ──
                            _buildFieldLabel('Complaint Title'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _titleController,
                              decoration: _inputDecoration(
                                hint:
                                    'Brief description (e.g., AC not working)',
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1E293B),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── Category Dropdown ──
                            _buildFieldLabel('Category'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: _inputDecoration(
                                hint: 'Select category',
                              ),
                              icon: const Icon(
                                Icons.unfold_more_rounded,
                                color: Color(0xFF94A3B8),
                              ),
                              items: _categories.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(
                                    cat,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedCategory = val),
                            ),

                            const SizedBox(height: 24),

                            // ── Priority Level ──
                            _buildFieldLabel('Priority Level'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildPriorityChip('Low', const Color(0xFF64748B)),
                                const SizedBox(width: 12),
                                _buildPriorityChip(
                                    'Medium', const Color(0xFFF59E0B)),
                                const SizedBox(width: 12),
                                _buildPriorityChip(
                                    'High', const Color(0xFFEF4444)),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // ── Detailed Description ──
                            _buildFieldLabel('Detailed Description'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _descriptionController,
                              maxLines: 5,
                              onChanged: (_) => setState(() {}),
                              decoration: _inputDecoration(
                                hint:
                                    'Please describe your complaint in detail...',
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_descriptionController.text.length} characters',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF14B8A6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ════════════════════════════════════
                      // LOCATION DETAILS SECTION
                      // ════════════════════════════════════
                      _buildSectionHeader(
                        icon: Icons.apartment_rounded,
                        title: 'Location Details',
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFE879F9).withOpacity(0.1),
                            const Color(0xFFF0ABFC).withOpacity(0.04),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border:
                              Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: _isLoadingLocation
                            ? const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF14B8A6),
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                            : Row(
                          children: [
                            Expanded(
                              child: _buildLocationCard(
                                icon: Icons.apartment_rounded,
                                label: 'Hostel',
                                value: _hostelName,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildLocationCard(
                                icon: Icons.layers_rounded,
                                label: 'Floor',
                                value: _floorLabel,
                                color: teal,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildLocationCard(
                                icon: Icons.meeting_room_outlined,
                                label: 'Room',
                                value: _roomNumber,
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ════════════════════════════════════
                      // INITIAL STATUS BANNER
                      // ════════════════════════════════════
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF9C3).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFDE047).withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Initial Status',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF92400E)
                                          .withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Your complaint will be reviewed by the admin team',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Pending Review',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ════════════════════════════════════
                      // ACTION BUTTONS
                      // ════════════════════════════════════
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                side: const BorderSide(
                                    color: Color(0xFFE2E8F0)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isSubmitting ? null : _submitComplaint,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.description_rounded,
                                      size: 18),
                              label: Text(
                                _isSubmitting
                                    ? 'Submitting...'
                                    : 'Submit Complaint',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: teal,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    teal.withOpacity(0.6),
                                disabledForegroundColor: Colors.white70,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Builders ──

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF334155), size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const TextSpan(
            text: ' *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFFCBD5E1),
      ),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.5),
      ),
    );
  }

  Widget _buildPriorityChip(String label, Color color) {
    final isSelected = _priority == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.4) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected ? color : const Color(0xFFCBD5E1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
