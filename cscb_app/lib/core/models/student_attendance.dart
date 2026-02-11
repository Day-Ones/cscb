/// Model for student attendance with detailed information
class StudentAttendance {
  final String id;
  final String eventId;
  final String studentNumber;
  final String lastName;
  final String firstName;
  final String program; // Stored as "BSIT 1-1", "DIT 2-1", etc.
  final int yearLevel;
  final DateTime timestamp;
  final String status;

  StudentAttendance({
    required this.id,
    required this.eventId,
    required this.studentNumber,
    required this.lastName,
    required this.firstName,
    required this.program,
    required this.yearLevel,
    required this.timestamp,
    required this.status,
  });

  String get fullName => '$lastName, $firstName';
  
  /// Get program abbreviation (BSIT, DIT)
  String get programAbbreviation {
    if (program.startsWith('BSIT')) return 'BSIT';
    if (program.startsWith('DIT')) return 'DIT';
    return program.split(' ').first;
  }

  /// Parse QR code data
  /// Expected format: JSON object with studentNumber, fullName, program, yearLevel
  /// Example: {"studentNumber":"2023-00495-TG-0","fullName":"Daniel Victorioso","program":"Diploma in Information Technology","yearLevel":"3rd Year","registrationDate":"2026-02-10T20:48:18.245Z","id":"CSCB-2023-00495-TG-0-1770756498245"}
  static StudentAttendance? fromQRCode(String qrData, String eventId, String attendanceId) {
    try {
      // Try to parse as JSON first
      final Map<String, dynamic> data = {};
      
      if (qrData.trim().startsWith('{')) {
        // JSON format
        final jsonData = Map<String, dynamic>.from(
          // Using a simple JSON parser
          _parseJson(qrData)
        );
        
        final studentNumber = jsonData['studentNumber']?.toString() ?? '';
        final fullName = jsonData['fullName']?.toString() ?? '';
        final programFull = jsonData['program']?.toString() ?? '';
        final yearLevelFull = jsonData['yearLevel']?.toString() ?? '';
        
        if (studentNumber.isEmpty || fullName.isEmpty) return null;
        
        // Split full name into last name and first name
        final nameParts = fullName.split(' ');
        String lastName = '';
        String firstName = '';
        
        if (nameParts.length >= 2) {
          firstName = nameParts[0];
          lastName = nameParts.sublist(1).join(' ');
        } else if (nameParts.length == 1) {
          lastName = nameParts[0];
          firstName = '';
        }
        
        // Convert program to abbreviation
        String programAbbrev;
        if (programFull.toLowerCase().contains('bachelor of science in information technology')) {
          programAbbrev = 'BSIT';
        } else if (programFull.toLowerCase().contains('diploma in information technology')) {
          programAbbrev = 'DIT';
        } else {
          programAbbrev = programFull;
        }
        
        // Extract year number from "1st Year", "2nd Year", etc.
        int yearNumber;
        if (yearLevelFull.toLowerCase().contains('1st')) {
          yearNumber = 1;
        } else if (yearLevelFull.toLowerCase().contains('2nd')) {
          yearNumber = 2;
        } else if (yearLevelFull.toLowerCase().contains('3rd')) {
          yearNumber = 3;
        } else if (yearLevelFull.toLowerCase().contains('4th')) {
          yearNumber = 4;
        } else {
          yearNumber = int.tryParse(yearLevelFull.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        }
        
        // Format as "BSIT 1-1", "DIT 2-1", etc.
        final programFormatted = '$programAbbrev $yearNumber-1';
        
        return StudentAttendance(
          id: attendanceId,
          eventId: eventId,
          studentNumber: studentNumber,
          lastName: lastName,
          firstName: firstName,
          program: programFormatted,
          yearLevel: yearNumber,
          timestamp: DateTime.now(),
          status: 'present',
        );
      } else {
        // Fallback: pipe-separated format for backward compatibility
        final parts = qrData.split('|');
        if (parts.length != 5) return null;

        final studentNumber = parts[0].trim();
        final lastName = parts[1].trim();
        final firstName = parts[2].trim();
        final programFull = parts[3].trim();
        final yearLevelFull = parts[4].trim();

        // Convert program to abbreviation
        String programAbbrev;
        if (programFull.toLowerCase().contains('bachelor of science in information technology')) {
          programAbbrev = 'BSIT';
        } else if (programFull.toLowerCase().contains('diploma in information technology')) {
          programAbbrev = 'DIT';
        } else {
          programAbbrev = programFull;
        }

        // Extract year number
        int yearNumber;
        if (yearLevelFull.toLowerCase().contains('1st')) {
          yearNumber = 1;
        } else if (yearLevelFull.toLowerCase().contains('2nd')) {
          yearNumber = 2;
        } else if (yearLevelFull.toLowerCase().contains('3rd')) {
          yearNumber = 3;
        } else if (yearLevelFull.toLowerCase().contains('4th')) {
          yearNumber = 4;
        } else {
          yearNumber = int.tryParse(yearLevelFull.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        }

        // Format as "BSIT 1-1", "DIT 2-1", etc.
        final programFormatted = '$programAbbrev $yearNumber-1';

        return StudentAttendance(
          id: attendanceId,
          eventId: eventId,
          studentNumber: studentNumber,
          lastName: lastName,
          firstName: firstName,
          program: programFormatted,
          yearLevel: yearNumber,
          timestamp: DateTime.now(),
          status: 'present',
        );
      }
    } catch (e) {
      return null;
    }
  }
  
  /// Simple JSON parser for QR code data
  static Map<String, dynamic> _parseJson(String jsonStr) {
    final Map<String, dynamic> result = {};
    
    // Remove outer braces and whitespace
    String content = jsonStr.trim();
    if (content.startsWith('{')) content = content.substring(1);
    if (content.endsWith('}')) content = content.substring(0, content.length - 1);
    
    // Split by comma (simple approach)
    final pairs = <String>[];
    int braceCount = 0;
    int quoteCount = 0;
    StringBuffer current = StringBuffer();
    
    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '"') quoteCount++;
      if (char == '{') braceCount++;
      if (char == '}') braceCount--;
      
      if (char == ',' && braceCount == 0 && quoteCount % 2 == 0) {
        pairs.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty) pairs.add(current.toString());
    
    // Parse each key-value pair
    for (final pair in pairs) {
      final colonIndex = pair.indexOf(':');
      if (colonIndex == -1) continue;
      
      String key = pair.substring(0, colonIndex).trim();
      String value = pair.substring(colonIndex + 1).trim();
      
      // Remove quotes
      if (key.startsWith('"')) key = key.substring(1);
      if (key.endsWith('"')) key = key.substring(0, key.length - 1);
      if (value.startsWith('"')) value = value.substring(1);
      if (value.endsWith('"')) value = value.substring(0, value.length - 1);
      
      result[key] = value;
    }
    
    return result;
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'studentNumber': studentNumber,
      'lastName': lastName,
      'firstName': firstName,
      'program': program,
      'yearLevel': yearLevel,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

  /// Create from database map
  factory StudentAttendance.fromMap(Map<String, dynamic> map) {
    return StudentAttendance(
      id: map['id'] as String,
      eventId: map['eventId'] as String,
      studentNumber: map['studentNumber'] as String,
      lastName: map['lastName'] as String,
      firstName: map['firstName'] as String,
      program: map['program'] as String,
      yearLevel: map['yearLevel'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: map['status'] as String,
    );
  }
}

/// Sorting options for attendance list
enum AttendanceSortOption {
  programYearLevel,
  checkInTime,
  alphabetical,
}

/// Extension for sorting
extension AttendanceListSorting on List<StudentAttendance> {
  /// Sort by program, year level, then alphabetically
  List<StudentAttendance> sortByProgramYearLevel() {
    final sorted = List<StudentAttendance>.from(this);
    sorted.sort((a, b) {
      // First by program
      final programCompare = a.program.compareTo(b.program);
      if (programCompare != 0) return programCompare;

      // Then by year level
      final yearCompare = a.yearLevel.compareTo(b.yearLevel);
      if (yearCompare != 0) return yearCompare;

      // Finally alphabetically by last name, then first name
      final lastNameCompare = a.lastName.compareTo(b.lastName);
      if (lastNameCompare != 0) return lastNameCompare;

      return a.firstName.compareTo(b.firstName);
    });
    return sorted;
  }

  /// Sort by check-in time (most recent first)
  List<StudentAttendance> sortByCheckInTime() {
    final sorted = List<StudentAttendance>.from(this);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }

  /// Sort alphabetically by last name, then first name
  List<StudentAttendance> sortAlphabetically() {
    final sorted = List<StudentAttendance>.from(this);
    sorted.sort((a, b) {
      final lastNameCompare = a.lastName.compareTo(b.lastName);
      if (lastNameCompare != 0) return lastNameCompare;
      return a.firstName.compareTo(b.firstName);
    });
    return sorted;
  }

  /// Group by program and year level
  Map<String, List<StudentAttendance>> groupByProgramYearLevel() {
    final Map<String, List<StudentAttendance>> grouped = {};
    
    for (final attendance in this) {
      final key = '${attendance.program} - Year ${attendance.yearLevel}';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(attendance);
    }

    // Sort each group alphabetically
    for (final key in grouped.keys) {
      grouped[key] = grouped[key]!.sortAlphabetically();
    }

    return grouped;
  }
}
