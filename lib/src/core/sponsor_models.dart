class Sponsor {
  Sponsor({
    required this.name,
    required this.amount,
    required this.time,
    this.message,
  });

  final String name;
  final double amount;
  final String time;
  final String? message;

  factory Sponsor.fromJson(Map<String, dynamic> json) {
    return Sponsor(
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      time: json['time'] as String? ?? '',
      message: json['message'] as String?,
    );
  }
}

class SponsorResponse {
  SponsorResponse({required this.sponsors});

  final List<Sponsor> sponsors;

  factory SponsorResponse.fromJson(Map<String, dynamic> json) {
    final sponsorsJson = json['sponsors'] as List? ?? [];
    return SponsorResponse(
      sponsors: sponsorsJson
          .whereType<Map>()
          .map((e) => Sponsor.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
