export '../../chat/application/chat_ai_service.dart';
export '../../chat/domain/chat_message.dart';

import '../../chat/application/chat_ai_service.dart';
import '../../chat/domain/chat_message.dart';

typedef PaperAiMessage = ChatMessage;
typedef PaperAiSource = ChatSource;
typedef PaperAiMessageStatus = ChatMessageStatus;
typedef PaperAiReasoningEffort = ChatReasoningEffort;
typedef ConfigurablePaperAiService = ConfigurableChatAiService;
typedef PaperAiService = ChatAiService;
typedef PaperAiStreamChunk = ChatStreamChunk;
typedef StreamingPaperAiService = StreamingChatAiService;
typedef CancellablePaperAiService = CancellableChatAiService;
typedef PaperAiException = ChatAiException;
typedef PaperAiCancelledException = ChatAiCancelledException;
