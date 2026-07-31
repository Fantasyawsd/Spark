import '../domain/paper.dart';
import '../domain/paper_repository.dart';

class DemoPaperRepository implements PaperRepository {
  const DemoPaperRepository();

  @override
  List<PaperRecord> getAll() => demoPapers;
}

final demoPapers = <PaperRecord>[
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
        '''**Low-Rank Adaptation (LoRA)** is a parameter-efficient method for fine-tuning large language models.

Instead of updating every model parameter, LoRA injects trainable low-rank matrices into Transformer layers. The approach:

- freezes the pretrained model weights;
- substantially reduces trainable parameters and GPU memory;
- maintains performance comparable to full fine-tuning.''',
    chineseAbstractMarkdown:
        '''**LoRA** 是一种参数高效的大语言模型微调方法。它冻结预训练模型参数，并在 Transformer 层中注入可训练的低秩矩阵。

主要优势包括：

- 显著减少可训练参数；
- 降低训练显存和任务存储开销；
- 保持接近全量微调的性能。''',
    relatedPapersMarkdown: '''### 推荐阅读

1. **QLoRA** - 在 LoRA 基础上使用 4-bit 量化进一步降低显存。
2. **AdaLoRA** - 根据重要性动态分配低秩预算。
3. **DoRA** - 将权重更新分解为幅度与方向。''',
    readMinutes: 12,
    citations: '1,234',
    likes: '1.2k',
    comments: '128',
    saves: '8.2k',
    shares: '256',
    publishedAt: DateTime(2021),
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
    chineseAbstractMarkdown:
        '**Mamba** 提出选择性状态空间架构，以线性复杂度处理序列，并通过输入相关的状态转移提升表达能力。',
    relatedPapersMarkdown: '''### 推荐阅读

- **S4**：结构化状态空间序列模型。
- **Mamba-2**：状态空间对偶视角下的新架构。''',
    readMinutes: 15,
    citations: '842',
    likes: '4.8k',
    comments: '306',
    saves: '6.1k',
    shares: '734',
    publishedAt: DateTime(2023),
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
    chineseAbstractMarkdown:
        '本文研究超长上下文模型是否仍需要检索。实验表明，**选择性检索**可以提升事实一致性、降低推理成本，并与长上下文推理形成互补。',
    relatedPapersMarkdown: '''### 推荐阅读

- Retrieval-Augmented Generation
- Lost in the Middle
- Long-context evaluation surveys''',
    readMinutes: 9,
    citations: '317',
    likes: '2.9k',
    comments: '184',
    saves: '3.7k',
    shares: '421',
    publishedAt: DateTime(2025),
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
    chineseAbstractMarkdown:
        '**QLoRA** 使用 4-bit 量化冻结基座模型，并训练 LoRA 适配器，使单张 GPU 微调 65B 模型成为可能。',
    relatedPapersMarkdown: '''### 推荐阅读

- LoRA
- GPTQ
- DoRA''',
    readMinutes: 11,
    citations: '3,607',
    likes: '6.3k',
    comments: '418',
    saves: '9.4k',
    shares: '1.1k',
    publishedAt: DateTime(2023),
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
    chineseAbstractMarkdown:
        '**Segment Anything** 提出可提示的通用分割模型，并构建大规模掩码数据集，以支持零样本图像分割。',
    relatedPapersMarkdown: '''### 推荐阅读

- Mask R-CNN
- CLIP
- Segment Anything 2''',
    readMinutes: 13,
    citations: '8,921',
    likes: '8.7k',
    comments: '692',
    saves: '11.2k',
    shares: '1.8k',
    publishedAt: DateTime(2023),
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
    chineseAbstractMarkdown:
        '**SWE-agent** 研究面向语言模型的 Agent-Computer Interface，使模型能够浏览仓库、编辑代码并解决真实 GitHub 问题。',
    relatedPapersMarkdown: '''### 推荐阅读

- SWE-bench
- AutoCodeRover
- OpenHands''',
    readMinutes: 10,
    citations: '486',
    likes: '3.9k',
    comments: '275',
    saves: '4.6k',
    shares: '587',
    publishedAt: DateTime(2024),
  ),
];
