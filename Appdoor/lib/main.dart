import 'package:flutter/material.dart';
import 'package:gsheets/gsheets.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hệ thống quản lý nhân viên',
      theme: ThemeData(
        primaryColor: Colors.indigo[700],
        scaffoldBackgroundColor: Colors.grey[50],
        fontFamily: 'Roboto',
        brightness: Brightness.light,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 14),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      home: const AttendanceApp(),
    );
  }
}

class GoogleSheetService {
  static const String _spreadsheetId = '13_Vw6G8H735qdZQqOj74CPtpRqthvnZpjXIqBl3Ht3w';
  late GSheets _gsheets;
  Worksheet? _userWorksheet;
  Worksheet? _attendanceWorksheet;

  Future<void> init(BuildContext context) async {
    try {
      final credentials = await DefaultAssetBundle.of(context).loadString('assets/credentials.json');
      _gsheets = GSheets(credentials);
      final spreadsheet = await _gsheets.spreadsheet(_spreadsheetId);
      _userWorksheet = spreadsheet.worksheetByTitle('Data');
      _attendanceWorksheet = spreadsheet.worksheetByTitle('Attendance');
      print('Kết nối Data: ${_userWorksheet != null ? "Thành công" : "Thất bại"}');
      print('Attendance: ${_attendanceWorksheet != null ? "Thành công" : "Thất bại"}');
    } catch (e) {
      print('Lỗi chi tiết: $e');
      rethrow;
    }
  }

  Future<List<List<String>>> loadUserData() async {
    if (_userWorksheet == null) return [];
    return await _userWorksheet!.values.allRows(fromRow: 2);
  }

  Future<List<List<String>>> loadAttendanceData() async {
    if (_attendanceWorksheet == null) return [];
    return await _attendanceWorksheet!.values.allRows(fromRow: 2).then((data) {
      return data.map((row) => _formatAttendanceRow(row)).toList();
    });
  }

  Future<void> addUser(List<String> userData) async {
    if (_userWorksheet != null) {
      await _userWorksheet!.values.appendRow(userData);
    }
  }

  Future<void> addAttendance(List<String> attendanceData) async {
    if (_attendanceWorksheet != null) {
      await _attendanceWorksheet!.values.appendRow(attendanceData);
    }
  }

  Future<void> deleteUser(int index) async {
    if (_userWorksheet != null) {
      await _userWorksheet!.deleteRow(index + 2);
    }
  }

  List<String> _formatAttendanceRow(List<String> row) {
    String date = row[3]; // Cột D
    try {
      int dateSerial = int.parse(date);
      DateTime parsedDate = DateTime.fromMillisecondsSinceEpoch((dateSerial - 25569) * 86400000, isUtc: false)
          .toUtc()
          .add(const Duration(hours: 7));
      date = DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      try {
        DateTime parsedDate = DateFormat('dd/MM/yyyy').parse(date);
        date = DateFormat('dd/MM/yyyy').format(parsedDate);
      } catch (_) {}
    }

    String timeIn = row[4]; // Cột E
    try {
      double timeSerial = double.parse(timeIn);
      int hours = (timeSerial * 24).floor();
      int minutes = ((timeSerial * 24 - hours) * 60).round();
      timeIn = DateFormat('HH:mm').format(DateTime(2023, 1, 1, hours, minutes));
    } catch (e) {
      try {
        DateTime parsedTime = DateFormat('HH:mm').parse(timeIn);
        timeIn = DateFormat('HH:mm').format(parsedTime);
      } catch (_) {}
    }

    String timeOut = row[5]; // Cột F
    try {
      double timeSerial = double.parse(timeOut);
      int hours = (timeSerial * 24).floor();
      int minutes = ((timeSerial * 24 - hours) * 60).round();
      timeOut = DateFormat('HH:mm').format(DateTime(2023, 1, 1, hours, minutes));
    } catch (e) {
      try {
        DateTime parsedTime = DateFormat('HH:mm').parse(timeOut);
        timeOut = DateFormat('HH:mm').format(parsedTime);
      } catch (_) {}
    }

    return [row[0], row[1], row[2], date, timeIn, timeOut];
  }
}

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key});

  @override
  _AttendanceAppState createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  final GoogleSheetService _sheetService = GoogleSheetService();
  List<List<String>> _userData = [];
  List<List<String>> _attendanceData = [];
  bool _isLoading = true;

  final List<String> _provinces = const [
    'An Giang', 'Bà Rịa - Vũng Tàu', 'Bắc Giang', 'Bắc Kạn', 'Bạc Liêu', 'Bắc Ninh', 'Bến Tre', 'Bình Định',
    'Bình Dương', 'Bình Phước', 'Bình Thuận', 'Cà Mau', 'Cần Thơ', 'Cao Bằng', 'Đà Nẵng', 'Đắk Lắk', 'Đắk Nông',
    'Điện Biên', 'Đồng Nai', 'Đồng Tháp', 'Gia Lai', 'Hà Giang', 'Hà Nam', 'Hà Nội', 'Hà Tĩnh', 'Hải Dương',
    'Hải Phòng', 'Hậu Giang', 'Hòa Bình', 'Hưng Yên', 'Khánh Hòa', 'Kiên Giang', 'Kon Tum', 'Lai Châu', 'Lâm Đồng',
    'Lạng Sơn', 'Lào Cai', 'Long An', 'Nam Định', 'Nghệ An', 'Ninh Bình', 'Ninh Thuận', 'Phú Thọ', 'Phú Yên',
    'Quảng Bình', 'Quảng Nam', 'Quảng Ngãi', 'Quảng Ninh', 'Quảng Trị', 'Sóc Trăng', 'Sơn La', 'Tây Ninh',
    'Thái Bình', 'Thái Nguyên', 'Thanh Hóa', 'Thừa Thiên Huế', 'Tiền Giang', 'TP. Hồ Chí Minh', 'Trà Vinh',
    'Tuyên Quang', 'Vĩnh Long', 'Vĩnh Phúc', 'Yên Bái',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _sheetService.init(context);
      _userData = await _sheetService.loadUserData();
      _attendanceData = await _sheetService.loadAttendanceData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi kết nối: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _manageEmployees(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController uidController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController positionController = TextEditingController();
    final TextEditingController dobController = TextEditingController();
    String? selectedProvince;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm nhân viên mới', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(controller: nameController, label: 'Họ và tên'),
              _buildTextField(controller: uidController, label: 'Mã UID'),
              _buildTextField(controller: emailController, label: 'Email'),
              _buildTextField(controller: phoneController, label: 'Số điện thoại'),
              _buildTextField(controller: positionController, label: 'Chức vụ'),
              _buildTextField(controller: dobController, label: 'Ngày sinh (dd/MM/yyyy)'),
              DropdownButtonFormField<String>(
                decoration: _buildInputDecoration('Tỉnh/Thành'),
                value: selectedProvince,
                items: _provinces.map((province) {
                  return DropdownMenuItem<String>(value: province, child: Text(province));
                }).toList(),
                onChanged: (value) {
                  selectedProvince = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_validateInputs([
                nameController,
                uidController,
                emailController,
                phoneController,
                positionController,
                dobController,
              ]) &&
                  selectedProvince != null) {
                final updateDate = DateFormat('dd/MM/yyyy').format(DateTime.now().toUtc().add(const Duration(hours: 7)));
                await _sheetService.addUser([
                  uidController.text,
                  nameController.text,
                  emailController.text,
                  phoneController.text,
                  positionController.text,
                  dobController.text,
                  selectedProvince!,
                  updateDate,
                ]);
                await _loadData();
                Navigator.pop(context);
                _showSnackBar(context, 'Đã thêm nhân viên thành công', Colors.green);
              } else {
                _showSnackBar(context, 'Vui lòng điền đầy đủ thông tin', Colors.red);
              }
            },
            child: const Text('Thêm nhân viên'),
          ),
        ],
      ),
    );
  }

  void _recordAttendance(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController uidController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? timeIn;
    TimeOfDay? timeOut;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ghi nhận ra vào', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: _buildInputDecoration('Tên nhân viên'),
                items: _userData.map((user) {
                  return DropdownMenuItem<String>(value: user[1], child: Text(user[1]));
                }).toList(),
                onChanged: (value) {
                  nameController.text = value ?? '';
                  final selectedUser = _userData.firstWhere((user) => user[1] == value, orElse: () => ['', '', '', '', '', '', '', '']);
                  uidController.text = selectedUser[0];
                },
              ),
              _buildTextField(controller: uidController, label: 'Mã UID', enabled: false),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked.toUtc().add(const Duration(hours: 7)));
                  }
                },
                child: _buildDateTimeContainer(
                  selectedDate == null ? 'Chọn ngày' : DateFormat('dd/MM/yyyy').format(selectedDate!),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (picked != null) {
                          setState(() => timeIn = picked);
                        }
                      },
                      child: _buildDateTimeContainer(
                        timeIn == null ? 'Giờ vào' : DateFormat('HH:mm').format(DateTime(2023, 1, 1, timeIn!.hour, timeIn!.minute)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (picked != null) {
                          setState(() => timeOut = picked);
                        }
                      },
                      child: _buildDateTimeContainer(
                        timeOut == null ? 'Giờ ra' : DateFormat('HH:mm').format(DateTime(2023, 1, 1, timeOut!.hour, timeOut!.minute)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && selectedDate != null && timeIn != null && timeOut != null) {
                final position = _userData.firstWhere((user) => user[1] == nameController.text, orElse: () => ['', '', '', '', '', '', '', ''])[4] ?? '';
                final dateSerial = (selectedDate!.millisecondsSinceEpoch ~/ 86400000) + 25569;
                final timeInFormatted = DateFormat('HH:mm').format(DateTime(2023, 1, 1, timeIn!.hour, timeIn!.minute));
                final timeOutFormatted = DateFormat('HH:mm').format(DateTime(2023, 1, 1, timeOut!.hour, timeOut!.minute));
                await _sheetService.addAttendance([
                  uidController.text,
                  nameController.text,
                  position,
                  dateSerial.toString(),
                  timeInFormatted,
                  timeOutFormatted,
                ]);
                await _loadData();
                Navigator.pop(context);
                _showSnackBar(context, 'Đã ghi nhận ra vào thành công', Colors.green);
              } else {
                _showSnackBar(context, 'Vui lòng điền đầy đủ thông tin', Colors.red);
              }
            },
            child: const Text('Ghi nhận'),
          ),
        ],
      ),
    );
  }

  void _showEmployeeList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _EmployeeListScreen(
          userData: _userData,
          onRefresh: _loadData,
          onDelete: (index) async {
            await _sheetService.deleteUser(index);
            await _loadData();
          },
        ),
      ),
    );
  }

  void _showAttendanceInfo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AttendanceInfoScreen(
          attendanceData: _attendanceData,
          onRefresh: _loadData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hệ thống quản lý nhân viên', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
        backgroundColor: Colors.indigo[700],
        elevation: 4,
        actions: [
          IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.indigo, Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCard('Quản lý nhân viên', ElevatedButton(
                onPressed: () => _manageEmployees(context),
                child: const Text('Thêm nhân viên'),
              )),
              const SizedBox(height: 16),
              _buildCard('Ghi nhận ra vào', ElevatedButton(
                onPressed: () => _recordAttendance(context),
                child: const Text('Ghi nhận'),
              )),
              const SizedBox(height: 16),
              Expanded(
                child: _buildCard(null, null, children: [
                  ListTile(
                    title: const Text('Danh sách nhân viên', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    trailing: IconButton(
                      icon: const Icon(Icons.list, color: Colors.indigo),
                      onPressed: () => _showEmployeeList(context),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),
                  ListTile(
                    title: const Text('Thông tin ra vào', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today, color: Colors.indigo),
                      onPressed: () => _showAttendanceInfo(context),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: _buildInputDecoration(label),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    );
  }

  Widget _buildDateTimeContainer(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black54)),
    );
  }

  Widget _buildCard(String? title, Widget? trailing, {List<Widget>? children}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: children != null
          ? Column(children: children)
          : ListTile(title: Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), trailing: trailing),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  bool _validateInputs(List<TextEditingController> controllers) {
    return controllers.every((controller) => controller.text.isNotEmpty);
  }
}

class _EmployeeListScreen extends StatelessWidget {
  final List<List<String>> userData;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int) onDelete;

  const _EmployeeListScreen({required this.userData, required this.onRefresh, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách nhân viên', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
        backgroundColor: Colors.indigo[700],
        elevation: 4,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: onRefresh),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: userData.isEmpty
            ? const Center(child: Text('Không có nhân viên nào', style: TextStyle(fontSize: 16, color: Colors.grey)))
            : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columnSpacing: 10,
              headingRowColor: MaterialStateProperty.all(Colors.indigo[50]),
              dataRowHeight: 48,
              columns: const [
                DataColumn(label: Text('Họ và tên', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('Mã UID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('SĐT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('Chức vụ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('Ngày sinh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('Tỉnh/Thành', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('Ngày cập nhật', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('Hành động', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              ],
              rows: userData.asMap().entries.map((entry) {
                final index = entry.key;
                final user = entry.value;
                return DataRow(cells: [
                  DataCell(Text(user[1], style: const TextStyle(fontSize: 12))),
                  DataCell(Text(user[0], style: const TextStyle(fontSize: 12))),
                  DataCell(Text(user[2], style: const TextStyle(fontSize: 12))),
                  DataCell(Text(user[3], style: const TextStyle(fontSize: 12))),
                  DataCell(Text(user[4], style: const TextStyle(fontSize: 12))),
                  DataCell(Text(user[5], style: const TextStyle(fontSize: 12))),
                  DataCell(Text(user[6], style: const TextStyle(fontSize: 12))),
                  DataCell(Text(user[7], style: const TextStyle(fontSize: 12))),
                  DataCell(IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => onDelete(index),
                  )),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceInfoScreen extends StatelessWidget {
  final List<List<String>> attendanceData;
  final Future<void> Function() onRefresh;

  const _AttendanceInfoScreen({required this.attendanceData, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin ra vào', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
        backgroundColor: Colors.indigo[700],
        elevation: 4,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: onRefresh),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: attendanceData.isEmpty
            ? const Center(child: Text('Không có dữ liệu điểm danh', style: TextStyle(fontSize: 16, color: Colors.grey)))
            : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columnSpacing: 10,
              headingRowColor: MaterialStateProperty.all(Colors.indigo[50]),
              dataRowHeight: 48,
              columns: const [
                DataColumn(label: Text('Mã UID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('Họ và tên', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('Chức vụ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('Ngày', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('Giờ vào', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(label: Text('Giờ ra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              ],
              rows: attendanceData.map((record) {
                return DataRow(cells: [
                  DataCell(Text(record[0], style: const TextStyle(fontSize: 12))),
                  DataCell(Text(record[1], style: const TextStyle(fontSize: 12))),
                  DataCell(Text(record[2], style: const TextStyle(fontSize: 12))),
                  DataCell(Text(record[3], style: const TextStyle(fontSize: 12))),
                  DataCell(Text(record[4], style: const TextStyle(fontSize: 12))),
                  DataCell(Text(record[5], style: const TextStyle(fontSize: 12))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}