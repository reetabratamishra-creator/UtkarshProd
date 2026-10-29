/**
 * @description   Resolves merge-field / parameter values from Lead, Opportunity, and
 *                related records for templates.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_FieldValueResolver {
  public static String resolve(Lead leadRecord, String fieldPath) {
    return resolveRecord(leadRecord, fieldPath);
  }

  public static String resolveRecord(SObject record, String fieldPath) {
    if (String.isBlank(fieldPath)) {
      return '';
    }

    if (fieldPath == BWM_MessagingConstants.FIELD_EMPTY) {
      return '';
    }

    if (fieldPath == BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_1) {
      return resolveCorporateSupportPhone(1);
    }

    if (fieldPath == BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_2) {
      return resolveCorporateSupportPhone(2);
    }

    if (fieldPath == BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_NAME_1) {
      return BWM_MessagingConstants.CORPORATE_SUPPORT_NAME_1_DEFAULT;
    }

    if (fieldPath == BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_NAME_2) {
      return BWM_MessagingConstants.CORPORATE_SUPPORT_NAME_2_DEFAULT;
    }

    if (
      fieldPath == BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_EMAIL_1 ||
      fieldPath == BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_EMAIL_2
    ) {
      return BWM_MessagingConstants.FALLBACK_CONTACT_EMAIL;
    }

    if (record == null) {
      return '';
    }

    if (fieldPath == BWM_EmailConstants.FIELD_PRODUCT_BRIEF) {
      return BWM_EmailProductBriefService.resolvePlainText(record);
    }

    if (fieldPath == BWM_MessagingConstants.FIELD_WHATSAPP_PRODUCT_BRIEF) {
      return BWM_MessagingProductBriefService.resolvePlainText(record);
    }

    if (fieldPath == BWM_MessagingConstants.FIELD_LOCATION) {
      return resolveLocation(record);
    }

    if (fieldPath == 'Owner.Name') {
      return resolveOwnerUserField(record, 'Name');
    }

    if (fieldPath == 'Owner.Email') {
      return resolveOwnerUserField(record, 'Email');
    }

    if (fieldPath == 'Owner.FirstName' || fieldPath == 'Owner.LastName') {
      return resolveOwnerUserField(record, fieldPath.replace('Owner.', ''));
    }

    if (fieldPath == 'Owner.Phone' || fieldPath == 'Owner.MobilePhone') {
      return resolveOwnerContactPhone(record);
    }

    if (fieldPath == 'Account.Name') {
      if (record instanceof Lead) {
        String companyName = nullToEmpty((String) record.get('Company'));
        if (String.isNotBlank(companyName)) {
          return companyName;
        }
        return nullToEmpty((String) record.get('Company_Name__c'));
      }

      SObject accountRecord = getRelatedRecord(record, 'Account');
      return accountRecord != null
        ? nullToEmpty((String) accountRecord.get('Name'))
        : '';
    }

    if (fieldPath == 'Account.Phone') {
      SObject accountRecord = getRelatedRecord(record, 'Account');
      return accountRecord != null
        ? nullToEmpty((String) accountRecord.get('Phone'))
        : '';
    }

    if (fieldPath == BWM_MessagingConstants.FIELD_OPPORTUNITY_LINK) {
      return resolveOpportunityLink(record);
    }

    if (fieldPath == 'Contact.Name') {
      SObject contactRecord = getRelatedRecord(record, 'Contact');
      return contactRecord != null
        ? nullToEmpty((String) contactRecord.get('Name'))
        : '';
    }

    if (fieldPath == 'Contact.FirstName') {
      SObject contactRecord = getRelatedRecord(record, 'Contact');
      return contactRecord != null
        ? nullToEmpty((String) contactRecord.get('FirstName'))
        : '';
    }

    if (fieldPath == 'Contact.LastName') {
      SObject contactRecord = getRelatedRecord(record, 'Contact');
      return contactRecord != null
        ? nullToEmpty((String) contactRecord.get('LastName'))
        : '';
    }

    if (fieldPath == 'Contact.Email') {
      SObject contactRecord = getRelatedRecord(record, 'Contact');
      return contactRecord != null
        ? nullToEmpty((String) contactRecord.get('Email'))
        : '';
    }

    if (fieldPath == 'DealerAccount__r.Phone') {
      SObject dealerAccount = getRelatedRecord(record, 'DealerAccount__r');
      return dealerAccount != null
        ? nullToEmpty((String) dealerAccount.get('Phone'))
        : '';
    }

    if (fieldPath == 'DealerAccount__r.Name') {
      SObject dealerAccount = getRelatedRecord(record, 'DealerAccount__r');
      return dealerAccount != null
        ? nullToEmpty((String) dealerAccount.get('Name'))
        : '';
    }

    if (fieldPath == 'FirstName' && record instanceof Opportunity) {
      return resolveOpportunityCustomerFirstName((Opportunity) record);
    }

    if (fieldPath == 'LastName' && record instanceof Opportunity) {
      return resolveOpportunityCustomerLastName((Opportunity) record);
    }

    if (fieldPath == 'Product_Category__c' && record instanceof Opportunity) {
      return BWM_OpportunityProductCategoryService.resolveAggregatedCategories(
        (Opportunity) record
      );
    }

    if (fieldPath == 'Email' && record instanceof Opportunity) {
      String oppEmail = nullToEmpty((String) record.get('Email__c'));
      if (String.isNotBlank(oppEmail)) {
        return oppEmail;
      }
      return resolveRecord(record, 'Contact.Email');
    }

    if (fieldPath == 'Email__c' && record instanceof Lead) {
      return nullToEmpty((String) record.get('Email'));
    }

    if (fieldPath == 'Email__c' && record instanceof Opportunity) {
      return nullToEmpty((String) record.get('Email__c'));
    }

    if (fieldPath == 'Phone__c' && record instanceof Lead) {
      String mobilePhone = nullToEmpty((String) record.get('MobilePhone'));
      if (String.isNotBlank(mobilePhone)) {
        return mobilePhone;
      }
      return nullToEmpty((String) record.get('Phone'));
    }

    if (fieldPath == 'Phone__c' && record instanceof Opportunity) {
      return nullToEmpty((String) record.get('Phone__c'));
    }

    if (fieldPath == 'Email' && record instanceof Lead) {
      return nullToEmpty((String) record.get('Email'));
    }

    if (fieldPath == 'Phone' && record instanceof Opportunity) {
      String oppPhone = nullToEmpty((String) record.get('Phone__c'));
      if (String.isNotBlank(oppPhone)) {
        return oppPhone;
      }
      return resolveRecord(record, 'Lead__r.Phone');
    }

    if (fieldPath.startsWith('Lead__r.')) {
      SObject leadRecord = getRelatedRecord(record, 'Lead__r');
      if (leadRecord == null) {
        return '';
      }
      return nullToEmpty(
        (String) leadRecord.get(fieldPath.replace('Lead__r.', ''))
      );
    }

    if (fieldPath == 'Quotation_Date__c' && record instanceof Opportunity) {
      Date quotationDate = (Date) record.get('Quotation_Date__c');
      if (quotationDate == null) {
        SObject syncedQuote = getRelatedRecord(record, 'SyncedQuote');
        if (syncedQuote != null && syncedQuote.get('CreatedDate') != null) {
          quotationDate = ((Datetime) syncedQuote.get('CreatedDate')).date();
        }
      }
      return quotationDate == null ? '' : quotationDate.format();
    }

    if (fieldPath == 'Quote_Number__c' && record instanceof Opportunity) {
      String quoteNumber = nullToEmpty((String) record.get('Quote_Number__c'));
      if (String.isNotBlank(quoteNumber)) {
        return quoteNumber;
      }
      SObject syncedQuote = getRelatedRecord(record, 'SyncedQuote');
      return syncedQuote != null
        ? nullToEmpty((String) syncedQuote.get('QuoteNumber'))
        : '';
    }

    if (fieldPath == 'CloseDate' && record instanceof Opportunity) {
      Date closeDate = (Date) record.get('CloseDate');
      return closeDate == null ? '' : closeDate.format();
    }

    if (fieldPath == 'Contact_Person_Name__c' && record instanceof Opportunity) {
      String contactPersonName = '';
      try {
        contactPersonName = nullToEmpty(
          (String) record.get('Contact_Person_Name__c')
        );
      } catch (Exception ex) {
        contactPersonName = '';
      }
      if (String.isNotBlank(contactPersonName)) {
        return contactPersonName;
      }
      return resolveOpportunityCustomerContactName((Opportunity) record);
    }

    if (fieldPath == 'City__c' && record instanceof Opportunity) {
      return resolveOpportunityCity((Opportunity) record);
    }

    if (fieldPath == 'State__c' && record instanceof Opportunity) {
      return resolveOpportunityState((Opportunity) record);
    }

    Object value;
    try {
      value = record.get(fieldPath.trim());
    } catch (Exception ex) {
      return '';
    }
    return value == null ? '' : String.valueOf(value);
  }

  public static List<String> resolveParams(
    Lead leadRecord,
    BWM_Template_Mapping__mdt mapping
  ) {
    return resolveParamsForRecord(leadRecord, mapping);
  }

  public static List<String> resolveParamsForRecord(
    SObject record,
    BWM_Template_Mapping__mdt mapping
  ) {
    List<String> fieldPaths = new List<String>{
      mapping.Param1_Field__c,
      mapping.Param2_Field__c,
      mapping.Param3_Field__c,
      mapping.Param4_Field__c,
      mapping.Param5_Field__c,
      mapping.Param6_Field__c,
      mapping.Param7_Field__c,
      mapping.Param8_Field__c
    };
    List<String> params = new List<String>();

    for (String fieldPath : fieldPaths) {
      params.add(
        String.isBlank(fieldPath) ? '' : resolveRecord(record, fieldPath)
      );
    }

    // Do not backfill corporate support phones with name/company defaults.
    if (shouldBackfillFirstNameWithLastName(fieldPaths[0], params[0], record)) {
      Lead leadRecord = (Lead) record;
      params[0] = String.isNotBlank(leadRecord.LastName)
        ? leadRecord.LastName
        : 'Customer';
    } else if (
      shouldBackfillOpportunityName(fieldPaths[0], params[0], record)
    ) {
      Opportunity opportunityRecord = (Opportunity) record;
      params[0] = String.isNotBlank(opportunityRecord.Name)
        ? opportunityRecord.Name
        : 'Customer';
    }

    if (shouldBackfillCompanyName(fieldPaths[1], params[1], record)) {
      if (record instanceof Lead) {
        params[1] = resolveRecord(record, 'Company');
        if (String.isBlank(params[1])) {
          params[1] = resolveRecord(record, 'Company_Name__c');
        }
      } else {
        params[1] = resolveRecord(record, 'Account.Name');
      }
    }

    if (
      String.isNotBlank(fieldPaths[3]) &&
      String.isBlank(params[3]) &&
      fieldPaths[3] == 'Product_Category__c'
    ) {
      params[3] = resolveRecord(record, 'Department_Name__c');
    }

    for (Integer i = 0; i < params.size(); i++) {
      if (String.isNotBlank(fieldPaths[i])) {
        params[i] = normalizeMappedParam(record, fieldPaths[i], params[i]);
      }
    }

    for (Integer i = 0; i < params.size(); i++) {
      if (String.isBlank(fieldPaths[i])) {
        params[i] = '';
        continue;
      }
      // Keep owner / corporate support phones blank when missing — never NA.
      // EMPTY token must stay blank for trailing optional template slots.
      if (
        fieldPaths[i] == 'Owner.Phone' ||
        fieldPaths[i] == 'Owner.MobilePhone' ||
        fieldPaths[i] == BWM_MessagingConstants.FIELD_EMPTY ||
        isCorporateSupportPhoneField(fieldPaths[i])
      ) {
        continue;
      }
      params[i] = normalizeTemplateParam(params[i]);
    }

    Integer lastMappedIndex = -1;
    for (Integer i = 0; i < fieldPaths.size(); i++) {
      if (String.isNotBlank(fieldPaths[i])) {
        lastMappedIndex = i;
      }
    }
    while (params.size() > lastMappedIndex + 1) {
      params.remove(params.size() - 1);
    }

    return params;
  }

  public static String resolveDepartmentName(SObject record) {
    String departmentName = resolveRecord(record, 'Department_Name__c');
    return String.isBlank(departmentName) ? null : departmentName;
  }

  private static String nullToEmpty(String value) {
    return value == null ? '' : value;
  }

  private static SObject getRelatedRecord(SObject record, String relationshipName) {
    try {
      return record.getSObject(relationshipName);
    } catch (Exception ex) {
      return null;
    }
  }

  private static String normalizeMappedParam(
    SObject record,
    String fieldPath,
    String rawValue
  ) {
    if (fieldPath == BWM_MessagingConstants.FIELD_EMPTY) {
      return '';
    }

    if (fieldPath == 'Owner.Email') {
      String emailValue = String.isBlank(rawValue)
        ? resolveRecord(record, 'Owner.Email')
        : rawValue;
      return resolveEmailContactValue(record, emailValue);
    }

    if (fieldPath == 'Owner.Phone' || fieldPath == 'Owner.MobilePhone') {
      // Owner contact only — never Lead phone. Blank if owner has no phone.
      String ownerPhone = resolveOwnerContactPhone(record);
      return String.isBlank(ownerPhone) ? '' : ownerPhone.trim();
    }

    if (isCorporateSupportPhoneField(fieldPath)) {
      // User Mobile/Phone only — blank stays blank (no NA, no settings number).
      return String.isBlank(rawValue) ? '' : rawValue.trim();
    }

    return normalizeTemplateParam(rawValue);
  }

  private static String resolveOwnerContactPhone(SObject record) {
    if (record == null) {
      return '';
    }

    Id ownerId = null;
    try {
      ownerId = (Id) record.get('OwnerId');
    } catch (Exception ex) {
      ownerId = null;
    }

    if (ownerId != null && ownerId.getSobjectType() == User.SObjectType) {
      List<User> owners = [
        SELECT Phone, MobilePhone
        FROM User
        WHERE Id = :ownerId
        LIMIT 1
      ];
      if (!owners.isEmpty()) {
        // Prefer mobile — this is the number shown to customers as the expert contact.
        String mobile = nullToEmpty(owners[0].MobilePhone);
        if (String.isNotBlank(mobile)) {
          return mobile;
        }
        String phone = nullToEmpty(owners[0].Phone);
        if (String.isNotBlank(phone)) {
          return phone;
        }
      }
    }

    SObject ownerRecord = getRelatedRecord(record, 'Owner');
    if (ownerRecord != null) {
      try {
        String mobile = nullToEmpty((String) ownerRecord.get('MobilePhone'));
        if (String.isNotBlank(mobile)) {
          return mobile;
        }
      } catch (Exception ex) {
        // Polymorphic Owner (Queue) may not expose MobilePhone.
      }
      try {
        String phone = nullToEmpty((String) ownerRecord.get('Phone'));
        if (String.isNotBlank(phone)) {
          return phone;
        }
      } catch (Exception ex) {
        // Ignore missing Phone on non-User owners.
      }
    }

    return '';
  }

  /**
   * @description SMS phone-slot value: Owner Mobile/Phone only. If both are blank,
   *              return blank — never Owner.Name. Non-name literals (static numbers)
   *              are kept.
   */
  public static String resolveSmsOwnerPhoneSlot(
    SObject record,
    String currentValue
  ) {
    String ownerPhone = resolveRecord(record, 'Owner.Phone');
    if (String.isNotBlank(ownerPhone)) {
      return ownerPhone.trim();
    }

    if (String.isBlank(currentValue)) {
      return '';
    }

    String trimmed = currentValue.trim();
    String ownerName = resolveRecord(record, 'Owner.Name');
    if (
      String.isNotBlank(ownerName) &&
      ownerName.trim().equalsIgnoreCase(trimmed)
    ) {
      return '';
    }

    String digitsOnly = trimmed.replaceAll('[^0-9]', '');
    return digitsOnly.length() >= 10 ? trimmed : '';
  }

  private static String safeGetField(SObject record, String fieldPath) {
    if (record == null || String.isBlank(fieldPath)) {
      return '';
    }
    try {
      Object value = record.get(fieldPath.trim());
      return value == null ? '' : String.valueOf(value);
    } catch (Exception ex) {
      return '';
    }
  }

  private static String safeResolveRecord(SObject record, String fieldPath) {
    try {
      return resolveRecord(record, fieldPath);
    } catch (Exception ex) {
      return '';
    }
  }

  private static String resolveEmailContactValue(SObject record, String rawValue) {
    String sanitized = sanitizeEmailParam(rawValue);
    if (sanitized != 'NA') {
      return sanitized;
    }

    String ownerEmail = sanitizeEmailParam(resolveRecord(record, 'Owner.Email'));
    if (ownerEmail != 'NA') {
      return ownerEmail;
    }

    return BWM_MessagingConstants.FALLBACK_CONTACT_EMAIL;
  }

  private static String sanitizeEmailParam(String email) {
    if (String.isBlank(email)) {
      return 'NA';
    }

    String normalized = email.trim().toLowerCase();
    if (normalized.contains('example.com') || !normalized.contains('@')) {
      return 'NA';
    }
    if (normalized.endsWith('.invalid')) {
      return email.trim().replaceAll('(?i)\\.invalid$', '');
    }

    return email.trim();
  }

  private static String normalizePhoneParam(String phone) {
    if (String.isBlank(phone)) {
      return 'NA';
    }
    return phone.trim();
  }

  private static String normalizeTemplateParam(String value) {
    return String.isBlank(value) ? 'NA' : value.trim();
  }

  private static String resolveOwnerUserField(SObject record, String fieldName) {
    SObject ownerRecord = getRelatedRecord(record, 'Owner');
    if (ownerRecord != null) {
      String value = nullToEmpty((String) ownerRecord.get(fieldName));
      if (String.isNotBlank(value)) {
        return value;
      }
    }

    Id ownerId = (Id) record.get('OwnerId');
    if (ownerId == null || ownerId.getSobjectType() != User.SObjectType) {
      return '';
    }

    List<User> owners = [
      SELECT FirstName, LastName, Name, Email, Phone, MobilePhone
      FROM User
      WHERE Id = :ownerId
      LIMIT 1
    ];
    if (owners.isEmpty()) {
      return '';
    }
    return nullToEmpty((String) owners[0].get(fieldName));
  }

  private static String resolveLocation(SObject record) {
    String city = safeResolveRecord(record, 'City__c');
    if (String.isBlank(city)) {
      city = safeGetField(record, 'City');
    }
    String state = safeResolveRecord(record, 'State__c');
    if (String.isBlank(state)) {
      state = safeGetField(record, 'State');
    }

    if (String.isNotBlank(city) && String.isNotBlank(state)) {
      return city.trim() + ', ' + state.trim();
    }
    if (String.isNotBlank(city)) {
      return city.trim();
    }
    return String.isNotBlank(state) ? state.trim() : '';
  }

  private static Boolean isCorporateSupportPhoneField(String fieldPath) {
    return fieldPath == BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_1 ||
      fieldPath == BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_2;
  }

  private static Boolean isOwnerContactField(String fieldPath) {
    return fieldPath == 'Owner.Name' ||
      fieldPath == 'Owner.FirstName' ||
      fieldPath == 'Owner.LastName' ||
      fieldPath == 'Owner.Email' ||
      fieldPath == 'Owner.Phone' ||
      fieldPath == 'Owner.MobilePhone';
  }

  private static Boolean shouldBackfillFirstNameWithLastName(
    String fieldPath,
    String paramValue,
    SObject record
  ) {
    return record instanceof Lead &&
      fieldPath == 'FirstName' &&
      String.isBlank(paramValue);
  }

  private static Boolean shouldBackfillOpportunityName(
    String fieldPath,
    String paramValue,
    SObject record
  ) {
    return record instanceof Opportunity &&
      fieldPath == 'FirstName' &&
      String.isBlank(paramValue);
  }

  private static Boolean shouldBackfillCompanyName(
    String fieldPath,
    String paramValue,
    SObject record
  ) {
    if (String.isBlank(fieldPath) || String.isNotBlank(paramValue)) {
      return false;
    }
    if (isCorporateSupportPhoneField(fieldPath) || isOwnerContactField(fieldPath)) {
      return false;
    }

    if (record instanceof Lead) {
      return fieldPath == 'Company' || fieldPath == 'Company_Name__c';
    }

    return record instanceof Opportunity && fieldPath == 'Account.Name';
  }

  private static Map<String, String> corporateSupportPhoneByName;

  private static String resolveCorporateSupportPhone(Integer contactNumber) {
    String userName = contactNumber == 1
      ? BWM_MessagingConstants.CORPORATE_SUPPORT_NAME_1_DEFAULT
      : BWM_MessagingConstants.CORPORATE_SUPPORT_NAME_2_DEFAULT;
    // Mobile → Phone from User only; blank if both empty (no settings fallback).
    return resolveUserMobileOrPhoneByName(userName);
  }

  private static String resolveUserMobileOrPhoneByName(String userName) {
    if (String.isBlank(userName)) {
      return '';
    }

    if (corporateSupportPhoneByName == null) {
      corporateSupportPhoneByName = new Map<String, String>();
    }
    if (corporateSupportPhoneByName.containsKey(userName)) {
      return corporateSupportPhoneByName.get(userName);
    }

    List<User> users = [
      SELECT Phone, MobilePhone
      FROM User
      WHERE Name = :userName AND IsActive = true
      LIMIT 1
    ];

    String resolved = '';
    if (!users.isEmpty()) {
      String rawPhone = String.isNotBlank(users[0].MobilePhone)
        ? users[0].MobilePhone
        : users[0].Phone;
      resolved = formatCorporateSupportPhone(rawPhone);
    }
    corporateSupportPhoneByName.put(userName, resolved);
    return resolved;
  }

  private static String formatCorporateSupportPhone(String rawPhone) {
    if (String.isBlank(rawPhone)) {
      return '';
    }
    String digits = rawPhone.replaceAll('[^0-9]', '');
    if (String.isBlank(digits)) {
      return '';
    }
    // WhatsApp template shows 10-digit Indian mobile.
    if (digits.length() >= 10) {
      return digits.substring(digits.length() - 10);
    }
    return digits;
  }

  private static String resolveOpportunityLink(SObject record) {
    if (record == null || !(record instanceof Opportunity) || record.Id == null) {
      return '';
    }

    return URL.getOrgDomainUrl().toExternalForm() +
      '/lightning/r/Opportunity/' +
      String.valueOf(record.Id) +
      '/view';
  }

  private static String resolveOpportunityContactName(Opportunity opportunityRecord) {
    if (opportunityRecord == null || opportunityRecord.ContactId == null) {
      return '';
    }

    List<Contact> contacts = [
      SELECT Name
      FROM Contact
      WHERE Id = :opportunityRecord.ContactId
      LIMIT 1
    ];
    return contacts.isEmpty() ? '' : nullToEmpty(contacts[0].Name);
  }

  private static String resolveOpportunityCustomerContactName(
    Opportunity opportunityRecord
  ) {
    String contactName = resolveOpportunityContactName(opportunityRecord);
    if (String.isNotBlank(contactName)) {
      return contactName;
    }

    String firstName = resolveOpportunityCustomerFirstName(opportunityRecord);
    String lastName = resolveOpportunityCustomerLastName(opportunityRecord);
    if (String.isNotBlank(firstName) && String.isNotBlank(lastName)) {
      return firstName.trim() + ' ' + lastName.trim();
    }
    if (String.isNotBlank(firstName)) {
      return firstName.trim();
    }
    return lastName.trim();
  }

  private static String resolveOpportunityCity(Opportunity opportunityRecord) {
    String city = safeGetField(opportunityRecord, 'City__c');
    if (String.isBlank(city)) {
      city = safeGetField(opportunityRecord, 'City');
    }
    return String.isNotBlank(city) ? city.trim() : '';
  }

  private static String resolveOpportunityState(Opportunity opportunityRecord) {
    String state = safeGetField(opportunityRecord, 'State__c');
    if (String.isBlank(state)) {
      state = safeGetField(opportunityRecord, 'State');
    }
    return String.isNotBlank(state) ? state.trim() : '';
  }

  private static String resolveOpportunityCustomerFirstName(Opportunity opportunityRecord) {
    String contactFirstName = resolveOpportunityContactField(
      opportunityRecord,
      'FirstName'
    );
    if (String.isNotBlank(contactFirstName)) {
      return contactFirstName;
    }

    String leadFirstName = resolveRecord(opportunityRecord, 'Lead__r.FirstName');
    if (String.isNotBlank(leadFirstName)) {
      return leadFirstName;
    }

    String contactPersonName = '';
    try {
      contactPersonName = nullToEmpty(
        (String) opportunityRecord.get('Contact_Person_Name__c')
      );
    } catch (Exception ex) {
      contactPersonName = '';
    }
    if (String.isNotBlank(contactPersonName)) {
      return firstTokenFromContactPersonName(contactPersonName);
    }

    return '';
  }

  private static String resolveOpportunityCustomerLastName(Opportunity opportunityRecord) {
    String contactLastName = resolveOpportunityContactField(
      opportunityRecord,
      'LastName'
    );
    if (String.isNotBlank(contactLastName)) {
      return contactLastName;
    }

    String leadLastName = resolveRecord(opportunityRecord, 'Lead__r.LastName');
    if (String.isNotBlank(leadLastName)) {
      return leadLastName;
    }

    String contactPersonName = '';
    try {
      contactPersonName = nullToEmpty(
        (String) opportunityRecord.get('Contact_Person_Name__c')
      );
    } catch (Exception ex) {
      contactPersonName = '';
    }
    if (String.isNotBlank(contactPersonName)) {
      return remainingTokensFromContactPersonName(contactPersonName);
    }

    return '';
  }

  private static String resolveOpportunityContactField(
    Opportunity opportunityRecord,
    String fieldName
  ) {
    if (opportunityRecord == null) {
      return '';
    }

    Id contactId = null;
    try {
      contactId = (Id) opportunityRecord.get('ContactId');
    } catch (Exception ex) {
      contactId = null;
    }

    if (contactId == null) {
      return '';
    }

    List<Contact> contacts = [
      SELECT FirstName, LastName, Email
      FROM Contact
      WHERE Id = :contactId
      LIMIT 1
    ];
    if (contacts.isEmpty()) {
      return '';
    }
    return nullToEmpty((String) contacts[0].get(fieldName));
  }

  private static String firstTokenFromContactPersonName(String contactPersonName) {
    if (String.isBlank(contactPersonName)) {
      return '';
    }

    List<String> nameParts = contactPersonName.trim().split('\\s+');
    return nameParts.isEmpty() ? '' : nameParts[0];
  }

  private static String remainingTokensFromContactPersonName(
    String contactPersonName
  ) {
    if (String.isBlank(contactPersonName)) {
      return '';
    }

    String trimmedName = contactPersonName.trim();
    Integer spaceIndex = trimmedName.indexOf(' ');
    if (spaceIndex < 0) {
      return '';
    }
    return trimmedName.substring(spaceIndex + 1).trim();
  }

  @TestVisible
  static void clearCorporateSupportPhoneCache() {
    corporateSupportPhoneByName = null;
  }
}