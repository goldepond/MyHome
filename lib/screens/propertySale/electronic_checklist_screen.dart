import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:property/models/checklist_item.dart';
import 'package:property/models/property.dart';
import 'package:property/constants/app_constants.dart';

class ElectronicChecklistScreen extends StatefulWidget {
  final Property property;
  final String userName;
  final String currentUserId;

  const ElectronicChecklistScreen({
    required this.property, required this.userName, required this.currentUserId, super.key,
  });

  @override
  State<ElectronicChecklistScreen> createState() => _ElectronicChecklistScreenState();
}

class _ElectronicChecklistScreenState extends State<ElectronicChecklistScreen> {
  List<ChecklistItem> checklistItems = [];
  bool isLoading = false;
  bool isAssistantMode = false; // 중개보조원 모드

  @override
  void initState() {
    super.initState();
    _initializeChecklistItems();
  }

  void _initializeChecklistItems() {
    checklistItems = [
      ChecklistItem(
        id: '1',
        title: '집주인 체납세 고지',
        description: '완납증명서 캡처/파일 업로드',
        category: '세무',
      ),
      ChecklistItem(
        id: '2',
        title: '선순위 권리관계 요약',
        description: '근저당·설정일·말소 여부 확인',
        category: '권리관계',
      ),
      ChecklistItem(
        id: '3',
        title: '전입 가능 여부',
        description: '불법용도·다가구/다세대 유의사항',
        category: '용도',
      ),
      ChecklistItem(
        id: '4',
        title: '관리비 상세',
        description: '포함/제외 항목 명시',
        category: '관리비',
      ),
      ChecklistItem(
        id: '5',
        title: '하자·수리 의무 안내',
        description: '보일러·전기·상하수도 등',
        category: '하자',
      ),
      ChecklistItem(
        id: '6',
        title: '확정일자/전입신고 협조 동의',
        description: '임차인 권리보호를 위한 협조사항',
        category: '권리보호',
      ),
      ChecklistItem(
        id: '7',
        title: '부동산 중개업소 등록증',
        description: '공인중개사 등록증 사본',
        category: '중개업소',
      ),
      ChecklistItem(
        id: '8',
        title: '중개보조원 자격증',
        description: '중개보조원 자격증 사본 (해당시)',
        category: '중개업소',
      ),
    ];
  }

  int get completedCount => checklistItems.where((item) => 
    item.status == ChecklistStatus.approved || item.status == ChecklistStatus.submitted
  ).length;

  int get totalCount => checklistItems.length;

  bool get isAllCompleted => completedCount == totalCount;

  Future<void> _uploadFile(ChecklistItem item) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null) {
        final file = result.files.first;
        
        // 실제 구현에서는 Firebase Storage에 업로드
        // 여기서는 시뮬레이션
        await Future.delayed(const Duration(seconds: 1));
        
        setState(() {

          final index = checklistItems.indexWhere((i) => i.id == item.id);
          if (index != -1) {
            checklistItems[index] = item.copyWith(
              status: ChecklistStatus.submitted,
              uploadedFileName: file.name,
              uploadedAt: DateTime.now(),
              uploadedBy: widget.userName,
              lastUpdated: DateTime.now(),
            );
          }
        });
        if(!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${file.name} 파일이 업로드되었습니다.'),
            backgroundColor: AirbnbColors.success,
          ),
        );
      }
    } catch (e) {
      if(!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('파일 업로드 중 오류가 발생했습니다: $e'),
          backgroundColor: AirbnbColors.error,
        ),
      );
    }
  }

  void _showRejectionDialog(ChecklistItem item) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('보완 필요 사유 입력'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${item.title} - 보완 필요 사유를 입력해주세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '예: 업로드된 완납증명서의 해상도가 낮아 식별이 불가능합니다. 재업로드 바랍니다.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                setState(() {
                  final index = checklistItems.indexWhere((i) => i.id == item.id);
                  if (index != -1) {
                    checklistItems[index] = item.copyWith(
                      status: ChecklistStatus.rejected,
                      rejectionReason: reasonController.text.trim(),
                      lastUpdated: DateTime.now(),
                    );
                  }
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('보완 필요로 처리되었습니다.'),
                    backgroundColor: AirbnbColors.warning,
                  ),
                );
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _approveItem(ChecklistItem item) {
    setState(() {
      final index = checklistItems.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        checklistItems[index] = item.copyWith(
          status: ChecklistStatus.approved,
          lastUpdated: DateTime.now(),
        );
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.title}이 승인되었습니다.'),
        backgroundColor: AirbnbColors.success,
      ),
    );
  }

  Future<void> _generatePDF() async {
    // PDF 생성 로직 (실제 구현에서는 pdf 패키지 사용)
    await Future.delayed(const Duration(seconds: 2));
    if(!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('확인·설명서 PDF가 생성되었습니다.'),
        backgroundColor: AirbnbColors.primary,
      ),
    );
  }

  Widget _buildChecklistCard(ChecklistItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.status.icon,
                  color: item.status.color,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AirbnbColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.status.color.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: item.status.color),
                  ),
                  child: Text(
                    item.status.displayName,
                    style: TextStyle(
                      color: item.status.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            if (item.uploadedFileName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AirbnbColors.primary.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, color: AirbnbColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.uploadedFileName!,
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (item.uploadedAt != null)
                            Text(
                              '업로드: ${item.uploadedAt!.toString().substring(0, 19)}',
                              style: const TextStyle(fontSize: 10, color: AirbnbColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (item.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AirbnbColors.error.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AirbnbColors.error.withValues(alpha:0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline, color: AirbnbColors.error, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '보완 필요 사유:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AirbnbColors.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.rejectionReason!,
                      style: const TextStyle(fontSize: 12, color: AirbnbColors.error),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            Row(
              children: [
                if (item.status == ChecklistStatus.pending || item.status == ChecklistStatus.rejected)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _uploadFile(item),
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('파일 업로드'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbColors.primary,
                        foregroundColor: AirbnbColors.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                if (isAssistantMode && item.status == ChecklistStatus.submitted) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectionDialog(item),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('보완요청'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AirbnbColors.error,
                        side: const BorderSide(color: AirbnbColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveItem(item),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('승인'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbColors.success,
                        foregroundColor: AirbnbColors.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('확인·설명서 전자체크'),
        backgroundColor: AirbnbColors.primary,
        foregroundColor: AirbnbColors.background,
        actions: [
          if (isAssistantMode)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AirbnbColors.warning,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '보조원 응대',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
          // 상단 경고 메시지
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AirbnbColors.warning.withValues(alpha:0.1),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: AirbnbColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '확인·설명서가 100% 완료되면 가계약으로 이동합니다.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AirbnbColors.warning.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 진행률 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AirbnbColors.surface,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '진행률',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AirbnbColors.textSecondary,
                      ),
                    ),
                    Text(
                      '$completedCount/$totalCount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isAllCompleted ? AirbnbColors.success : AirbnbColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: totalCount > 0 ? completedCount / totalCount : 0,
                  backgroundColor: AirbnbColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isAllCompleted ? AirbnbColors.success : AirbnbColors.primary,
                  ),
                ),
              ],
            ),
          ),
          
          // 체크리스트 목록
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: checklistItems.length,
              itemBuilder: (context, index) {
                return _buildChecklistCard(checklistItems[index]);
              },
            ),
          ),
          
          // 하단 버튼들
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AirbnbColors.background,
              boxShadow: [
                BoxShadow(
                  color: AirbnbColors.textSecondary.withValues(alpha:0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _generatePDF,
                        icon: const Icon(Icons.download),
                        label: const Text('PDF 내려받기'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AirbnbColors.primary,
                          side: const BorderSide(color: AirbnbColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isAllCompleted ? () {
                          // 가계약 화면으로 이동
                          Navigator.of(context).pop(true);
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAllCompleted ? AirbnbColors.primary : AirbnbColors.textSecondary,
                          foregroundColor: AirbnbColors.background,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('가계약 진행'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '모든 확인 내역은 시간·IP가 찍힌 PDF로 보관되어 분쟁 시 증거가 됩니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AirbnbColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

