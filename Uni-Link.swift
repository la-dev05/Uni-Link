//  Uni-Link
//
//  Created by Lakshya G. on 11/23/24.

import SwiftUI
import CoreLocation
import LocalAuthentication
import Network

struct AppTheme {
    static let primary = Color("AccentColor")
    static let background = Color(.systemBackground)
    static let cardBackground = Color(.secondarySystemBackground)
    static let text = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .greatestFiniteMagnitude)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            .shadow(radius: 2)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct Student: Identifiable {
    var id = UUID()
    var name: String
    var email: String
    var studentId: String
}

class AttendanceExportService {
    static func getAttendanceFilePath() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Student Attendance.csv")
    }
    
    static func generateCSV(students: [Student], attendanceRecords: [(studentId: String, date: Date)]) -> String {
        var csv = "Student Name,Student ID,Email,Attendance Date,Time\n"
        
        for record in attendanceRecords {
            if let student = students.first(where: { $0.studentId == record.studentId }) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                
                let date = dateFormatter.string(from: record.date)
                csv += "\(student.name),\(student.studentId),\(student.email),\(date)\n"
            }
        }
        
        return csv
    }
    
    static func appendAttendanceRecord(student: Student, date: Date) {
        guard let fileURL = getAttendanceFilePath() else {
            print("Error: Unable to access documents directory")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let dateString = dateFormatter.string(from: date)
        let newRecord = "\(student.name),\(student.studentId),\(student.email),\(dateString)\n"
        
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let headers = "Student Name,Student ID,Email,Attendance Date,Time\n"
            try? headers.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            fileHandle.seekToEndOfFile()
            if let data = newRecord.data(using: .utf8) {
                fileHandle.write(data)
            }
            try? fileHandle.close()
        }
    }
    
    static func exportToNumbers(students: [Student], attendanceRecords: [(studentId: String, date: Date)]) {
        let csv = generateCSV(students: students, attendanceRecords: attendanceRecords)
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let fileName = "attendance_\(Date().timeIntervalSince1970).csv"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error writing CSV file: \(error)")
        }
    }
}

// Mock Database!
class MockDatabase: ObservableObject {
    @Published var students: [Student] = []
    @Published var attendanceRecords: [(studentId: String, date: Date)] = []
    @Published var currentStudent: Student?
    
    func addStudent(_ student: Student) {
        students.append(student)
        currentStudent = student
    }
    
    func recordAttendance(studentId: String) {
        attendanceRecords.append((studentId: studentId, date: Date()))
    }
}

// Biometric Authentication
class BiometricAuthManager {
    let context = LAContext()
    var error: NSError?
    
    func canUseFaceID() -> Bool {
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func authenticateUser() async -> Bool {
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Scan your face or finger to mark attendance"
            )
        } catch {
            return false
        }
    }
}


// VPN Detection Service
class VPNDetectionService {
    static func isVPNConnected() -> Bool {
        guard let cfDict = CFNetworkCopySystemProxySettings() else { return false }
        let nsDict = cfDict.takeRetainedValue() as NSDictionary
        guard let keys = nsDict["__SCOPED__"] as? NSDictionary else { return false }
        
        // Check for VPN interface
        for key in keys.allKeys {
            guard let interface = key as? String else { continue }
            if interface.contains("tap") || interface.contains("tun") || interface.contains("ppp") || interface.contains("ipsec") {
                return true
            }
        }
        
        return false
    }
}




// Location Tracker with predefined coordinates around Plaksha University!
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    // Plaksha University campus coordinates
    private let campusPolygon: [(Double, Double)] = [
        (30.6312807, 76.7272162), 
        (30.6334221, 76.7250286),
        (30.6317419, 76.7215720),
        (30.6289446, 76.7234467)
    ]
    
    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        
        // Location Checking, if authorization complete!
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func requestLocationPermission() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func startUpdatingLocation() {
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // locationManager Authorization Methods
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            location = nil
            stopUpdatingLocation()
        case .notDetermined:
            requestLocationPermission()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        location = latestLocation
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    // Custom Designed Location Verification Algorithm
    private func locationCheck(position: (Double, Double), polygon: [(Double, Double)]) -> Bool {
        let (xPos, yPos) = position
        var inside = false
        let sides = polygon.count
        
        for i in 0..<sides {
            let (x1, y1) = polygon[i]
            let (x2, y2) = polygon[(i + 1) % sides]
            
            if (min(y1, y2) <= yPos && yPos < max(y1, y2)) && (xPos <= max(x1, x2)) {
                let x_intersect: Double
                if y1 != y2 {
                    x_intersect = (yPos - y1) * (x2 - x1) / (y2 - y1) + x1
                } else {
                    x_intersect = x1
                }
                
                if xPos == x_intersect {
                    return true
                }
                if xPos < x_intersect {
                    inside.toggle()
                }
            }
        }
        return inside
    }
    
    func isWithinCampus(location: CLLocation) -> Bool {
        let position = (location.coordinate.latitude, location.coordinate.longitude)
        return locationCheck(position: position, polygon: campusPolygon)
    }
    
    func setupLocationServices() {
        requestLocationPermission()
    }
}

// AttendanceViewModel
class AttendanceViewModel: ObservableObject {
    @Published var locationManager = LocationManager()
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var isAuthenticating = false
    var database: MockDatabase
    private let biometricAuth = BiometricAuthManager()
    
    init(database: MockDatabase) {
        self.database = database
        locationManager.setupLocationServices()
    }
    
    func markAttendance(studentId: String) async {
        // First check for VPN connection
        if VPNDetectionService.isVPNConnected() {
            alertMessage = "Please disconnect from VPN before marking attendance. VPN usage is not allowed for attendance marking."
            showAlert = true
            return
        }
        
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            alertMessage = "Location access is denied. Please enable location services in Settings to mark attendance."
            showAlert = true
            return
            
        case .notDetermined:
            locationManager.requestLocationPermission()
            alertMessage = "Please grant location access and try again."
            showAlert = true
            return
            
        case .authorizedWhenInUse, .authorizedAlways:
            await handleAuthorizedLocationAttendance(studentId: studentId)
            
        @unknown default:
            alertMessage = "Unknown location authorization status. Please try again."
            showAlert = true
            return
        }
    }
    
    private func handleAuthorizedLocationAttendance(studentId: String) async {
        // Check for a valid location
        guard let location = locationManager.location else {
            locationManager.startUpdatingLocation()
            alertMessage = "Waiting for location... Please try again in a moment."
            showAlert = true
            return
        }
        
        // Verify campus location
        if !locationManager.isWithinCampus(location: location) {
            alertMessage = "You must be within the campus boundaries to mark attendance."
            showAlert = true
            return
        }
        
        // Check Face ID availability
        if !biometricAuth.canUseFaceID() {
            alertMessage = "Face ID is not available on this device."
            showAlert = true
            return
        }
        
        // Attempt Face ID authentication
        isAuthenticating = true
        let authenticated = await biometricAuth.authenticateUser()
        isAuthenticating = false
        
        if authenticated {
            // Record attendance
            let currentDate = Date()
            database.recordAttendance(studentId: studentId)
            
            // Export attendance record
            if let student = database.students.first(where: { $0.studentId == studentId }) {
                AttendanceExportService.appendAttendanceRecord(student: student, date: currentDate)
            }
            
            alertMessage = "Attendance marked successfully!"
        } else {
            alertMessage = "Face ID authentication failed. Please try again."
        }
        showAlert = true
    }
}


// Registration View
struct RegistrationView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var studentId = ""
    @ObservedObject var database: MockDatabase
    @Binding var isRegistered: Bool
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Welcome")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Register to start marking your attendance")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText)
                }
                .padding(.top, 40)
                
                VStack(spacing: 20) {
                    InputField(title: "Full Name", text: $name, icon: "person.fill")
                    InputField(title: "College Email", text: $email, icon: "envelope.fill")
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    InputField(title: "Student ID", text: $studentId, icon: "number")
                        .keyboardType(.numberPad)
                }
                .padding(.horizontal)
                
                Button("Register") {
                    if email.hasSuffix(".edu.in") {
                        let student = Student(name: name, email: email, studentId: studentId)
                        database.addStudent(student)
                        isRegistered = true
                        alertMessage = "Registration successful!"
                    } else {
                        alertMessage = "Please use your university email address"
                    }
                    showAlert = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.isEmpty || email.isEmpty || studentId.isEmpty)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Registration"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}

// Input Field
struct InputField: View {
    let title: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundColor(AppTheme.secondaryText)
                .font(.subheadline)
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.secondaryText)
                TextField(title, text: $text)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
    }
}

// Account Info View
struct AccountInfoView: View {
    @ObservedObject var database: MockDatabase
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                if let student = database.currentStudent {
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(AppTheme.primary)
                        
                        Text(student.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(student.email)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 16) {
                        InfoCard(title: "Student ID", value: student.studentId, icon: "number.circle.fill")
                        InfoCard(title: "University", value: "Plaksha University", icon: "books.vertical.fill")
                    }
                    .padding()
                    
                    Spacer()
                }
            }
        }
        .navigationTitle("Profile")
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppTheme.primary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.secondaryText)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }
            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }
}


// Attendance History View
struct AttendanceHistoryView: View {
    @ObservedObject var database: MockDatabase
    @State private var showingExportAlert = false
    @State private var showingFileLocationAlert = false
    @State private var exportMessage = ""
    @State private var fileLocationMessage = ""
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 16) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(database.attendanceRecords, id: \.date) { record in
                            if let student = database.students.first(where: { $0.studentId == record.studentId }) {
                                AttendanceCard(student: student, date: record.date)
                            }
                        }
                    }
                    .padding()
                }
                
                VStack(spacing: 12) {
                    Button {
                        if let fileURL = AttendanceExportService.getAttendanceFilePath() {
                            fileLocationMessage = "File location:\n\(fileURL.path)"
                            showingFileLocationAlert = true
                        }
                    } label: {
                        Label("Show File Location", systemImage: "folder")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button {
                        AttendanceExportService.exportToNumbers(
                            students: database.students,
                            attendanceRecords: database.attendanceRecords
                        )
                        exportMessage = "Export completed successfully!"
                        showingExportAlert = true
                    } label: {
                        Label("Export to Numbers", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding()
            }
        }
        .navigationTitle("History")
        .alert("File Location", isPresented: $showingFileLocationAlert) {
            Button("OK") {}
        } message: {
            Text(fileLocationMessage)
        }
        .alert("Export Complete", isPresented: $showingExportAlert) {
            Button("OK") {}
        } message: {
            Text(exportMessage)
        }
    }
}



// NotificationManager to handle local notifications
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    let attendanceStartTime = Calendar.current.date(from: DateComponents(hour: 10, minute: 00))!
    let attendanceEndTime = Calendar.current.date(from: DateComponents(hour: 12, minute: 00))!
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleAttendanceNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time for Attendance!"
        content.body = "Click here to mark your attendance"
        content.sound = .default
        
        // Create notification trigger for start time
        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: attendanceStartTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create the request
        let request = UNNotificationRequest(
            identifier: "attendanceReminder",
            content: content,
            trigger: trigger
        )
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
}



struct AttendanceCard: View {
    let student: Student
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(student.name)
                        .font(.headline)
                    Text(student.studentId)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
            
            HStack {
                Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    .font(.footnote)
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }
}


// Attendance View
struct AttendanceView: View {
    @StateObject var viewModel: AttendanceViewModel
    @Binding var isRegistered: Bool
    @ObservedObject var database: MockDatabase
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                if let student = database.currentStudent {
                    VStack(spacing: 8) {
                        Text("Welcome")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(student.name)
                            .font(.title3)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    Text("Today's Attendance Timings: 10:00 AM - 12:00 PM")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 16) {
                        Image(systemName: "faceid")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.primary)
                        
                        if viewModel.isAuthenticating {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                        }
                        
                        Button {
                            Task {
                                await viewModel.markAttendance(studentId: student.studentId)
                            }
                        } label: {
                            Text("Mark Attendance")
                                .font(.headline)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(viewModel.isAuthenticating)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(16)
                    
                    Spacer()
                }
            }
            .padding()
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text("Attendance"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}


enum Tab {
    case attendance
    case history
    case account
}


// Tab View
struct MainTabView: View {
    @StateObject var database: MockDatabase
    @Binding var isRegistered: Bool
    @State private var selectedTab: Tab = .attendance
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AttendanceView(
                viewModel: AttendanceViewModel(database: database),
                isRegistered: $isRegistered,
                database: database
            )
            .tabItem {
                Label("Attendance", systemImage: "clock.fill")
            }
            .tag(Tab.attendance)
            
            AttendanceHistoryView(database: database)
                .tabItem {
                    Label("History", systemImage: "list.bullet.clipboard")
                }
                .tag(Tab.history)
            
            AccountInfoView(database: database)
                .tabItem {
                    Label("Account", systemImage: "person.fill")
                }
                .tag(Tab.account)
        }
        .tint(AppTheme.primary)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAttendanceTab"))) { _ in
            selectedTab = .attendance
        }
    }
}



// Main View
struct MainView: View {
    @State private var isRegistered = false
    @StateObject private var database = MockDatabase()
    
    var body: some View {
        if isRegistered {
            MainTabView(database: database, isRegistered: $isRegistered)
        } else {
            RegistrationView(database: database, isRegistered: $isRegistered)
        }
    }
}


// App Delegate to handle notification responses
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier == "attendanceReminder" {
            // Post notification to switch to attendance tab
            NotificationCenter.default.post(name: NSNotification.Name("ShowAttendanceTab"), object: nil)
        }
        completionHandler()
    }
}



@main
struct AttendanceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .onAppear {
                    NotificationManager.shared.scheduleAttendanceNotification()
                }
        }
    }
}

