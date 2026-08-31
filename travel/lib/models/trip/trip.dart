import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  // id dung de phan biet tung trip trong
  // database. final co nghia la id can phai
  // duoc assign khi tao object. Va no khong
  // the thay doi sau do.
  final String id;
  final String ownerId;
  final String destination;
  final double budget;
  final int days;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // constructor
  Trip({
    // required co nghia la bat buoc phai nhap
    // cai nay khi tao object.
    // this co nghia la object nay.
    required this.id,
    required this.ownerId,
    required this.destination,
    required this.budget,
    required this.days,
    required this.status,
    this.startDate,
    this.endDate,
    this.rating,
    this.createdAt,
    this.updatedAt,
  });

  // Convert Firestore data to Trip
  // Du lieu tren Firestore duoc luu duoi dang
  // Map<String, dynamic>
  // vi du nhu:
  /*
    {
      "title": "Japan Trip",
      "startDate": Timestamp(...),
      "location": "Tokyo"
    }
  */
  // Nhung minh muon Trip object khong phai la map
  // nen method nay convert Map to Trip object
  // cai nay la factory constructor.
  // no cho phep minh tao object tu mot thu gi do khong phai tu class nay
  factory Trip.fromMap(Map<String, dynamic> data, String id) {
    return Trip(
      id: id,
      ownerId: data['ownerId'] as String? ?? '',
      destination: data['destination'] as String? ?? '',
      budget: (data['budget'] as num?)?.toDouble() ?? 0,
      days: (data['days'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'draft',
      startDate: _dateFromFirestore(data['startDate']),
      endDate: _dateFromFirestore(data['endDate']),
      rating: (data['rating'] as num?)?.toInt(),
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  static DateTime? _dateFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  // Convert Trip to FireStore Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'destination': destination,
      'budget': budget,
      'days': days,
      'status': status,
      'startDate': startDate,
      'endDate': endDate,
      'rating': rating,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
