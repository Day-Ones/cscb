import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import '../data/local/db/app_database.dart';
import '../core/di/locator.dart';
import '../data/local/repositories/event_repository.dart';
import '../core/models/student_attendance.dart';

class AttendanceListPage extends StatefulWidget {
  final Event event;

  const AttendanceListPage({super.key, required this.event});

  @override
  State<AttendanceListPage> createState() => _AttendanceListPageState();
}

class _AttendanceListPageState extends State<AttendanceListPage> {
  final _eventRepo = getIt<EventRepository>();
  List<StudentAttendance> _attendanceList = [];
  List<StudentAttendance> _displayedList = [];
  bool _isLoading = true;
  bool _isExporting = false;
  AttendanceSortOption _sortOption = AttendanceSortOption.programYearLevel;
  bool _isGrouped = true;
  
  // Export filter state
  String? _exportFilterSection; // e.g., "BSIT 3-1", "DIT 1-1", or null for all

  @override
  void initState() {
    super.initState();
    _loadAttendanceList();
  }

  Future<void> _loadAttendanceList() async {
    setState(() => _isLoading = true);
    try {
      final list = await _eventRepo.getStudentAttendanceList(widget.event.id);
      setState(() {
        _attendanceList = list;
        _applySorting();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance: $e')),
        );
      }
    }
  }

  void _applySorting() {
    switch (_sortOption) {
      case AttendanceSortOption.programYearLevel:
        _displayedList = _attendanceList.sortByProgramYearLevel();
        break;
      case AttendanceSortOption.checkInTime:
        _displayedList = _attendanceList.sortByCheckInTime();
        _isGrouped = false;
        break;
      case AttendanceSortOption.alphabetical:
        _displayedList = _attendanceList.sortAlphabetically();
        _isGrouped = false;
        break;
    }
  }

  /// Get list of unique sections (program + year level combinations)
  List<String> _getAvailableSections() {
    final sections = <String>{};
    for (var attendance in _attendanceList) {
      sections.add(attendance.program); // e.g., "BSIT 3-1", "DIT 1-1"
    }
    final sortedSections = sections.toList()..sort();
    return sortedSections;
  }

  /// Get filtered list based on selected section
  List<StudentAttendance> _getFilteredList() {
    if (_exportFilterSection == null) {
      return _displayedList; // All records
    }
    return _displayedList.where((record) => record.program == _exportFilterSection).toList();
  }

  /// Show filter dialog before export
  Future<void> _showFilterDialog(Function(String?) onFilterSelected) async {
    final sections = _getAvailableSections();
    
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Section',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a section to export, or choose "All" for complete list',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            // All option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.select_all, color: Colors.blue.shade700),
              ),
              title: const Text('All Sections'),
              subtitle: Text('${_attendanceList.length} students'),
              trailing: _exportFilterSection == null
                  ? Icon(Icons.check_circle, color: Colors.blue.shade700)
                  : null,
              onTap: () {
                Navigator.pop(context);
                onFilterSelected(null);
              },
            ),
            const Divider(),
            // Individual sections
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  final section = sections[index];
                  final count = _attendanceList.where((r) => r.program == section).length;
                  final isSelected = _exportFilterSection == section;
                  
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.green.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.school,
                        color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ),
                    title: Text(
                      section,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text('$count students'),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: Colors.green.shade700)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      onFilterSelected(section);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort Attendance',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSortOption(
              'Program & Year Level',
              'Group by program and year, then alphabetically',
              Icons.school,
              AttendanceSortOption.programYearLevel,
            ),
            _buildSortOption(
              'Check-in Time',
              'Most recent first',
              Icons.access_time,
              AttendanceSortOption.checkInTime,
            ),
            _buildSortOption(
              'Alphabetical',
              'Sort by last name',
              Icons.sort_by_alpha,
              AttendanceSortOption.alphabetical,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String title, String subtitle, IconData icon, AttendanceSortOption option) {
    final isSelected = _sortOption == option;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Colors.blue.shade700)
          : null,
      onTap: () {
        setState(() {
          _sortOption = option;
          _isGrouped = option == AttendanceSortOption.programYearLevel;
          _applySorting();
        });
        Navigator.pop(context);
      },
    );
  }

  Future<void> _exportToPDF() async {
    // Show filter dialog first
    await _showFilterDialog((selectedFilter) async {
      setState(() {
        _exportFilterSection = selectedFilter;
        _isExporting = true;
      });
      
      try {
        final filteredList = _getFilteredList();
        final filterText = _exportFilterSection ?? 'All Sections';
        
        final pdf = pw.Document();

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Title - Centered
                  pw.Center(
                    child: pw.Text(
                      'ATTENDANCE REPORT',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 24),
                  
                  // Event name (left) and Date (right) on same line
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Event: ${widget.event.name}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Date: ${_formatDate(widget.event.eventDate)}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  
                  // Year & Section
                  pw.Text(
                    'Year & Section: ${_exportFilterSection ?? 'All Year Levels'}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 6),
                  
                  // Total Attendees
                  pw.Text(
                    'Total Attendees: ${filteredList.length}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Divider line
                  pw.Divider(thickness: 1.5),
                  pw.SizedBox(height: 12),
                  
                  // Table
                  pw.Table.fromTextArray(
                    headers: ['#', 'Student No.', 'Name', 'Program', 'Year', 'Check-in Time'],
                    data: filteredList.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final record = entry.value;
                      // Extract program abbreviation (BSIT or DIT) and year level (1-1, 2-1, etc.)
                      final programParts = record.program.split(' ');
                      final programAbbrev = programParts.isNotEmpty ? programParts[0] : record.program;
                      final yearLevel = programParts.length > 1 ? programParts[1] : '${record.yearLevel}-1';
                      
                      return [
                        index.toString(),
                        record.studentNumber,
                        record.fullName,
                        programAbbrev, // Just BSIT or DIT
                        yearLevel, // Just 1-1, 2-1, 3-1, or 4-1
                        _formatDateTime(record.timestamp),
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellAlignment: pw.Alignment.centerLeft,
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    headerPadding: const pw.EdgeInsets.all(8),
                    cellPadding: const pw.EdgeInsets.all(6),
                    border: pw.TableBorder.all(
                      color: PdfColors.grey400,
                      width: 0.5,
                    ),
                  ),
                ],
              );
            },
          ),
        );

        final output = await getTemporaryDirectory();
        final filterSuffix = _exportFilterSection != null 
            ? '_${_exportFilterSection!.replaceAll(' ', '_')}' 
            : '_all';
        final file = File('${output.path}/attendance_${widget.event.name.replaceAll(' ', '_')}$filterSuffix.pdf');
        await file.writeAsBytes(await pdf.save());

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Attendance Report - ${widget.event.name} ($filterText)',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF exported successfully! ($filterText)')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error exporting PDF: $e')),
          );
        }
      } finally {
        setState(() => _isExporting = false);
      }
    });
  }

  Future<void> _exportToExcel() async {
    // Show filter dialog first
    await _showFilterDialog((selectedFilter) async {
      setState(() {
        _exportFilterSection = selectedFilter;
        _isExporting = true;
      });
      
      try {
        final filteredList = _getFilteredList();
        final filterText = _exportFilterSection ?? 'All Sections';
        
        List<List<dynamic>> rows = [
          ['Event', widget.event.name],
          ['Date', _formatDate(widget.event.eventDate)],
          ['Filter', filterText],
          ['Total Attendees', filteredList.length.toString()],
          [], // Empty row
          ['#', 'Student No.', 'Last Name', 'First Name', 'Program', 'Year Level', 'Check-in Time'],
        ];

        for (var i = 0; i < filteredList.length; i++) {
          final record = filteredList[i];
          // Extract program abbreviation (BSIT or DIT) and year level (1-1, 2-1, etc.)
          final programParts = record.program.split(' ');
          final programAbbrev = programParts.isNotEmpty ? programParts[0] : record.program;
          final yearLevel = programParts.length > 1 ? programParts[1] : '${record.yearLevel}-1';
          
          rows.add([
            (i + 1).toString(),
            record.studentNumber,
            record.lastName,
            record.firstName,
            programAbbrev, // Just BSIT or DIT
            yearLevel, // Just 1-1, 2-1, 3-1, or 4-1
            _formatDateTime(record.timestamp),
          ]);
        }

        String csv = const ListToCsvConverter().convert(rows);

        final output = await getTemporaryDirectory();
        final filterSuffix = _exportFilterSection != null 
            ? '_${_exportFilterSection!.replaceAll(' ', '_')}' 
            : '_all';
        final file = File('${output.path}/attendance_${widget.event.name.replaceAll(' ', '_')}$filterSuffix.csv');
        await file.writeAsString(csv);

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Attendance Report - ${widget.event.name} ($filterText)',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('CSV exported successfully! ($filterText)')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error exporting CSV: $e')),
          );
        }
      } finally {
        setState(() => _isExporting = false);
      }
    });
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export Attendance',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.picture_as_pdf, color: Colors.red.shade700),
              ),
              title: const Text('Export as PDF'),
              subtitle: const Text('Formatted document'),
              onTap: () {
                Navigator.pop(context);
                _exportToPDF();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.table_chart, color: Colors.green.shade700),
              ),
              title: const Text('Export as CSV'),
              subtitle: const Text('Excel compatible'),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.purple.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Attendance List',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_attendanceList.isNotEmpty && !_isExporting)
                      IconButton(
                        onPressed: _showSortOptions,
                        icon: const Icon(Icons.sort, color: Colors.white),
                        tooltip: 'Sort',
                      ),
                    if (_attendanceList.isNotEmpty && !_isExporting)
                      IconButton(
                        onPressed: _showExportOptions,
                        icon: const Icon(Icons.download, color: Colors.white),
                        tooltip: 'Export',
                      ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    child: Column(
                      children: [
                        // Event Info Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade50,
                                Colors.purple.shade50,
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.event.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(widget.event.eventDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Total Attendees: ${_attendanceList.length}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Attendance List
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _attendanceList.isEmpty
                                  ? _buildEmptyState()
                                  : _isGrouped
                                      ? _buildGroupedList()
                                      : _buildAttendanceList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No attendance records yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start scanning QR codes to track attendance',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    return RefreshIndicator(
      onRefresh: _loadAttendanceList,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _displayedList.length,
        itemBuilder: (context, index) {
          final record = _displayedList[index];
          return _buildAttendanceCard(record, index + 1);
        },
      ),
    );
  }

  Widget _buildGroupedList() {
    final grouped = _displayedList.groupByProgramYearLevel();
    final sortedKeys = grouped.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _loadAttendanceList,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final key = sortedKeys[index];
          final students = grouped[key]!;
          return _buildGroupSection(key, students, index == 0);
        },
      ),
    );
  }

  Widget _buildGroupSection(String title, List<StudentAttendance> students, bool isFirst) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isFirst) const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade400,
                Colors.purple.shade400,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.school, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${students.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...students.asMap().entries.map((entry) {
          final localIndex = entry.key + 1;
          final student = entry.value;
          return _buildAttendanceCard(student, localIndex);
        }),
      ],
    );
  }

  Widget _buildAttendanceCard(StudentAttendance record, int number) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Number badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade400,
                    Colors.purple.shade400,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  number.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.studentNumber,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.school,
                        size: 13,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${record.program} - Year ${record.yearLevel}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(record.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                record.status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${_formatDate(dateTime)} at $hour:$minute $period';
  }
}
