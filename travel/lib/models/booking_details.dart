/// User-supplied booking information. Null times/locations remain unknown.
class BookingDetails {
  final String? localDate;
  final int? startMinutes;
  final String? timeZone;
  final String address;
  final String notes;
  final String reference;
  final String provider;
  final String contact;
  final bool confirmed;
  final List<String> warnings;

  const BookingDetails({this.localDate, this.startMinutes, this.timeZone,
    this.address = '', this.notes = '', this.reference = '',
    this.provider = '', this.contact = '', this.confirmed = false,
    this.warnings = const []});

  Map<String, dynamic> toMap() => {
    'localDate': localDate, 'startMinutes': startMinutes, 'timeZone': timeZone,
    'address': address, 'notes': notes, 'reference': reference,
    'provider': provider, 'contact': contact, 'confirmed': confirmed,
    'warnings': warnings,
  };

  factory BookingDetails.fromMap(Map<String, dynamic> data) => BookingDetails(
    localDate: data['localDate'] as String?,
    startMinutes: (data['startMinutes'] as num?)?.toInt(),
    timeZone: data['timeZone'] as String?,
    address: data['address'] as String? ?? '',
    notes: data['notes'] as String? ?? '',
    reference: data['reference'] as String? ?? '',
    provider: data['provider'] as String? ?? '',
    contact: data['contact'] as String? ?? '',
    confirmed: data['confirmed'] == true,
    warnings: (data['warnings'] as List? ?? []).whereType<String>().toList(),
  );
}
