import '../ordin_operator.dart';

/// Result of one AI turn (local rule, on-device LLM, or remote).
class AiReply {
  AiReply({
    required this.text,
    required this.source,
    this.model,
    this.usedSituation = false,
    this.error,
    this.proposals = const [],
  });

  final String text;
  final AiSource source;
  final String? model;
  final bool usedSituation;
  final String? error;
  final List<OrdinActionProposal> proposals;

  bool get ok => error == null && text.isNotEmpty;
}

enum AiSource { localRules, onDevice, remote }

enum AiMode {
  /// Deterministic offline rules only (always available).
  localOnly,

  /// On-device GGUF when configured.
  onDeviceLlm,

  /// Try GGUF, fall back to local rules on failure.
  onDeviceWithFallback,

  /// Optional cloud/OpenAI-compatible endpoint.
  remote,

  /// Remote first, then local rules.
  remoteWithFallback,
}

class AiSettings {
  AiSettings({
    this.mode = AiMode.localOnly,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.localModelPath = '',
    this.localModelLabel = '',
    this.contextSize = 1024,
    this.threads = 2,
    this.maxTokens = 256,
    this.systemPreamble =
        'You are the offline Personal Life OS assistant. Use only the provided personal context. Be concise, practical, and honest. Never invent calendar events or balances.',
  });

  final AiMode mode;
  final String baseUrl;
  final String apiKey;
  final String model;
  final String localModelPath;
  final String localModelLabel;
  final int contextSize;
  final int threads;
  final int maxTokens;
  final String systemPreamble;

  bool get remoteConfigured =>
      baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  bool get localModelConfigured => localModelPath.trim().isNotEmpty;

  AiSettings copyWith({
    AiMode? mode,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? localModelPath,
    String? localModelLabel,
    int? contextSize,
    int? threads,
    int? maxTokens,
    String? systemPreamble,
  }) {
    return AiSettings(
      mode: mode ?? this.mode,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      localModelPath: localModelPath ?? this.localModelPath,
      localModelLabel: localModelLabel ?? this.localModelLabel,
      contextSize: contextSize ?? this.contextSize,
      threads: threads ?? this.threads,
      maxTokens: maxTokens ?? this.maxTokens,
      systemPreamble: systemPreamble ?? this.systemPreamble,
    );
  }

  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'localModelPath': localModelPath,
        'localModelLabel': localModelLabel,
        'contextSize': contextSize,
        'threads': threads,
        'maxTokens': maxTokens,
        'systemPreamble': systemPreamble,
      };

  static AiSettings fromJson(Map<String, Object?> m) {
    final modeName = '${m['mode'] ?? 'localOnly'}';
    final mode = AiMode.values.firstWhere(
      (e) => e.name == modeName,
      orElse: () => AiMode.localOnly,
    );
    return AiSettings(
      mode: mode,
      baseUrl: '${m['baseUrl'] ?? ''}',
      apiKey: '${m['apiKey'] ?? ''}',
      model: '${m['model'] ?? 'gpt-4o-mini'}',
      localModelPath: '${m['localModelPath'] ?? ''}',
      localModelLabel: '${m['localModelLabel'] ?? ''}',
      contextSize: (m['contextSize'] as int?) ?? 1024,
      threads: (m['threads'] as int?) ?? 2,
      maxTokens: (m['maxTokens'] as int?) ?? 256,
      systemPreamble: '${m['systemPreamble'] ?? AiSettings().systemPreamble}',
    );
  }
}
