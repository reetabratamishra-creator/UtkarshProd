public with sharing class BWM_PhoneFormatter {
  public static String formatForMessaging(String rawPhone, String countryCode) {
    if (String.isBlank(rawPhone)) {
      return null;
    }

    String digits = rawPhone.replaceAll('[^0-9]', '');
    if (String.isBlank(digits)) {
      return null;
    }

    String normalizedCountryCode = String.isBlank(countryCode)
      ? '91'
      : countryCode.replaceAll('[^0-9]', '');

    if (digits.length() == 10) {
      return normalizedCountryCode + digits;
    }

    Integer expectedLength = 10 + normalizedCountryCode.length();
    if (
      digits.startsWith(normalizedCountryCode) &&
      digits.length() == expectedLength
    ) {
      return digits;
    }

    return null;
  }
}