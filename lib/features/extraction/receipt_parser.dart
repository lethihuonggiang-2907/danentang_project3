// PURE DART - NO FLUTTER IMPORTS

/// Data transfer object containing extracted values from receipt OCR.
/// All fields are nullable so UI can prompt user to complete any missing data.
class ParsedReceiptResult {
  final int? amount;
  final DateTime? date;
  final String? merchant;
  final String rawText;

  const ParsedReceiptResult({
    this.amount,
    this.date,
    this.merchant,
    required this.rawText,
  });

  @override
  String toString() {
    return 'ParsedReceiptResult(amount: $amount, date: $date, merchant: $merchant)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedReceiptResult &&
        other.amount == amount &&
        other.date == date &&
        other.merchant == merchant;
  }

  @override
  int get hashCode => Object.hash(amount, date, merchant);
}

/// Pure Dart heuristic parser that analyzes raw OCR text from receipts and bank transfers.
class ReceiptParser {
  ReceiptParser._();

  /// Normalized list of keywords indicating the total transaction amount.
  static const List<String> _amountKeywords = <String>[
    'TONG CONG',
    'TONG TIEN',
    'THANH TIEN',
    'TONG THANH TOAN',
    'SO TIEN',
    'TOTAL',
    'AMOUNT',
    'TONG',
  ];

  /// Normalized list of keywords that should be IGNORED when searching for total amount
  /// (e.g. VAT, discount, money given by customer, change returned).
  static const List<String> _ignoreAmountKeywords = <String>[
    'TAM TINH',
    'VAT',
    'THUE',
    'TIEN KHACH DUA',
    'KHACH DUA',
    'TIEN THUA',
    'TRA LAI',
    'GIAM GIA',
    'CHIET KHAU',
    'PHI DICH VU',
    'PHI',
  ];

  /// Bank transfer recipient keywords.
  static const List<String> _transferRecipientKeywords = <String>[
    'TEN NGUOI THU HUONG',
    'NGUOI THU HUONG',
    'NGUOI NHAN',
    'TAI KHOAN NHAN',
    'DEN:',
  ];

  /// Header words to skip when detecting merchant names.
  static const List<String> _merchantSkipKeywords = <String>[
    'HOA DON',
    'PHIEU THANH TOAN',
    'PHIEU TINH TIEN',
    'RECEIPT',
    'BILL',
    'BIEN LAI',
    'GIAO DICH THANH CONG',
    'CHUYEN TIEN THANH CONG',
    'CHUYEN NHANH',
    'NAPAS',
    'VIETCOMBANK',
    'MB BANK',
    'MBBANK',
    'TECHCOMBANK',
    'MOMO',
    'NGAN HANG',
    'BANK',
  ];

  /// Main parse method. Pure function.
  static ParsedReceiptResult parse(String ocrText) {
    if (ocrText.trim().isEmpty) {
      return ParsedReceiptResult(
        amount: null,
        date: null,
        merchant: null,
        rawText: ocrText,
      );
    }

    final List<String> lines = ocrText
        .split(RegExp(r'\r?\n'))
        .map((String l) => l.trim())
        .where((String l) => l.isNotEmpty)
        .toList();

    final int? extractedAmount = _extractAmount(lines);
    final DateTime? extractedDate = _extractDate(lines);
    final String? extractedMerchant = _extractMerchant(lines);

    return ParsedReceiptResult(
      amount: extractedAmount,
      date: extractedDate,
      merchant: extractedMerchant,
      rawText: ocrText,
    );
  }

  // ==========================================
  // AMOUNT EXTRACTION HEURISTICS
  // ==========================================

  /// Checks whether a line contains email, website, phone number or tax code indicators.
  static bool _isContactOrMetadataLine(String line) {
    final String norm = _normalize(line);
    if (norm.contains('EMAIL') ||
        norm.contains('@') ||
        norm.contains('WEBSITE') ||
        norm.contains('WWW.') ||
        norm.contains('HTTP://') ||
        norm.contains('HTTPS://') ||
        norm.contains('MST') ||
        norm.contains('MA SO THUE') ||
        norm.contains('SDT') ||
        norm.contains('SĐT') ||
        norm.contains('DIEN THOAI') ||
        norm.contains('TEL') ||
        norm.contains('HOTLINE') ||
        norm.contains('PHONE')) {
      return true;
    }

    final String trimmed = line.trim();
    if (trimmed.startsWith('+84') || trimmed.startsWith('+')) {
      return true;
    }

    final String digitsOnly = line.replaceAll(RegExp(r'[^0-9]'), '');
    if ((digitsOnly.startsWith('0') && (digitsOnly.length == 10 || digitsOnly.length == 11)) ||
        (digitsOnly.startsWith('84') && (digitsOnly.length == 11 || digitsOnly.length == 12))) {
      return true;
    }

    return false;
  }

  /// Extracts Vietnamese unit-word amounts (e.g. "70 triệu VNĐ", "2 triệu", "1,5 triệu", "500 nghìn", "500k", "2tr").
  static List<int> _extractUnitWordAmountsFromLine(String line) {
    if (_isContactOrMetadataLine(line)) {
      return <int>[];
    }

    final String norm = _normalize(line);
    final RegExp unitRegex = RegExp(
      r'(?:^|[^\w])(\d+(?:[.,]\d+)?)\s*(TRIEU|TR|NGHIN|NGAN|K)\b',
      caseSensitive: false,
    );

    final List<int> results = <int>[];
    for (final RegExpMatch m in unitRegex.allMatches(norm)) {
      final String rawNum = m.group(1)!.replaceAll(',', '.');
      final double? numVal = double.tryParse(rawNum);
      if (numVal == null || numVal <= 0) continue;

      final String unit = m.group(2)!.toUpperCase();
      final double multiplier;
      if (unit == 'TRIEU' || unit == 'TR') {
        multiplier = 1000000;
      } else if (unit == 'NGHIN' || unit == 'NGAN' || unit == 'K') {
        multiplier = 1000;
      } else {
        continue;
      }

      final int finalAmount = (numVal * multiplier).round();
      if (finalAmount >= 1000 && finalAmount <= 9999999999) {
        results.add(finalAmount);
      }
    }
    return results;
  }

  static int? _extractUnitWordAmountFromLine(String line) {
    final List<int> amounts = _extractUnitWordAmountsFromLine(line);
    if (amounts.isEmpty) return null;
    return amounts.last;
  }

  static int? _extractAmount(List<String> lines) {
    // 1. Try keyword matching on lines first
    for (int i = 0; i < lines.length; i++) {
      final String rawLine = lines[i];
      final String normLine = _normalize(rawLine);

      // Check if line contains ignore keywords or contact metadata
      if (_hasAnyKeyword(normLine, _ignoreAmountKeywords) ||
          _isContactOrMetadataLine(rawLine)) {
        continue;
      }

      // Check if line contains a preferred amount keyword
      if (_hasAnyKeyword(normLine, _amountKeywords)) {
        // 1a. Try to extract standard numeric amount from the same line
        final int? sameLineAmount = _extractAmountFromLine(rawLine);
        if (sameLineAmount != null) {
          return sameLineAmount;
        }

        // 1b. Try unit-word amounts on the same line (e.g. "TỔNG CỘNG 70 triệu VNĐ")
        final int? sameLineUnitAmount = _extractUnitWordAmountFromLine(rawLine);
        if (sameLineUnitAmount != null) {
          return sameLineUnitAmount;
        }

        // 1c. If not found on same line, inspect the immediate next line (e.g. MB Bank / MoMo)
        if (i + 1 < lines.length) {
          final String nextLine = lines[i + 1];
          final String normNextLine = _normalize(nextLine);
          if (!_hasAnyKeyword(normNextLine, _ignoreAmountKeywords) &&
              !_isContactOrMetadataLine(nextLine)) {
            final int? nextLineAmount = _extractAmountFromLine(nextLine);
            if (nextLineAmount != null) {
              return nextLineAmount;
            }

            final int? nextLineUnitAmount = _extractUnitWordAmountFromLine(nextLine);
            if (nextLineUnitAmount != null) {
              return nextLineUnitAmount;
            }
          }
        }
      }
    }

    // 2. Fallback: Find the largest plausible amount in lines not marked as ignored or contact
    int? maxAmount;
    for (final String line in lines) {
      final String normLine = _normalize(line);
      if (_hasAnyKeyword(normLine, _ignoreAmountKeywords) ||
          _isContactOrMetadataLine(line)) {
        continue;
      }
      final List<int> candidates = <int>[
        ..._extractAllAmountsFromLine(line),
        ..._extractUnitWordAmountsFromLine(line),
      ];
      for (final int cand in candidates) {
        // Plausible VND amount: at least 1,000 VND and under 10 billion (max 10 digits)
        if (cand >= 1000 && cand <= 9999999999) {
          if (maxAmount == null || cand > maxAmount) {
            maxAmount = cand;
          }
        }
      }
    }

    return maxAmount;
  }

  /// Extracts the most prominent amount from a single line.
  static int? _extractAmountFromLine(String line) {
    final List<int> amounts = _extractAllAmountsFromLine(line);
    if (amounts.isEmpty) {
      return null;
    }
    // Usually the amount after the keyword is at the end or the largest
    return amounts.last;
  }

  /// Finds and parses all amount patterns in a line, with OCR noise correction.
  static List<int> _extractAllAmountsFromLine(String line) {
    if (_isContactOrMetadataLine(line)) {
      return <int>[];
    }

    final List<int> results = <int>[];

    String sanitized = line;

    // Mask out phone numbers (+84... or 0 followed by 9 to 10 digits or hotlines 1800/1900)
    sanitized = sanitized.replaceAll(
      RegExp(r'\+?84[\s.-]?[1-9]\d{1,3}[\s.-]?\d{3}[\s.-]?\d{3,4}'),
      ' ',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\b0[1-9]\d{1,2}[\s.-]?\d{3}[\s.-]?\d{3,4}\b'),
      ' ',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\b(?:1800|1900)[\s.-]?\d{4}\b'),
      ' ',
    );

    // Iteratively replace letter O/o when adjacent to digits or decimal points
    for (int iter = 0; iter < 4; iter++) {
      sanitized = sanitized.replaceAllMapped(
        RegExp(r'(\d|\.|\,)[oO]'),
        (Match m) => '${m[1]}0',
      );
      sanitized = sanitized.replaceAllMapped(
        RegExp(r'[oO](\d|\.|\,)'),
        (Match m) => '0${m[1]}',
      );
    }

    // Iteratively replace letter l/I when adjacent to digits or decimal points
    for (int iter = 0; iter < 4; iter++) {
      sanitized = sanitized.replaceAllMapped(
        RegExp(r'(\d|\.|\,)[lI]'),
        (Match m) => '${m[1]}1',
      );
      sanitized = sanitized.replaceAllMapped(
        RegExp(r'[lI](\d|\.|\,)'),
        (Match m) => '1${m[1]}',
      );
    }

    // Collapse spaces between digits ONLY when forming standard thousand groups
    // (1 to 3 digits followed by 3-digit groups, e.g. "150 000" -> "150000", "1 250 000" -> "1250000")
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b(\d{1,3})\s+(\d{3})(?:\s+(\d{3}))?(?!\s*\d)'),
      (Match m) => m.group(0)!.replaceAll(RegExp(r'\s+'), ''),
    );

    // Collapse spaces around punctuation: "150. 000" or "150 .000" -> "150.000"
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(\d)\s*([.,])\s*(\d)'),
      (Match m) => '${m[1]}${m[2]}${m[3]}',
    );

    // Stray spaces inside digits before decimal: "1 50.000" -> "150.000"
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b(\d)\s+(\d{2})\s*([.,])\s*(\d{3})\b'),
      (Match m) => '${m[1]}${m[2]}${m[3]}${m[4]}',
    );

    // Regex for standard currency formats:
    // 150,000 | 150.000 | 1.250.000 | 150 000 | 150000
    final RegExp moneyRegex = RegExp(
      r'(?:VND|VNĐ|đ|d)?\s*(\d{1,3}(?:[.,\s]\d{3})+(?:\s*(?:VND|VNĐ|đ|d))?|\d{4,9}(?:\s*(?:VND|VNĐ|đ|d))?)',
      caseSensitive: false,
    );

    final Iterable<RegExpMatch> matches = moneyRegex.allMatches(sanitized);
    for (final RegExpMatch match in matches) {
      final String rawMatch = match.group(1) ?? match.group(0)!;
      // Strip out currency words and separators
      final String digitsOnly = rawMatch.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.isNotEmpty) {
        final int? parsed = int.tryParse(digitsOnly);
        // Plausibility check: reject amounts over 10 digits
        if (parsed != null && parsed >= 1000 && parsed <= 9999999999) {
          results.add(parsed);
        }
      }
    }

    return results;
  }

  // ==========================================
  // DATE EXTRACTION & VALIDATION
  // ==========================================

  static DateTime? _extractDate(List<String> lines) {
    // Regex for date: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY, DD/MM/YY
    // Support optional spaces around delimiters (common in OCR e.g. "20 / 07 / 2030")
    // Followed optionally by time: HH:mm or HH:mm:ss
    final RegExp dateRegex = RegExp(
      r'(\b\d{1,2})\s*[\/\-\.]\s*(\d{1,2})\s*[\/\-\.]\s*(\d{2,4})(?:\s+(\d{1,2})\s*:\s*(\d{1,2})(?:\s*:\s*(\d{1,2}))?)?',
    );

    // Vietnamese textual date regex: "Ngày 20 tháng 07 năm 2030"
    final RegExp vnTextDateRegex = RegExp(
      r'(?:NGAY|NGÀY)?\s*(\b\d{1,2})\s*(?:THANG|THÁNG)\s*(\d{1,2})\s*(?:NAM|NĂM)\s*(\d{2,4})',
      caseSensitive: false,
    );

    for (final String line in lines) {
      // 1. Check standard slash/dash/dot formatted date
      final Iterable<RegExpMatch> matches = dateRegex.allMatches(line);
      for (final RegExpMatch m in matches) {
        final int day = int.parse(m.group(1)!);
        final int month = int.parse(m.group(2)!);
        int year = int.parse(m.group(3)!);
        if (year < 100) {
          year += 2000;
        }

        final int hour = m.group(4) != null ? int.parse(m.group(4)!) : 0;
        final int minute = m.group(5) != null ? int.parse(m.group(5)!) : 0;
        final int second = m.group(6) != null ? int.parse(m.group(6)!) : 0;

        // Basic boundary check
        if (month < 1 || month > 12 || day < 1 || day > 31) {
          continue;
        }
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59) {
          continue;
        }

        // Calendar verification to prevent roll-over (e.g. 31/02 -> March in Dart)
        try {
          final DateTime testDate = DateTime(year, month, day, hour, minute, second);
          if (testDate.year == year && testDate.month == month && testDate.day == day) {
            return testDate;
          }
        } catch (_) {
          continue;
        }
      }

      // 2. Check Vietnamese textual date (e.g. "Ngày 20 tháng 07 năm 2030")
      final Iterable<RegExpMatch> textMatches = vnTextDateRegex.allMatches(line);
      for (final RegExpMatch m in textMatches) {
        final int day = int.parse(m.group(1)!);
        final int month = int.parse(m.group(2)!);
        int year = int.parse(m.group(3)!);
        if (year < 100) {
          year += 2000;
        }

        if (month < 1 || month > 12 || day < 1 || day > 31) {
          continue;
        }

        try {
          final DateTime testDate = DateTime(year, month, day);
          if (testDate.year == year && testDate.month == month && testDate.day == day) {
            return testDate;
          }
        } catch (_) {
          continue;
        }
      }
    }

    return null;
  }

  // ==========================================
  // MERCHANT NAME EXTRACTION
  // ==========================================

  static String? _extractMerchant(List<String> lines) {
    // 1. Check for bank transfer beneficiary keywords
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      final String norm = _normalize(line);

      for (final String keyword in _transferRecipientKeywords) {
        if (norm.contains(keyword)) {
          // Check if recipient name is on the same line after keyword/colon
          final int kwIdx = norm.indexOf(keyword);
          final String afterKw = line.substring(kwIdx + keyword.length).replaceFirst(RegExp(r'^[\s\:\-]+'), '').trim();
          if (afterKw.isNotEmpty && !_isAddressOrTax(afterKw)) {
            return afterKw;
          }

          // Otherwise check immediate next line
          if (i + 1 < lines.length) {
            final String nextLine = lines[i + 1].trim();
            if (nextLine.isNotEmpty && !_isAddressOrTax(nextLine) && !_isKeywordLine(nextLine)) {
              return nextLine;
            }
          }
        }
      }
    }

    // 2. Standard receipt heuristic: inspect top lines
    final int searchLimit = lines.length < 6 ? lines.length : 6;
    for (int i = 0; i < searchLimit; i++) {
      final String candidate = lines[i];
      final String norm = _normalize(candidate);

      if (_isHeaderOrSkipWord(norm)) {
        continue;
      }
      if (_isAddressOrTax(norm)) {
        continue;
      }
      if (_isAllNumericOrCode(candidate)) {
        continue;
      }
      if (candidate.length >= 3) {
        return candidate;
      }
    }

    return null;
  }

  // ==========================================
  // HELPER UTILITIES
  // ==========================================

  static bool _hasAnyKeyword(String normalizedText, List<String> keywords) {
    for (final String kw in keywords) {
      if (normalizedText.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  static bool _isHeaderOrSkipWord(String normalizedLine) {
    for (final String skip in _merchantSkipKeywords) {
      if (normalizedLine.contains(skip)) {
        return true;
      }
    }
    return false;
  }

  static bool _isKeywordLine(String line) {
    final String norm = _normalize(line);
    return _hasAnyKeyword(norm, _amountKeywords) ||
        _hasAnyKeyword(norm, _ignoreAmountKeywords) ||
        _hasAnyKeyword(norm, _transferRecipientKeywords);
  }

  static bool _isAddressOrTax(String text) {
    final String norm = _normalize(text);
    return norm.contains('DIA CHI') ||
        norm.contains('D/C') ||
        norm.contains('DC:') ||
        norm.contains('ADDRESS') ||
        norm.contains('MA SO THUE') ||
        norm.contains('MST') ||
        norm.contains('DIEN THOAI') ||
        norm.contains('TEL') ||
        norm.contains('PHONE') ||
        norm.contains('HOTLINE');
  }

  static bool _isAllNumericOrCode(String text) {
    final String clean = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (clean.isEmpty) return true;
    final int digits = clean.replaceAll(RegExp(r'[^0-9]'), '').length;
    return digits / clean.length > 0.6;
  }

  /// Normalizes Vietnamese diacritics and converts to uppercase for reliable matching.
  static String _normalize(String input) {
    String text = input.toUpperCase();

    // Map common accented Vietnamese characters to ASCII
    const String vietnameseA = 'ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬ';
    const String vietnameseE = 'ÉÈẺẼẸÊẾỀỂỄỆ';
    const String vietnameseI = 'ÍÌỈĨỊ';
    const String vietnameseO = 'ÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢ';
    const String vietnameseU = 'ÚÙỦŨỤƯỨỪỬỮỰ';
    const String vietnameseY = 'ÝỲỶỸỴ';
    const String vietnameseD = 'Đ';

    for (int i = 0; i < vietnameseA.length; i++) {
      text = text.replaceAll(vietnameseA[i], 'A');
    }
    for (int i = 0; i < vietnameseE.length; i++) {
      text = text.replaceAll(vietnameseE[i], 'E');
    }
    for (int i = 0; i < vietnameseI.length; i++) {
      text = text.replaceAll(vietnameseI[i], 'I');
    }
    for (int i = 0; i < vietnameseO.length; i++) {
      text = text.replaceAll(vietnameseO[i], 'O');
    }
    for (int i = 0; i < vietnameseU.length; i++) {
      text = text.replaceAll(vietnameseU[i], 'U');
    }
    for (int i = 0; i < vietnameseY.length; i++) {
      text = text.replaceAll(vietnameseY[i], 'Y');
    }
    text = text.replaceAll(vietnameseD, 'D');

    return text;
  }
}
