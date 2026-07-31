import '../application/arxiv_paper_mapper.dart';
import '../domain/paper.dart';
import '../domain/paper_repository.dart';
import '../domain/paper_source.dart';

/// A small, checked-in seed captured from arXiv OAI-PMH on 2026-07-31.
///
/// The app uses this offline seed at startup. A server-side sync job can later
/// replace it with records written by ArxivPaperSyncService.
class ArxivSeedRepository implements PaperRepository {
  const ArxivSeedRepository();

  @override
  List<PaperRecord> getAll() {
    return arxivSeedMetadata.map((metadata) {
      return metadata.toPaperRecord(
        relatedPapers: _relatedPapersFor(metadata),
      );
    }).toList(growable: false);
  }

  List<RelatedPaper> _relatedPapersFor(ArxivMetadata source) {
    final candidates = arxivSeedMetadata
        .where((candidate) => candidate.normalizedId != source.normalizedId)
        .map((candidate) {
      final sharedCategories = source.categories
          .where(candidate.categories.contains)
          .toList(growable: false);
      return (metadata: candidate, shared: sharedCategories);
    }).toList(growable: false)
      ..sort((a, b) {
        final sharedComparison = b.shared.length.compareTo(a.shared.length);
        if (sharedComparison != 0) return sharedComparison;
        return b.metadata.publishedAt.compareTo(a.metadata.publishedAt);
      });

    return candidates.take(3).map((candidate) {
      final shared = candidate.shared;
      return RelatedPaper(
        id: candidate.metadata.normalizedId,
        title: candidate.metadata.title,
        venue: candidate.metadata.journalReference ?? 'arXiv',
        relation: shared.isEmpty ? '同属近期研究' : '共同领域 ${shared.join(' / ')}',
      );
    }).toList(growable: false);
  }
}

final arxivSeedMetadata = <ArxivMetadata>[
  ArxivMetadata(
    id: '2402.06734',
    title:
        'Corruption Robust Offline Reinforcement Learning with Human Feedback',
    authors: [
      'Debmalya Mandal',
      'Andi Nika',
      'Parameswaran Kamalaruban',
      'Adish Singla',
      'Goran Radanović',
    ],
    abstractText:
        r'''We study data corruption robustness for reinforcement learning with human feedback (RLHF) in an offline setting. Given an offline dataset of pairs of trajectories along with feedback about human preferences, an $\varepsilon$-fraction of the pairs is corrupted (e.g., feedback flipped or trajectory features manipulated), capturing an adversarial attack or noisy human preferences. We aim to design algorithms that identify a near-optimal policy from the corrupted data, with provable guarantees. Existing theoretical works have separately studied the settings of corruption robust RL (learning from scalar rewards directly under corruption) and offline RLHF (learning from human feedback without corruption); however, they are inapplicable to our problem of dealing with corrupted data in offline RLHF setting. To this end, we design novel corruption robust offline RLHF methods under various assumptions on the coverage of the data-generating distributions. At a high level, our methodology robustifies an offline RLHF framework by first learning a reward model along with confidence sets and then learning a pessimistic optimal policy over the confidence set. Our key insight is that learning optimal policy can be done by leveraging an offline corruption-robust RL oracle in different ways (e.g., zero-order oracle or first-order oracle), depending on the data coverage assumptions. To our knowledge, ours is the first work that provides provable corruption robust offline RLHF methods.''',
    categories: ['cs.LG', 'cs.AI'],
    publishedAt: DateTime.utc(2026, 6, 29),
    updatedAt: DateTime.utc(2026, 7, 1),
  ),
  ArxivMetadata(
    id: '2404.01356',
    title: 'Perturbation Effects on Robustness and Individual Fairness',
    authors: [
      'Xuran Li',
      'Hao Xue',
      'Peng Wu',
      'Xingjun Ma',
      'Zhen Zhang',
      'Huaming Chen',
      'Flora D. Salim',
    ],
    abstractText:
        'Deep neural networks are vulnerable to adversarial perturbations that can simultaneously degrade prediction robustness and individual fairness across diverse application settings. However, existing evaluation protocols typically assess these dimensions in isolation, thereby obscuring critical failure modes. To bridge this gap, we formalize Robust Individual Fairness (RIF): under semantic-preserving (truth-condition-preserving) perturbations, predictions should remain both correct with respect to the ground truth and invariant across semantically equivalent individuals. To surface RIF violations in practice, we introduce RIFair, a black-box adversarial framework that leverages a decoupled perturbation strategy to construct semantically preserved yet unrobust and/or unfair instance pairs. Experiments across multiple model architectures and real-world textual datasets show that robustness-only or fairness-only metrics often miss Robust Biased and Unrobust Fair behaviors. RIFair reliably exposes these hidden vulnerabilities, supporting RIF as a necessary criterion for trustworthy model assessment. The experimental code is publicly available at https://github.com/Xuran-LI/RIFair.',
    categories: ['cs.LG', 'cs.AI', 'cs.CY'],
    publishedAt: DateTime.utc(2026, 6, 30),
    updatedAt: DateTime.utc(2026, 7, 1),
  ),
  ArxivMetadata(
    id: '2409.03500',
    title:
        'Quality Perceptions and Intended Engagement in Response to AI-Generated and AI-Assisted News',
    authors: [
      'Fabrizio Gilardi',
      'Sabrina Di Lorenzo',
      'Juri Ezzaini',
      'Beryl Santa',
      'Benjamin Streiff',
      'Eric Zurfluh',
      'Emma Hoes',
    ],
    abstractText:
        'The increasing use of artificial intelligence (AI) in news production raises important questions about how audiences perceive and respond to AI-generated journalism. This preregistered survey experiment (N = 599, German-speaking Switzerland) examines (i) perceptions of article quality (measured as credibility, readability, and expertise) across news excerpts that were human-written, AI-assisted, or fully AI-generated, and (ii) self-reported intentions to engage following disclosure of AI involvement. Participants rated two short news excerpts before learning how they had been produced. Articles across all conditions were evaluated similarly in perceived quality. After disclosure, participants in the AI-assisted and AI-generated conditions reported a higher willingness to continue reading their assigned articles compared to the control group, but future willingness to read AI-generated news did not differ across conditions. Overall, the findings suggest that readers assess AI-generated and human-written articles comparably in quality, while disclosure of AI use can momentarily increase curiosity or interest without yet changing longer-term reading intentions.',
    categories: ['cs.CY', 'cs.AI'],
    publishedAt: DateTime.utc(2026, 6, 17),
    updatedAt: DateTime.utc(2026, 7, 1),
  ),
  ArxivMetadata(
    id: '2410.12341',
    title:
        'Learning by Surprise: Adaptive Mitigation of Model Collapse in Large Language Models',
    authors: [
      'Daniele Gambetta',
      'Gizem Gezici',
      'Fosca Giannotti',
      'Dino Pedreschi',
      'Alistair Knott',
      'Luca Pappalardo',
    ],
    abstractText:
        'As AI-generated content increasingly populates the web, generative AI models are at growing risk of being trained on their own outputs, a process known as AI autophagy. This feedback loop has been shown to induce model collapse, typically characterized by a loss of diversity in generated content. However, existing work offers a limited understanding of this phenomenon and relies on mitigation strategies that assume access to human-authored data. In this paper, we conduct extensive simulations across multiple datasets and LLMs to address key gaps in the study of model collapse. First, we introduce model-intrinsic measures based on next-token probability distributions, showing that model collapse corresponds to an increasing concentration of probability mass on a small set of tokens. Second, we demonstrate that model collapse is also associated with a loss of common sense, as measured by a decline in commonsense inference accuracy. Third, we identify perplexity (a measure of model "surprise") as a key driver of collapse: fine-tuning on the least "surprising" documents leads to more severe degeneration. Building on this insight, we propose a perplexity-based filtering strategy that prioritizes high-surprise documents during fine-tuning. Unlike existing approaches, our method does not require distinguishing between human-authored and AI-generated content. Across datasets and LLM families, this strategy consistently mitigates model collapse, achieving performance comparable to, and in some cases better than, human-data baselines, while substantially reducing the concentration of next-token probabilities. Overall, our results provide a unified, model-centric understanding of model collapse and suggest practical, scalable strategies for training generative AI systems in increasingly synthetic environments.',
    categories: ['cs.CL', 'cs.AI'],
    publishedAt: DateTime.utc(2026, 6, 30),
    updatedAt: DateTime.utc(2026, 7, 1),
  ),
  ArxivMetadata(
    id: '2412.11439',
    title: 'Sampling Out-of-Distribution Chemical Spaces via Bayesian Flow',
    authors: ['Nianze Tao', 'Minori Abe'],
    abstractText:
        'Generating novel molecules with higher properties than the training space, namely the out-of-distribution generation, is important for de novo drug design. However, it is not easy for distribution learning-based models, for example diffusion models, to solve this challenge as these methods are designed to fit the distribution of training data as close as possible. In this paper, we show that Bayesian flow network, especially ChemBFN model, is capable of intrinsically generating high quality out-of-distribution samples that meet several scenarios. A reinforcement learning strategy is added to the ChemBFN and a controllable ordinary differential equation solver-like generating process is employed that accelerate the sampling processes. Most importantly, we introduce a semi-autoregressive strategy during training and inference that enhances the model performance and surpass the state-of-the-art models. A theoretical analysis of out-of-distribution generation in ChemBFN with semi-autoregressive approach is included as well.',
    categories: ['cs.LG', 'cs.AI', 'physics.chem-ph'],
    publishedAt: DateTime.utc(2026, 6, 8),
    updatedAt: DateTime.utc(2026, 7, 1),
  ),
  ArxivMetadata(
    id: '2502.00547',
    title:
        'Milmer: a Framework for Multiple Instance Learning based Multimodal Emotion Recognition',
    authors: [
      'Zaitian Wang',
      'Jian He',
      'Yu Liang',
      'Xiyuan Hu',
      'Tianhao Peng',
      'Kaixin Wang',
      'Jiakai Wang',
      'Chenlong Zhang',
      'Weili Zhang',
      'Shuang Niu',
      'Xiaoyang Xie',
    ],
    abstractText:
        'Emotions play a crucial role in human behavior and decision-making, making emotion recognition a key area of interest in human-computer interaction (HCI). This study addresses the challenges of emotion recognition by integrating facial expression analysis with electroencephalogram (EEG) signals, introducing a novel multimodal framework-Milmer. The proposed framework employs a transformer-based fusion approach to effectively integrate visual and physiological modalities. It consists of an EEG preprocessing module, a facial feature extraction and balancing module, and a cross-modal fusion module. To enhance visual feature extraction, we fine-tune a pre-trained Swin Transformer on emotion-related datasets. Additionally, a cross-attention mechanism is introduced to balance token representation across modalities, ensuring effective feature integration. A key innovation of this work is the adoption of a multiple instance learning (MIL) approach, which extracts meaningful information from multiple facial expression images over time, capturing critical temporal dynamics often overlooked in previous studies. Extensive experiments conducted on the DEAP dataset demonstrate the superiority of the proposed framework, achieving a classification accuracy of 96.72% in the four-class emotion recognition task. Ablation studies further validate the contributions of each module, highlighting the significance of advanced feature extraction and cross-modal fusion strategies in enhancing emotion recognition performance. Our code are available at https://github.com/liangyubuaa/Milmer.',
    categories: ['cs.CV', 'cs.AI', 'cs.HC'],
    publishedAt: DateTime.utc(2025, 2, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  ),
];
