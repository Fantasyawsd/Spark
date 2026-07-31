import '../domain/paper.dart';
import '../domain/paper_repository.dart';

class DemoPaperRepository implements PaperRepository {
  const DemoPaperRepository();

  @override
  List<PaperRecord> getAll() => demoPapers;
}

const demoPapers = <PaperRecord>[
  PaperRecord(
    id: 'lora-2021',
    venue: 'ICLR 2024',
    title: 'LoRA: Low-Rank Adaptation of Large Language Models',
    authors:
        'Edward J. Hu, Yelong Shen, Phillip Wallis, Zeyuan Allen-Zhu, Yuanzhi Li, Shean Wang, Lu Wang, Weizhu Chen',
    firstAffiliation: 'Microsoft Research',
    topics: [
      'Large Language Models',
      'Parameter Efficient Fine-tuning',
      'PEFT',
    ],
    abstractText:
        'We propose Low-Rank Adaptation (LoRA), a simple yet highly effective method for fine-tuning large language models. Instead of updating all model parameters, LoRA injects trainable low-rank matrices into each layer of the Transformer architecture. This significantly reduces trainable parameters and GPU memory usage while maintaining comparable performance.',
    readMinutes: 12,
    citations: '1,234',
    likes: '1.2k',
    comments: '128',
    saves: '8.2k',
    shares: '256',
    accent: PaperAccent.blue,
  ),
  PaperRecord(
    id: 'mamba-2023',
    venue: 'NeurIPS 2024',
    title: 'Mamba: Linear-Time Sequence Modeling with Selective State Spaces',
    authors: 'Albert Gu, Tri Dao',
    firstAffiliation: 'Carnegie Mellon University',
    topics: ['State Space Models', 'Efficient Architecture', 'Long Context'],
    abstractText:
        'Mamba introduces a selective state space architecture that scales linearly with sequence length. The model combines hardware-aware parallel algorithms with input-dependent state transitions, delivering strong language modeling quality without attention or key-value caches.',
    readMinutes: 15,
    citations: '842',
    likes: '4.8k',
    comments: '306',
    saves: '6.1k',
    shares: '734',
    accent: PaperAccent.purple,
  ),
  PaperRecord(
    id: 'retrieval-long-context-2025',
    venue: 'ACL 2025',
    title: 'Rethinking Retrieval for Long-Context Language Models',
    authors: 'Mina Park, Leo Chen, Ananya Rao, Daniel Kim',
    firstAffiliation: 'Stanford University',
    topics: ['Retrieval-Augmented Generation', 'Long Context', 'Evaluation'],
    abstractText:
        'This work studies when retrieval still helps language models with very long context windows. A controlled benchmark reveals that selective retrieval improves factual consistency, lowers inference cost, and remains complementary to long-context reasoning.',
    readMinutes: 9,
    citations: '317',
    likes: '2.9k',
    comments: '184',
    saves: '3.7k',
    shares: '421',
    accent: PaperAccent.green,
  ),
  PaperRecord(
    id: 'qlora-2023',
    venue: 'NeurIPS 2023',
    title: 'QLoRA: Efficient Finetuning of Quantized LLMs',
    authors: 'Tim Dettmers, Artidoro Pagnoni, Ari Holtzman, Luke Zettlemoyer',
    firstAffiliation: 'University of Washington',
    topics: ['Quantization', 'Efficient Fine-tuning', 'LLM'],
    abstractText:
        'QLoRA reduces memory usage enough to fine-tune a 65B parameter model on a single GPU while preserving full fine-tuning task performance.',
    readMinutes: 11,
    citations: '3,607',
    likes: '6.3k',
    comments: '418',
    saves: '9.4k',
    shares: '1.1k',
    accent: PaperAccent.pink,
  ),
  PaperRecord(
    id: 'segment-anything-2023',
    venue: 'ICCV 2023',
    title: 'Segment Anything',
    authors: 'Alexander Kirillov, Eric Mintun, Nikhila Ravi, Hanzi Mao',
    firstAffiliation: 'Meta AI Research',
    topics: ['Computer Vision', 'Foundation Models', 'Segmentation'],
    abstractText:
        'The Segment Anything project introduces a promptable segmentation model and a large-scale mask dataset for general-purpose image segmentation.',
    readMinutes: 13,
    citations: '8,921',
    likes: '8.7k',
    comments: '692',
    saves: '11.2k',
    shares: '1.8k',
    accent: PaperAccent.azure,
  ),
  PaperRecord(
    id: 'swe-agent-2024',
    venue: 'ICML 2024',
    title:
        'SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering',
    authors: 'John Yang, Carlos E. Jimenez, Alexander Wettig, Kilian Lieret',
    firstAffiliation: 'Princeton University',
    topics: ['Agents', 'Software Engineering', 'Tool Use'],
    abstractText:
        'SWE-agent studies agent-computer interfaces that allow language models to navigate repositories, edit code, and resolve real GitHub issues.',
    readMinutes: 10,
    citations: '486',
    likes: '3.9k',
    comments: '275',
    saves: '4.6k',
    shares: '587',
    accent: PaperAccent.orange,
  ),
];
