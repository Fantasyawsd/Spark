export '../../chat/application/chat_conversation_controller.dart';

import '../../chat/application/chat_conversation_controller.dart';
import '../domain/paper.dart';
import 'paper_chat_context.dart';

typedef PaperAiRequestStatus = ChatRequestStatus;

class PaperAiConversationController extends ChatConversationController {
  PaperAiConversationController({
    required Paper paper,
    required super.service,
    super.webSearchService,
    super.sessionRepository,
  }) : super(
          context: PaperChatContext.fromPaper(paper),
        );
}
