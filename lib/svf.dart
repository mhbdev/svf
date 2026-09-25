// Core
export 'src/svf_facade.dart';
export 'src/core/errors/svf_exception.dart';
export 'src/core/types/audio_format.dart';
export 'src/core/types/audio_source.dart';
export 'src/core/types/usage.dart';
export 'src/core/schema/svf_schema.dart';

// Language (Vercel AI SDK style)
export 'src/language/contracts/language_model.dart';
export 'src/language/contracts/message.dart';
export 'src/language/contracts/tool.dart';
export 'src/language/models/generation_result.dart';
export 'src/language/models/stream_result.dart';
export 'src/language/operations/generate_text.dart';
export 'src/language/operations/stream_text.dart';
export 'src/language/operations/generate_object.dart';
export 'src/language/operations/stream_object.dart';
export 'src/language/agent/agent_loop.dart';
export 'src/language/providers/gemini_language_model.dart';
export 'src/language/providers/openai_language_model.dart';
export 'src/language/providers/groq_language_model.dart';
export 'src/language/providers/ollama_language_model.dart';
export 'src/language/providers/custom_offline_language_model.dart';

// Audio
export 'src/audio/contracts/audio_recorder.dart';
export 'src/audio/models/amplitude.dart';
export 'src/audio/models/recorder_state.dart';
export 'src/audio/recorder/svf_recorder.dart';
export 'src/audio/storage/audio_store.dart';

// Visualizer & Waveforms
export 'src/visualizer/models/waveform_style.dart';
export 'src/visualizer/controller/waveform_controller.dart';
export 'src/visualizer/painter/waveform_painter.dart';
export 'src/visualizer/widgets/svf_live_waveform.dart';
export 'src/visualizer/widgets/svf_playback_waveform.dart';

// Speech (STT)
export 'src/speech/contracts/speech_to_text_model.dart';
export 'src/speech/models/transcription_chunk.dart';
export 'src/speech/models/transcription_options.dart';
export 'src/speech/models/transcription_result.dart';
export 'src/speech/operations/transcribe_audio.dart';
export 'src/speech/operations/stream_transcription.dart';
export 'src/speech/providers/device_speech_model.dart';
export 'src/speech/providers/whisper_cloud_model.dart';
export 'src/speech/providers/custom_offline_speech_model.dart';
export 'src/speech/router/speech_router.dart';

// Synthesis (TTS)
export 'src/synthesis/contracts/text_to_speech_model.dart';
export 'src/synthesis/operations/synthesize_speech.dart';
export 'src/synthesis/providers/openai_speech_model.dart';

// Downloader & Cache
export 'src/downloader/manifest.dart';
export 'src/downloader/progress.dart';
export 'src/downloader/cache.dart';
export 'src/downloader/resumable_downloader.dart';
export 'src/downloader/registry.dart';
