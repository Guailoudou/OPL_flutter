class SemVer implements Comparable<SemVer> {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;

  const SemVer(this.major, this.minor, this.patch, [this.preRelease]);

  factory SemVer.parse(String version) {
    var v = version.trim();
    if (v.startsWith('v')) v = v.substring(1);

    final preIdx = v.indexOf('-');
    String? pre;
    if (preIdx != -1) {
      pre = v.substring(preIdx + 1);
      v = v.substring(0, preIdx);
    }

    final parts = v.split('.');
    final major = int.tryParse(parts[0]) ?? 0;
    final minor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final patch = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

    return SemVer(major, minor, patch, pre);
  }

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    // Pre-release versions have lower precedence than release
    if (preRelease == null && other.preRelease == null) return 0;
    if (preRelease == null) return 1;
    if (other.preRelease == null) return -1;
    return preRelease!.compareTo(other.preRelease!);
  }

  bool operator >(SemVer other) => compareTo(other) > 0;
  bool operator <(SemVer other) => compareTo(other) < 0;
  bool operator >=(SemVer other) => compareTo(other) >= 0;
  bool operator <=(SemVer other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is SemVer &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch &&
      preRelease == other.preRelease;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    return preRelease != null ? '$base-$preRelease' : base;
  }
}
