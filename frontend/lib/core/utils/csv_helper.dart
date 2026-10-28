/// High-performance, zero-dependency CSV parser and serializer adhering to RFC 4180.
class CsvHelper {
  /// Parses standard CSV text into rows of columns.
  /// Handles quoted fields, embedded commas, double-quote escapes (""), and multiline cells.
  static List<List<String>> parseCsv(String input) {
    if (input.isEmpty) return [];

    // Strip BOM if present
    String text = input;
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }

    final List<List<String>> rows = [];
    List<String> currentRow = [];
    final StringBuffer currentCell = StringBuffer();
    bool insideQuotes = false;
    int i = 0;
    final int len = text.length;

    while (i < len) {
      final char = text[i];

      if (insideQuotes) {
        if (char == '"') {
          // Check for escaped quote ("")
          if (i + 1 < len && text[i + 1] == '"') {
            currentCell.write('"');
            i += 2;
            continue;
          } else {
            // Closing quote
            insideQuotes = false;
            i++;
            continue;
          }
        } else {
          currentCell.write(char);
          i++;
          continue;
        }
      } else {
        if (char == '"') {
          insideQuotes = true;
          i++;
          continue;
        } else if (char == ',') {
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          i++;
          continue;
        } else if (char == '\r') {
          // Check for CRLF
          if (i + 1 < len && text[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          if (currentRow.any((c) => c.isNotEmpty)) {
            rows.add(currentRow);
          }
          currentRow = [];
          i++;
          continue;
        } else if (char == '\n') {
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          if (currentRow.any((c) => c.isNotEmpty)) {
            rows.add(currentRow);
          }
          currentRow = [];
          i++;
          continue;
        } else {
          currentCell.write(char);
          i++;
          continue;
        }
      }
    }

    // Add trailing cell and row if present
    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString().trim());
      if (currentRow.any((c) => c.isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }

  /// Serializes rows into RFC 4180 CSV string with optional spreadsheet formula injection sanitization.
  static String toCsv(List<List<dynamic>> rows, {bool sanitizeForSpreadsheet = true}) {
    final StringBuffer buffer = StringBuffer();

    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (int c = 0; c < row.length; c++) {
        if (c > 0) buffer.write(',');

        String val = row[c]?.toString() ?? '';

        // Prevent spreadsheet formula injection on export
        if (sanitizeForSpreadsheet && val.isNotEmpty) {
          final firstChar = val[0];
          if (firstChar == '=' || firstChar == '+' || firstChar == '-' || firstChar == '@') {
            val = "'$val";
          }
        }

        if (val.contains(',') || val.contains('"') || val.contains('\n') || val.contains('\r')) {
          buffer.write('"${val.replaceAll('"', '""')}"');
        } else {
          buffer.write(val);
        }
      }
      buffer.write('\r\n');
    }

    return buffer.toString();
  }
}
