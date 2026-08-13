class ArxivSubject {
  const ArxivSubject({required this.code, required this.displayName});

  /// 真实 arXiv 分类编号，如 `cs.AI`。
  final String code;

  /// 面向用户的中文显示名称。
  final String displayName;
}

/// 结构化 arXiv 主题目录。
///
/// 覆盖 arXiv 官方计算机科学（cs.*）全部 40 个分类，按官方字母序排列；
/// 后续主题必须来自结构化目录，不能只保存用户可见字符串。
class ArxivSubjectCatalog {
  const ArxivSubjectCatalog._();

  static List<String> get codes => [
        for (final subject in initialSubjects) subject.code,
      ];

  static const List<ArxivSubject> initialSubjects = [
    ArxivSubject(code: 'cs.AI', displayName: '人工智能'),
    ArxivSubject(code: 'cs.AR', displayName: '硬件架构'),
    ArxivSubject(code: 'cs.CC', displayName: '计算复杂性'),
    ArxivSubject(code: 'cs.CE', displayName: '计算工程、金融与科学'),
    ArxivSubject(code: 'cs.CG', displayName: '计算几何'),
    ArxivSubject(code: 'cs.CL', displayName: '计算与语言'),
    ArxivSubject(code: 'cs.CR', displayName: '密码学与安全'),
    ArxivSubject(code: 'cs.CV', displayName: '计算机视觉与模式识别'),
    ArxivSubject(code: 'cs.CY', displayName: '计算机与社会'),
    ArxivSubject(code: 'cs.DB', displayName: '数据库'),
    ArxivSubject(code: 'cs.DC', displayName: '分布式、并行与集群计算'),
    ArxivSubject(code: 'cs.DL', displayName: '数字图书馆'),
    ArxivSubject(code: 'cs.DM', displayName: '离散数学'),
    ArxivSubject(code: 'cs.DS', displayName: '数据结构与算法'),
    ArxivSubject(code: 'cs.ET', displayName: '新兴技术'),
    ArxivSubject(code: 'cs.FL', displayName: '形式语言与自动机理论'),
    ArxivSubject(code: 'cs.GL', displayName: '通用文献'),
    ArxivSubject(code: 'cs.GR', displayName: '计算机图形学'),
    ArxivSubject(code: 'cs.GT', displayName: '博弈论'),
    ArxivSubject(code: 'cs.HC', displayName: '人机交互'),
    ArxivSubject(code: 'cs.IR', displayName: '信息检索'),
    ArxivSubject(code: 'cs.IT', displayName: '信息论'),
    ArxivSubject(code: 'cs.LG', displayName: '机器学习'),
    ArxivSubject(code: 'cs.LO', displayName: '逻辑'),
    ArxivSubject(code: 'cs.MA', displayName: '多智能体系统'),
    ArxivSubject(code: 'cs.MM', displayName: '多媒体'),
    ArxivSubject(code: 'cs.MS', displayName: '数学软件'),
    ArxivSubject(code: 'cs.NA', displayName: '数值分析'),
    ArxivSubject(code: 'cs.NE', displayName: '神经与进化计算'),
    ArxivSubject(code: 'cs.NI', displayName: '网络与互联网架构'),
    ArxivSubject(code: 'cs.OH', displayName: '其他'),
    ArxivSubject(code: 'cs.OS', displayName: '操作系统'),
    ArxivSubject(code: 'cs.PF', displayName: '性能'),
    ArxivSubject(code: 'cs.PL', displayName: '编程语言'),
    ArxivSubject(code: 'cs.RO', displayName: '机器人学'),
    ArxivSubject(code: 'cs.SC', displayName: '符号计算'),
    ArxivSubject(code: 'cs.SD', displayName: '声音'),
    ArxivSubject(code: 'cs.SE', displayName: '软件工程'),
    ArxivSubject(code: 'cs.SI', displayName: '社会与信息网络'),
    ArxivSubject(code: 'cs.SY', displayName: '系统与控制'),
  ];
}
