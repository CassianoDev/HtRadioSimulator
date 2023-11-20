class AudioPacket {
  final int channel;
  final String data; // String base64

  AudioPacket(this.channel, this.data);

  Map<String, dynamic> toJson() => {
    'channel': channel,
    'data': data,
  };

  static AudioPacket fromJson(Map<String, dynamic> json) => AudioPacket(
    json['channel'],
    json['data'],
  );
}