import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/mls_property.dart';
import '../../api_request/mls_property_service.dart';
import '../../widgets/common_design_system.dart';
import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// P3. 통합 방문 스케줄러 (스마트 예약)
///
/// 매도인 오픈 타임을 설정하고, 중개사 방문 요청을 승인/반려합니다.
/// 더블 부킹을 방지하고 방문 리마인드를 자동화합니다.
class MLSVisitSchedulerPage extends StatefulWidget {
  final String propertyId;

  const MLSVisitSchedulerPage({
    Key? key,
    required this.propertyId,
  }) : super(key: key);

  @override
  State<MLSVisitSchedulerPage> createState() => _MLSVisitSchedulerPageState();
}

class _MLSVisitSchedulerPageState extends State<MLSVisitSchedulerPage> {
  final _mlsService = MLSPropertyService();

  MLSProperty? _property;
  bool _isLoading = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<VisitSchedule> _selectedDaySchedules = [];

  // 오픈 타임 설정
  final Map<String, List<TimeSlot>> _availableSlots = {};
  bool _isEditingSlots = false;

  @override
  void initState() {
    super.initState();
    _loadProperty();
  }

  Future<void> _loadProperty() async {
    setState(() => _isLoading = true);
    try {
      final property = await _mlsService.getProperty(widget.propertyId);
      if (property != null && mounted) {
        setState(() {
          _property = property;
          _availableSlots.addAll(property.availableSlots);
          _selectedDay = DateTime.now();
          _updateSelectedDaySchedules();
        });
      }
    } catch (e) {
      Logger.error('Failed to load property', error: e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateSelectedDaySchedules() {
    if (_selectedDay == null || _property == null) {
      _selectedDaySchedules = [];
      return;
    }

    _selectedDaySchedules = _property!.visitSchedules.where((schedule) {
      final scheduleDate = schedule.scheduledAt;
      return scheduleDate.year == _selectedDay!.year &&
          scheduleDate.month == _selectedDay!.month &&
          scheduleDate.day == _selectedDay!.day;
    }).toList();

    _selectedDaySchedules.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('방문 스케줄')),
        body: const Center(child: Text('매물 정보를 찾을 수 없습니다')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('방문 스케줄 관리'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(_isEditingSlots ? Icons.check : Icons.edit),
            onPressed: () {
              if (_isEditingSlots) {
                _saveAvailableSlots();
              }
              setState(() => _isEditingSlots = !_isEditingSlots);
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildCalendar(),
          const SizedBox(height: 16),
          if (_isEditingSlots)
            _buildTimeSlotsEditor()
          else
            _buildVisitRequests(),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: CommonDesignSystem.cardDecoration(),
      child: TableCalendar(
        firstDay: DateTime.now(),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        eventLoader: (day) {
          return _property!.visitSchedules.where((schedule) {
            final scheduleDate = schedule.scheduledAt;
            return scheduleDate.year == day.year &&
                scheduleDate.month == day.month &&
                scheduleDate.day == day.day;
          }).toList();
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
            _updateSelectedDaySchedules();
          });
        },
      ),
    );
  }

  Widget _buildTimeSlotsEditor() {
    if (_selectedDay == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('날짜를 선택해주세요'),
      );
    }

    final dateKey = '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}';
    final slots = _availableSlots[dateKey] ?? [];

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '가용 시간대 설정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.primary),
                onPressed: () => _addTimeSlot(dateKey),
              ),
            ],
          ),
          const Divider(height: 24),
          if (slots.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '시간대를 추가해주세요',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: slots.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final slot = slots[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: slot.isAvailable ? AppColors.success : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${slot.startTime} - ${slot.endTime}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      Switch(
                        value: slot.isAvailable,
                        onChanged: (value) => _toggleSlotAvailability(dateKey, index, value),
                        activeColor: AppColors.primary,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.error),
                        onPressed: () => _removeTimeSlot(dateKey, index),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVisitRequests() {
    if (_selectedDay == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('날짜를 선택해주세요'),
      );
    }

    final pendingRequests = _selectedDaySchedules
      .where((s) => s.status == VisitStatus.requested)
      .toList();
    final approvedSchedules = _selectedDaySchedules
      .where((s) => s.status == VisitStatus.approved)
      .toList();
    final completedSchedules = _selectedDaySchedules
      .where((s) => s.status == VisitStatus.completed)
      .toList();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedDay!.month}월 ${_selectedDay!.day}일 방문 일정',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          if (pendingRequests.isNotEmpty) ...[
            const Text(
              '승인 대기',
              style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.warning),
            ),
            const SizedBox(height: 12),
            ...pendingRequests.map((schedule) => _buildVisitRequestCard(schedule)),
            const SizedBox(height: 16),
          ],
          if (approvedSchedules.isNotEmpty) ...[
            const Text(
              '확정된 일정',
              style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.success),
            ),
            const SizedBox(height: 12),
            ...approvedSchedules.map((schedule) => _buildVisitScheduleCard(schedule)),
            const SizedBox(height: 16),
          ],
          if (completedSchedules.isNotEmpty) ...[
            const Text(
              '완료된 방문',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ...completedSchedules.map((schedule) => _buildVisitScheduleCard(schedule)),
          ],
          if (_selectedDaySchedules.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '예약된 방문이 없습니다',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisitRequestCard(VisitSchedule schedule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  schedule.brokerName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${schedule.scheduledAt.hour.toString().padLeft(2, '0')}:${schedule.scheduledAt.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (schedule.note != null && schedule.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              schedule.note!,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _updateScheduleStatus(schedule.id, VisitStatus.rejected),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  child: const Text('거절'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateScheduleStatus(schedule.id, VisitStatus.approved),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  child: const Text('승인'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisitScheduleCard(VisitSchedule schedule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _getScheduleStatusColor(schedule.status)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getScheduleStatusIcon(schedule.status),
                color: _getScheduleStatusColor(schedule.status),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  schedule.brokerName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                _getScheduleStatusText(schedule.status),
                style: TextStyle(
                  fontSize: 12,
                  color: _getScheduleStatusColor(schedule.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${schedule.scheduledAt.hour.toString().padLeft(2, '0')}:${schedule.scheduledAt.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (schedule.feedback != null && schedule.feedback!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '방문 피드백',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    schedule.feedback!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addTimeSlot(String dateKey) {
    showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    ).then((startTime) {
      if (startTime == null) return;

      showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: startTime.hour + 1, minute: startTime.minute),
      ).then((endTime) {
        if (endTime == null) return;

        setState(() {
          if (!_availableSlots.containsKey(dateKey)) {
            _availableSlots[dateKey] = [];
          }
          _availableSlots[dateKey]!.add(TimeSlot(
            startTime: '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
            endTime: '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
            isAvailable: true,
          ));
        });
      });
    });
  }

  void _removeTimeSlot(String dateKey, int index) {
    setState(() {
      _availableSlots[dateKey]?.removeAt(index);
      if (_availableSlots[dateKey]?.isEmpty ?? false) {
        _availableSlots.remove(dateKey);
      }
    });
  }

  void _toggleSlotAvailability(String dateKey, int index, bool isAvailable) {
    setState(() {
      final slot = _availableSlots[dateKey]![index];
      _availableSlots[dateKey]![index] = TimeSlot(
        startTime: slot.startTime,
        endTime: slot.endTime,
        isAvailable: isAvailable,
      );
    });
  }

  Future<void> _saveAvailableSlots() async {
    try {
      await _mlsService.setAvailableSlots(
        propertyId: widget.propertyId,
        slots: _availableSlots,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가용 시간대가 저장되었습니다')),
      );
    } catch (e) {
      Logger.error('Failed to save available slots', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장에 실패했습니다')),
      );
    }
  }

  Future<void> _updateScheduleStatus(String scheduleId, VisitStatus status) async {
    try {
      await _mlsService.updateVisitSchedule(
        propertyId: widget.propertyId,
        scheduleId: scheduleId,
        status: status,
      );

      await _loadProperty();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('방문 일정이 ${_getScheduleStatusText(status)}되었습니다')),
      );
    } catch (e) {
      Logger.error('Failed to update schedule status', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상태 변경에 실패했습니다')),
      );
    }
  }

  String _getScheduleStatusText(VisitStatus status) {
    switch (status) {
      case VisitStatus.requested:
        return '대기중';
      case VisitStatus.approved:
        return '승인됨';
      case VisitStatus.rejected:
        return '거절됨';
      case VisitStatus.completed:
        return '완료됨';
      case VisitStatus.cancelled:
        return '취소됨';
    }
  }

  Color _getScheduleStatusColor(VisitStatus status) {
    switch (status) {
      case VisitStatus.requested:
        return AppColors.warning;
      case VisitStatus.approved:
        return AppColors.success;
      case VisitStatus.rejected:
        return AppColors.error;
      case VisitStatus.completed:
        return Colors.grey;
      case VisitStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getScheduleStatusIcon(VisitStatus status) {
    switch (status) {
      case VisitStatus.requested:
        return Icons.schedule;
      case VisitStatus.approved:
        return Icons.check_circle;
      case VisitStatus.rejected:
        return Icons.cancel;
      case VisitStatus.completed:
        return Icons.done_all;
      case VisitStatus.cancelled:
        return Icons.block;
    }
  }
}
