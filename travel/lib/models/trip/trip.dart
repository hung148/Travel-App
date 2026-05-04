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
      ownerId: data['ownerId'],
      destination: data['destination'],
      budget: data['budget'],
      days: data['days'],
      status: data['status'],
      startDate: data['startDate'] != null ? (data['startDate'] as DateTime) : null,
      endDate: data['endDate'] != null ? (data['endDate'] as DateTime) : null,
      rating: data['rating'],
    );
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
    };
  }
}