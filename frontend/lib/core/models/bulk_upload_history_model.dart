import 'package:flutter/material.dart';

class BulkUploadHistoryRecord {
  final String id;
  final String fileName;
  final String masterType; // 'Raw Materials' | 'Products'
  final String uploadedBy;
  final DateTime uploadedAt;
  final int totalRows;
  final int importedRows;
  final int errorRows;
  final int duplicateRows;
  final String status; // 'SUCCESS' | 'PARTIAL' | 'FAILED'
  final String? notes;

  const BulkUploadHistoryRecord({
    required this.id,
    required this.fileName,
    required this.masterType,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.totalRows,
    required this.importedRows,
    required this.errorRows,
    required this.duplicateRows,
    required this.status,
    this.notes,
  });

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        return const Color(0xFF16A34A);
      case 'PARTIAL':
        return const Color(0xFFEA580C);
      case 'FAILED':
      default:
        return const Color(0xFFDC2626);
    }
  }

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        return 'SUCCESS';
      case 'PARTIAL':
        return 'PARTIALLY IMPORTED';
      case 'FAILED':
      default:
        return 'FAILED';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'masterType': masterType,
        'uploadedBy': uploadedBy,
        'uploadedAt': uploadedAt.toIso8601String(),
        'totalRows': totalRows,
        'importedRows': importedRows,
        'errorRows': errorRows,
        'duplicateRows': duplicateRows,
        'status': status,
        'notes': notes,
      };

  factory BulkUploadHistoryRecord.fromJson(Map<String, dynamic> json) {
    return BulkUploadHistoryRecord(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      masterType: json['masterType'] as String,
      uploadedBy: json['uploadedBy'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      totalRows: (json['totalRows'] as num).toInt(),
      importedRows: (json['importedRows'] as num).toInt(),
      errorRows: (json['errorRows'] as num).toInt(),
      duplicateRows: (json['duplicateRows'] as num).toInt(),
      status: json['status'] as String,
      notes: json['notes'] as String?,
    );
  }
}
