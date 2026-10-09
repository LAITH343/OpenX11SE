class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, [this.preRelease = '']);

  static final _pattern = RegExp(
    r'^[vV]?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  );

  static AppVersion? tryParse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      match[4] ?? '',
    );
  }

  final int major;
  final int minor;
  final int patch;
  final String preRelease;

  bool get isPreRelease => preRelease.isNotEmpty;

  @override
  int compareTo(AppVersion other) {
    for (final (a, b) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      if (a != b) return a.compareTo(b);
    }
    return _comparePreRelease(preRelease, other.preRelease);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  bool operator <(AppVersion other) => compareTo(other) < 0;

  static int _comparePreRelease(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return 1;
    if (b.isEmpty) return -1;
    final left = a.split('.');
    final right = b.split('.');
    for (var i = 0; i < left.length && i < right.length; i++) {
      final x = int.tryParse(left[i]);
      final y = int.tryParse(right[i]);
      final result = switch ((x, y)) {
        (final int x, final int y) => x.compareTo(y),
        (int(), null) => -1,
        (null, int()) => 1,
        _ => left[i].compareTo(right[i]),
      };
      if (result != 0) return result;
    }
    return left.length.compareTo(right.length);
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() =>
      '$major.$minor.$patch${isPreRelease ? '-$preRelease' : ''}';
}

class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, this.size});

  final String name;
  final Uri url;
  final int? size;

  @override
  bool operator ==(Object other) =>
      other is ReleaseAsset &&
      other.name == name &&
      other.url == url &&
      other.size == size;

  @override
  int get hashCode => Object.hash(name, url, size);
}

class AppRelease {
  const AppRelease({
    required this.version,
    required this.tag,
    required this.installer,
    required this.checksum,
    this.notes = '',
    this.pageUrl,
    this.publishedAt,
  });

  final AppVersion version;
  final String tag;
  final ReleaseAsset installer;
  final ReleaseAsset checksum;
  final String notes;
  final Uri? pageUrl;
  final DateTime? publishedAt;

  @override
  bool operator ==(Object other) =>
      other is AppRelease &&
      other.version == version &&
      other.tag == tag &&
      other.installer == installer &&
      other.checksum == checksum &&
      other.notes == notes &&
      other.pageUrl == pageUrl &&
      other.publishedAt == publishedAt;

  @override
  int get hashCode => Object.hash(
    version,
    tag,
    installer,
    checksum,
    notes,
    pageUrl,
    publishedAt,
  );
}
