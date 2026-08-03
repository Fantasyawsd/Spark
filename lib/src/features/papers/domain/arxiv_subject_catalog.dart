class ArxivSubject {
  const ArxivSubject({required this.code, required this.displayName});

  /// 真实 arXiv 分类编号，如 `cs.AI`。
  final String code;

  /// 面向用户的中文显示名称。
  final String displayName;
}

/// 结构化 arXiv 主题目录。
///
/// 首批主题来自开发计划的固定清单；后续主题必须来自结构化目录，
/// 不能只保存用户可见字符串。
class ArxivSubjectCatalog {
  const ArxivSubjectCatalog._();

  static const List<ArxivSubject> initialSubjects = [
    ArxivSubject(code: 'cs.AI', displayName: '人工智能'),
    ArxivSubject(code: 'cs.CL', displayName: '计算与语言'),
    ArxivSubject(code: 'cs.CV', displayName: '计算机视觉与模式识别'),
    ArxivSubject(code: 'cs.LG', displayName: '机器学习'),
  ];
}
